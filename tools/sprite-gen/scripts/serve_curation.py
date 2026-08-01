#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Serve the sprite-gen curation webview for a single run directory.

Standalone, dependency-free (Python standard library + the PIL already used by
the pipeline). Launch it against any sprite-gen run folder and open the printed
URL in a browser to compare frames per state, select/reject frames, and apply a
non-destructive per-frame transform (rotate/scale/move). All edits are persisted
to `curation.json` in the run directory; the original frame PNGs are never
touched. The compose scripts read that sidecar and bake the result.

    python3 serve_curation.py --run-dir <run-folder>

This is intentionally a standalone skill tool (not a Studio panel) so it works
from Claude Code Desktop, the Codex app, or any environment where the skill is
installed.

API:
    GET  /                    -> curator SPA
    GET  /api/run             -> run state (cell, states, frames, current curation)
    GET  /frames/<state>/<f>  -> a frame PNG
    GET  /run/<relpath>       -> a file inside the run dir (atlas/qa previews)
    POST /api/curation        -> atomically write curation.json (request body)
    POST /api/compose         -> re-run compose_sprite_atlas.py, return its result
"""

from __future__ import annotations

import argparse
import base64
import binascii
import copy
import io
import json
import os
import re
import socket
import shutil
import subprocess
import sys
import tempfile
import threading
import time
import uuid
import zipfile

try:
    from PIL import Image, ImageOps
except ImportError:  # pragma: no cover — 파이프라인 필수 의존성이지만 서버는 살아있게
    Image = None
    ImageOps = None
import webbrowser
from functools import partial
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, quote, unquote, urlparse

from curation import (CURATION_FILENAME, SCHEMA_VERSION, apply_pixel_edits, apply_transform,
                      backup_stale_curation, empty_curation, frame_variant, imported_ref_role,
                      load_curation, load_curation_report, pixel_snap_scale, run_revision,
                      source_frame_index, stamp_curation, state_pixel_ops, state_plan)
from extract import heal_run, load_consistent_frames_manifest, load_frames_manifest
import sys as _sys
_sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from sprite_gen.gen import generate_image
from sprite_gen.layout import (frames_dir_rel, raw_rel, row_frame_rel, row_orig_rel,
                               state_frame_total, take_raw_rel)
from runio import publish_guard, read_guard

SCRIPTS_DIR = Path(__file__).resolve().parent
CURATOR_DIR = SCRIPTS_DIR / "curator"
DEFAULT_DIRECTION_REFERENCE_PACK = (
    SCRIPTS_DIR.parents[2]
    / "assets"
    / "generated"
    / "sprite_reference_packs"
    / "8way_cat_player_validated"
)
_MAX_PARALLEL_GENERATIONS = 3
_generation_slots = threading.BoundedSemaphore(_MAX_PARALLEL_GENERATIONS)
_generation_commit_lock = threading.Lock()
_base_generation_lock = threading.Lock()
_generation_job_locks_guard = threading.Lock()
_generation_job_locks: dict[tuple[str, str, str], threading.Lock] = {}
_auto_generation_jobs_lock = threading.Lock()
_auto_generation_jobs: dict[str, dict] = {}
_auto_generation_workers: set[str] = set()
_notification_lock = threading.Lock()
_character_lock = threading.Lock()
_RUN_SNAPSHOT_RETRY_SECONDS = 60.0
_RUN_SNAPSHOT_RETRY_INTERVAL = 0.2


def _generation_job_lock(run_dir: Path, state: str, phase: int | None) -> threading.Lock:
    phase_key = "all" if phase is None else str(phase)
    key = (str(run_dir.resolve()), state, phase_key)
    with _generation_job_locks_guard:
        return _generation_job_locks.setdefault(key, threading.Lock())


def _skeleton_root(run_dir: Path) -> Path:
    return run_dir.parent / ".sprite-skeleton"


def _skeleton_profile_by_id(run_dir: Path, profile_id: str) -> tuple[Path, dict] | None:
    root = _skeleton_root(run_dir)
    if not re.fullmatch(r"[A-Za-z0-9._-]+", profile_id):
        return None
    try:
        profile_dir = (root / "profiles" / profile_id).resolve()
        profile_dir.relative_to((root / "profiles").resolve())
        metadata = json.loads((profile_dir / "profile.json").read_text(encoding="utf-8"))
        if metadata.get("profileId") != profile_id or not isinstance(metadata.get("states"), dict):
            return None
        return profile_dir, metadata
    except (OSError, ValueError, json.JSONDecodeError):
        return None


def _active_skeleton_profile(run_dir: Path) -> tuple[Path, dict] | None:
    """Resolve the skeleton assigned to this character, with legacy active.json support."""
    request_path = run_dir / "sprite-request.json"
    request_states: set[str] = set()
    if request_path.is_file():
        try:
            request = json.loads(request_path.read_text(encoding="utf-8"))
            request_states = set((request.get("states") or {}).keys())
            assignment = request.get("studio_skeleton")
            if isinstance(assignment, dict):
                profile_id = str(assignment.get("profileId") or "")
                if profile_id:
                    return _skeleton_profile_by_id(run_dir, profile_id)
                # New skeleton drafts and directionless characters intentionally
                # have no shared pose source. Do not fall back to the legacy
                # global pointer for either mode.
                if assignment.get("mode") in {"new", "none"}:
                    return None
        except (OSError, json.JSONDecodeError):
            pass

    root = _skeleton_root(run_dir)
    # Legacy characters predate per-character assignment. Match their state
    # contract to the largest compatible saved profile before consulting the
    # old global pointer, so saving a new roll skeleton cannot silently switch
    # an older movement character to that unrelated profile.
    compatible = []
    profiles_dir = root / "profiles"
    if request_states and profiles_dir.is_dir():
        for profile_dir in profiles_dir.iterdir():
            profile = _skeleton_profile_by_id(run_dir, profile_dir.name)
            if profile is None:
                continue
            profile_states = set((profile[1].get("states") or {}).keys())
            if profile_states and profile_states.issubset(request_states):
                compatible.append((len(profile_states), str(profile[1].get("savedAt") or ""), profile))
    if compatible:
        return max(compatible, key=lambda item: (item[0], item[1]))[2]

    pointer = root / "active.json"
    if not pointer.is_file():
        return None
    try:
        active = json.loads(pointer.read_text(encoding="utf-8"))
        return _skeleton_profile_by_id(run_dir, str(active.get("profileId") or ""))
    except (OSError, json.JSONDecodeError):
        return None


def _infer_skeleton_name(metadata: dict) -> str:
    explicit = re.sub(r"\s+", " ", str(metadata.get("name") or "")).strip()
    if explicit:
        return explicit
    states = set((metadata.get("states") or {}).keys())
    movement = {
        f"{direction}_{motion}"
        for direction in _DIRECTION_VIEW
        for motion in ("idle", "walk")
    }
    if movement.issubset(states):
        return "8방향 이동"
    custom_names = {
        str((spec.get("custom_animation") or {}).get("name") or "").strip()
        for spec in (metadata.get("stateSpecs") or {}).values()
        if isinstance(spec, dict)
    }
    custom_names.discard("")
    if len(custom_names) == 1:
        return f"8방향 {next(iter(custom_names))}"
    return f"스켈레톤 {str(metadata.get('profileId') or '')[-6:]}"


def _skeleton_contract(metadata: dict) -> tuple[tuple[str, int], ...]:
    """Return the state/frame contract used to find a safe deletion fallback."""
    contract = []
    for state, entry in (metadata.get("states") or {}).items():
        entry = entry if isinstance(entry, dict) else {}
        frames = int(entry.get("frames") or len(entry.get("phases") or []))
        contract.append((str(state), frames))
    return tuple(sorted(contract))


def _skeleton_profile_usage(run_dir: Path, profile_id: str) -> list[tuple[Path, str]]:
    usage = []
    studio_root = run_dir.parent
    if not studio_root.is_dir():
        return usage
    for candidate in studio_root.iterdir():
        if not candidate.is_dir() or candidate.name.startswith("."):
            continue
        request_path = candidate / "sprite-request.json"
        if not request_path.is_file():
            continue
        try:
            request = json.loads(request_path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            continue
        assignment = request.get("studio_skeleton")
        if not isinstance(assignment, dict) or str(assignment.get("profileId") or "") != profile_id:
            continue
        character = request.get("character") or {}
        name = str(character.get("description") or character.get("id") or candidate.name)
        usage.append((candidate, name))
    return usage


def _skeleton_delete_fallback(run_dir: Path, metadata: dict) -> tuple[Path, dict] | None:
    profiles_dir = _skeleton_root(run_dir) / "profiles"
    target_id = str(metadata.get("profileId") or "")
    target_contract = _skeleton_contract(metadata)
    compatible = []
    if profiles_dir.is_dir():
        for candidate in profiles_dir.iterdir():
            if candidate.name == target_id:
                continue
            profile = _skeleton_profile_by_id(run_dir, candidate.name)
            if profile is None or _skeleton_contract(profile[1]) != target_contract:
                continue
            compatible.append(profile)
    if not compatible:
        return None
    return max(compatible, key=lambda profile: str(profile[1].get("savedAt") or ""))


def list_skeleton_profiles(run_dir: Path) -> list[dict]:
    root = _skeleton_root(run_dir)
    profiles_dir = root / "profiles"
    selected = _active_skeleton_profile(run_dir)
    selected_id = str(selected[1].get("profileId") or "") if selected else ""
    result = []
    if not profiles_dir.is_dir():
        return result
    for profile_dir in sorted(profiles_dir.iterdir(), key=lambda path: path.name):
        profile = _skeleton_profile_by_id(run_dir, profile_dir.name)
        if profile is None:
            continue
        metadata = profile[1]
        states = metadata.get("states") or {}
        usage = _skeleton_profile_usage(run_dir, metadata["profileId"])
        fallback = _skeleton_delete_fallback(run_dir, metadata)
        found_directions = set()
        for state in states:
            for direction in sorted(_DIRECTION_VIEW, key=len, reverse=True):
                if state == direction or state.startswith(f"{direction}_"):
                    found_directions.add(direction)
                    break
        directions = sorted(found_directions, key=lambda direction: list(_DIRECTION_VIEW).index(direction))
        result.append({
            "profileId": metadata["profileId"],
            "name": _infer_skeleton_name(metadata),
            "savedAt": metadata.get("savedAt"),
            "sourceCharacterId": metadata.get("sourceCharacterId"),
            "stateCount": len(states),
            "directions": directions,
            "frameCount": metadata.get("frameCount"),
            "actionPrompt": metadata.get("actionPrompt"),
            "selected": metadata["profileId"] == selected_id,
            "usedBy": [name for _path, name in usage],
            "deletable": not usage or fallback is not None,
        })
    result.sort(key=lambda item: str(item.get("savedAt") or ""), reverse=True)
    return result


def delete_skeleton_profile(run_dir: Path, profile_id: str) -> dict:
    """Delete a profile, safely reassigning explicit users to a compatible version."""
    profile = _skeleton_profile_by_id(run_dir, profile_id)
    if profile is None:
        raise ValueError(f"unknown skeleton profile: {profile_id}")
    profile_dir, metadata = profile
    fallback = _skeleton_delete_fallback(run_dir, metadata)
    usage = _skeleton_profile_usage(run_dir, profile_id)
    if usage and fallback is None:
        names = ", ".join(name for _path, name in usage)
        raise ValueError(
            f"this skeleton is used by {names}; save a compatible replacement before deleting it")

    root = _skeleton_root(run_dir)
    trash_dir = root / f".profile-delete-{profile_id}-{uuid.uuid4().hex}"
    fallback_metadata = fallback[1] if fallback else None
    with _character_lock:
        os.replace(profile_dir, trash_dir)
        try:
            if fallback_metadata is not None:
                for character_dir, _name in usage:
                    request_path = character_dir / "sprite-request.json"
                    request = json.loads(request_path.read_text(encoding="utf-8"))
                    request["studio_skeleton"] = {
                        "mode": "existing",
                        "profileId": fallback_metadata["profileId"],
                        "name": _infer_skeleton_name(fallback_metadata),
                    }
                    _atomic_json(request_path, request)

            pointer = root / "active.json"
            if pointer.is_file():
                try:
                    active = json.loads(pointer.read_text(encoding="utf-8"))
                except (OSError, json.JSONDecodeError):
                    active = {}
                if str(active.get("profileId") or "") == profile_id:
                    if fallback_metadata is not None:
                        _atomic_json(pointer, {
                            "version": 1,
                            "profileId": fallback_metadata["profileId"],
                            "savedAt": fallback_metadata.get("savedAt"),
                        })
                    else:
                        pointer.unlink(missing_ok=True)
        except Exception:
            if trash_dir.is_dir() and not profile_dir.exists():
                os.replace(trash_dir, profile_dir)
            raise
        shutil.rmtree(trash_dir, ignore_errors=True)

    return {
        "ok": True,
        "deletedId": profile_id,
        "fallbackId": fallback_metadata.get("profileId") if fallback_metadata else None,
        "reassignedCharacters": [name for _path, name in usage],
        "profiles": list_skeleton_profiles(run_dir),
    }


def _skeleton_profile_summary(run_dir: Path) -> dict:
    active = _active_skeleton_profile(run_dir)
    if active is None:
        return {"available": False}
    _profile_dir, metadata = active
    return {
        "available": True,
        "profileId": metadata["profileId"],
        "savedAt": metadata.get("savedAt"),
        "sourceCharacterId": metadata.get("sourceCharacterId"),
        "stateCount": len(metadata.get("states") or {}),
        "name": _infer_skeleton_name(metadata),
    }


def _skeleton_generation_refs(run_dir: Path, state: str, phase: int | None) -> list[Path]:
    active = _active_skeleton_profile(run_dir)
    if active is None:
        return []
    profile_dir, metadata = active
    entry = (metadata.get("states") or {}).get(state)
    if not isinstance(entry, dict):
        return []
    refs: list[Path] = []
    if phase is not None:
        phase_paths = entry.get("phases") or []
        if phase < len(phase_paths):
            phase_path = profile_dir / str(phase_paths[phase])
            if phase_path.is_file():
                refs.append(phase_path)
    strip_rel = entry.get("strip")
    if strip_rel:
        strip_path = profile_dir / str(strip_rel)
        if strip_path.is_file() and strip_path not in refs:
            refs.append(strip_path)
    return refs

_WALK_PHASES = (
    "frame 1: left leg forward, right leg back",
    "frame 2: both feet gathered in the passing pose",
    "frame 3: right leg forward, left leg back",
    "frame 4: both feet gathered in the passing pose",
)

_IDLE_PHASES = (
    "frame 1: neutral resting pose at the midpoint of the breath; both feet planted",
    "frame 2: gentle inhale; chest and shoulders rise subtly while both feet stay planted",
    "frame 3: return to the neutral resting pose; both feet remain in exactly the same positions",
    "frame 4: gentle exhale; chest and shoulders settle subtly while both feet stay planted",
)

_DIRECTION_VIEW = {
    "down": "front view, moving toward the viewer",
    "down_right": "three-quarter front view, moving toward the lower-right corner of the image (screen-right / viewer's right)",
    "right": "pure side profile, moving toward the right edge of the image (screen-right / viewer's right)",
    "up_right": "three-quarter back view, moving toward the upper-right corner of the image (screen-right / viewer's right); the face, chest, hips, and feet point toward the right edge, never the left edge",
    "up": "back view, moving away from the viewer; do not show the face",
    "up_left": "three-quarter back view, moving toward the upper-left corner of the image (screen-left / viewer's left); the face, chest, hips, and feet point toward the left edge, never the right edge",
    "left": "pure side profile, moving toward the left edge of the image (screen-left / viewer's left)",
    "down_left": "three-quarter front view, moving toward the lower-left corner of the image (screen-left / viewer's left)",
}

_IDLE_DIRECTION_VIEW = {
    "down": "front view, facing the viewer",
    "down_right": "three-quarter front view, facing the lower-right corner of the image (screen-right / viewer's right)",
    "right": "pure side profile, facing the right edge of the image (screen-right / viewer's right)",
    "up_right": "three-quarter back view, facing the upper-right corner of the image (screen-right / viewer's right); the face, chest, hips, and feet point toward the right edge, never the left edge",
    "up": "back view, facing away from the viewer; do not show the face",
    "up_left": "three-quarter back view, facing the upper-left corner of the image (screen-left / viewer's left); the face, chest, hips, and feet point toward the left edge, never the right edge",
    "left": "pure side profile, facing the left edge of the image (screen-left / viewer's left)",
    "down_left": "three-quarter front view, facing the lower-left corner of the image (screen-left / viewer's left)",
}


def _studio_registry_path(studio_root: Path) -> Path:
    return studio_root / ".sprite-studio.json"


def _safe_character_dir(studio_root: Path, rel: str) -> Path:
    candidate = (studio_root / rel).resolve()
    try:
        candidate.relative_to(studio_root.resolve())
    except ValueError as exc:
        raise ValueError("character path escapes the sprite studio root") from exc
    return candidate


def _initial_character_entry(initial_run_dir: Path) -> dict:
    request = json.loads((initial_run_dir / "sprite-request.json").read_text(encoding="utf-8"))
    character = request.get("character") or {}
    name = str(character.get("description") or character.get("id") or initial_run_dir.name)
    return {"id": initial_run_dir.name, "name": name, "path": initial_run_dir.name}


def load_studio_registry(studio_root: Path, initial_run_dir: Path) -> dict:
    path = _studio_registry_path(studio_root)
    if path.is_file():
        data = json.loads(path.read_text(encoding="utf-8"))
        if not isinstance(data.get("characters"), list):
            raise ValueError(f"invalid sprite studio registry: {path}")
    else:
        data = {"version": 1, "characters": [_initial_character_entry(initial_run_dir)]}
        _atomic_json(path, data)
    initial = _initial_character_entry(initial_run_dir)
    if not any(item.get("path") == initial["path"] for item in data["characters"]):
        data["characters"].insert(0, initial)
        _atomic_json(path, data)
    return data


def studio_character_list(studio_root: Path, initial_run_dir: Path, active_run_dir: Path) -> list[dict]:
    registry = load_studio_registry(studio_root, initial_run_dir)
    result = []
    for item in registry["characters"]:
        run_dir = _safe_character_dir(studio_root, str(item.get("path") or ""))
        if not (run_dir / "sprite-request.json").is_file():
            continue
        request = json.loads((run_dir / "sprite-request.json").read_text(encoding="utf-8"))
        skeleton = copy.deepcopy(request.get("studio_skeleton") or {})
        resolved_profile = _active_skeleton_profile(run_dir)
        if resolved_profile is not None:
            skeleton = {
                "mode": "existing",
                "profileId": resolved_profile[1]["profileId"],
                "name": _infer_skeleton_name(resolved_profile[1]),
            }
        result.append({
            "id": str(item.get("id") or run_dir.name),
            "name": str(item.get("name") or run_dir.name),
            "active": run_dir == active_run_dir.resolve(),
            "hasBase": _base_image_path(run_dir) is not None,
            "baseUrl": (
                f"/api/characters/base?characterId={quote(str(item.get('id') or run_dir.name), safe='')}"
                if _base_image_path(run_dir) is not None else None
            ),
            "deletable": run_dir != initial_run_dir.resolve(),
            "skeleton": skeleton,
            "autoGeneration": auto_generation_status(run_dir),
        })
    return result


def _character_slug(name: str) -> str:
    slug = re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-")
    return slug[:40] or "character"


def _profile_state_specs(metadata: dict, template: dict) -> dict:
    saved = metadata.get("stateSpecs")
    if isinstance(saved, dict) and saved:
        return copy.deepcopy(saved)
    result = {}
    template_states = template.get("states") or {}
    for state, entry in (metadata.get("states") or {}).items():
        if state in template_states:
            result[state] = copy.deepcopy(template_states[state])
            continue
        frames = int((entry or {}).get("frames") or 4)
        result[state] = {
            "frames": frames,
            "fps": min(12, max(6, frames * 2)),
            "loop": True,
            "action": str(metadata.get("actionPrompt") or _infer_skeleton_name(metadata)),
        }
    return result


def _new_skeleton_states(request: dict, assignment: dict) -> dict:
    display_name = re.sub(r"\s+", " ", str(assignment.get("name") or "")).strip()
    prompt = re.sub(r"\s+", " ", str(assignment.get("prompt") or "")).strip()
    if not display_name:
        raise ValueError("new skeleton animation name is required")
    if len(display_name) > 60:
        raise ValueError("animation name must be 60 characters or fewer")
    if not prompt:
        raise ValueError("new skeleton motion prompt is required")
    if len(prompt) > 4000:
        raise ValueError("animation prompt must be 4000 characters or fewer")
    try:
        frame_count = int(assignment.get("frames"))
    except (TypeError, ValueError) as exc:
        raise ValueError("animation frame count must be a number") from exc
    if frame_count < 2 or frame_count > 8:
        raise ValueError("animation frame count must be between 2 and 8")
    suffix = re.sub(r"[^a-z0-9]+", "_", display_name.lower()).strip("_")[:28] or "action"
    directions = list(((request.get("directions") or {}).get("set") or _DIRECTION_VIEW.keys()))
    animation_id = uuid.uuid4().hex
    states = {}
    for direction in directions:
        if direction not in _DIRECTION_VIEW:
            raise ValueError(f"unsupported skeleton direction: {direction}")
        state = f"{direction}_{suffix}"
        states[state] = {
            "frames": frame_count,
            "fps": min(12, max(6, frame_count * 2)),
            "loop": True,
            "action": prompt,
            "custom_animation": {
                "id": animation_id,
                "name": display_name,
                "prompt": prompt,
                "directional_skeleton": True,
            },
        }
    return states


def create_studio_character(studio_root: Path, initial_run_dir: Path, name: str,
                            skeleton: dict | None = None) -> dict:
    name = re.sub(r"\s+", " ", name).strip()
    if not name:
        raise ValueError("character name is required")
    if len(name) > 80:
        raise ValueError("character name must be 80 characters or fewer")
    with _character_lock:
        registry = load_studio_registry(studio_root, initial_run_dir)
        used_ids = {str(item.get("id")) for item in registry["characters"]}
        base_slug = _character_slug(name)
        character_id = base_slug
        serial = 2
        while character_id in used_ids or (studio_root / character_id).exists():
            character_id = f"{base_slug}-{serial}"
            serial += 1
        run_dir = _safe_character_dir(studio_root, character_id)
        run_dir.mkdir(parents=True, exist_ok=False)
        template = json.loads((initial_run_dir / "sprite-request.json").read_text(encoding="utf-8"))
        request = copy.deepcopy(template)
        selection = skeleton if isinstance(skeleton, dict) else None
        mode = str((selection or {}).get("mode") or "existing")
        if selection is None:
            profile = _active_skeleton_profile(initial_run_dir)
            if profile is not None:
                request["states"] = _profile_state_specs(profile[1], template)
                request["studio_skeleton"] = {
                    "mode": "existing",
                    "profileId": profile[1]["profileId"],
                    "name": _infer_skeleton_name(profile[1]),
                }
        elif mode == "new":
            request["states"] = _new_skeleton_states(request, selection)
            request["studio_skeleton"] = {
                "mode": "new",
                "name": re.sub(r"\s+", " ", str(selection.get("name") or "")).strip(),
                "prompt": re.sub(r"\s+", " ", str(selection.get("prompt") or "")).strip(),
                "frames": int(selection.get("frames")),
            }
        elif mode == "existing":
            profile_id = str(selection.get("profileId") or "")
            profile = (_skeleton_profile_by_id(initial_run_dir, profile_id)
                       if profile_id else _active_skeleton_profile(initial_run_dir))
            if profile is None:
                raise ValueError("choose an existing skeleton or create a new skeleton")
            request["states"] = _profile_state_specs(profile[1], template)
            request["studio_skeleton"] = {
                "mode": "existing",
                "profileId": profile[1]["profileId"],
                "name": _infer_skeleton_name(profile[1]),
            }
        elif mode == "none":
            # A base-only character has no directional animation contract. This
            # keeps the curation view empty until animation structure is added.
            request["states"] = {}
            request.pop("directions", None)
            request["studio_skeleton"] = {"mode": "none"}
        else:
            raise ValueError("skeleton mode must be existing, new, or none")
        request["character"] = {
            "id": character_id,
            "description": name,
            "base_image": "base-source.png",
        }
        request["style"] = (
            "match the supplied base character exactly: preserve its proportions, face, "
            "clothing, accessories, palette, outline weight, and rendering style; do not redesign it"
        )
        if isinstance(request.get("directions"), dict):
            request["directions"]["match_longest"] = True
        for spec in (request.get("states") or {}).values():
            if isinstance(spec, dict):
                spec.pop("takes", None)
        _atomic_json(run_dir / "sprite-request.json", request)
        entry = {"id": character_id, "name": name, "path": character_id}
        registry["characters"].append(entry)
        _atomic_json(_studio_registry_path(studio_root), registry)
    return {
        **entry,
        "active": False,
        "hasBase": False,
        "skeleton": copy.deepcopy(request.get("studio_skeleton") or {}),
    }


def select_studio_character(studio_root: Path, initial_run_dir: Path, character_id: str) -> Path:
    registry = load_studio_registry(studio_root, initial_run_dir)
    entry = next((item for item in registry["characters"] if str(item.get("id")) == character_id), None)
    if entry is None:
        raise ValueError(f"unknown character: {character_id}")
    run_dir = _safe_character_dir(studio_root, str(entry.get("path") or ""))
    if not (run_dir / "sprite-request.json").is_file():
        raise ValueError(f"character run is missing sprite-request.json: {character_id}")
    return run_dir


def delete_studio_character(studio_root: Path, initial_run_dir: Path,
                            active_run_dir: Path, character_id: str) -> dict:
    """Delete one non-template character and choose a safe remaining active run."""
    with _character_lock:
        registry = load_studio_registry(studio_root, initial_run_dir)
        entry = next(
            (item for item in registry["characters"] if str(item.get("id")) == character_id),
            None,
        )
        if entry is None:
            raise ValueError(f"unknown character: {character_id}")
        run_dir = _safe_character_dir(studio_root, str(entry.get("path") or ""))
        if run_dir == initial_run_dir.resolve():
            raise ValueError("the startup template character cannot be deleted")
        remaining = [item for item in registry["characters"] if item is not entry]
        if not remaining:
            raise ValueError("at least one character must remain")
        fallback = active_run_dir.resolve()
        if run_dir == fallback:
            fallback_entry = next(
                (item for item in remaining
                 if (_safe_character_dir(studio_root, str(item.get("path") or ""))
                     / "sprite-request.json").is_file()),
                None,
            )
            if fallback_entry is None:
                raise ValueError("no valid character remains after deletion")
            fallback = _safe_character_dir(
                studio_root, str(fallback_entry.get("path") or ""))
        trash_dir = None
        if run_dir.is_dir():
            trash_dir = (studio_root / f".sprite-delete-{run_dir.name}-{uuid.uuid4().hex}").resolve()
            os.replace(run_dir, trash_dir)
        try:
            registry["characters"] = remaining
            _atomic_json(_studio_registry_path(studio_root), registry)
        except Exception:
            if trash_dir is not None and trash_dir.is_dir():
                os.replace(trash_dir, run_dir)
            raise
        if trash_dir is not None:
            shutil.rmtree(trash_dir, ignore_errors=True)
    return {
        "ok": True,
        "deletedId": character_id,
        "activeId": fallback.name,
        "activeRunDir": str(fallback),
    }


def create_custom_animation(run_dir: Path, payload: dict) -> dict:
    """Add exactly one user-defined animation section to this character."""
    display_name = re.sub(r"\s+", " ", str(payload.get("name") or "")).strip()
    prompt = re.sub(r"\s+", " ", str(payload.get("prompt") or "")).strip()
    if not display_name:
        raise ValueError("animation name is required")
    if len(display_name) > 60:
        raise ValueError("animation name must be 60 characters or fewer")
    if not prompt:
        raise ValueError("animation prompt is required")
    if len(prompt) > 4000:
        raise ValueError("animation prompt must be 4000 characters or fewer")
    try:
        frame_count = int(payload.get("frames"))
    except (TypeError, ValueError) as exc:
        raise ValueError("animation frame count must be a number") from exc
    if frame_count < 2 or frame_count > 8:
        raise ValueError("animation frame count must be between 2 and 8")
    if _base_image_path(run_dir) is None:
        raise ValueError("create a base character before adding an animation")

    request_path = run_dir / "sprite-request.json"
    with _generation_commit_lock:
        request = json.loads(request_path.read_text(encoding="utf-8"))
        base_suffix = re.sub(r"[^a-z0-9]+", "_", display_name.lower()).strip("_")[:32]
        if not base_suffix:
            base_suffix = "animation"
        suffix = f"custom_{base_suffix}"
        sequence = 2
        while suffix in request.get("states", {}):
            suffix = f"custom_{base_suffix}_{sequence}"
            sequence += 1
        animation_id = uuid.uuid4().hex
        fps = min(12, max(6, frame_count * 2))
        state = suffix
        request["states"][state] = {
            "frames": frame_count,
            "fps": fps,
            "loop": False,
            "action": prompt,
            "custom_animation": {
                "id": animation_id,
                "name": display_name,
                "prompt": prompt,
            },
        }
        _atomic_json(request_path, request)
    _add_notification(
        run_dir,
        "animation_added",
        state=state,
        detail={"name": display_name, "frames": frame_count, "stateCount": 1},
    )
    return {
        "ok": True,
        "animationId": animation_id,
        "name": display_name,
        "frames": frame_count,
        "state": state,
        "states": [state],
    }


def _url(*parts) -> str:
    """/-rooted URL with every path segment percent-encoded. base/ref/state/frame names
    can contain `#`, `%`, space, quotes, non-ASCII — unencoded they break the URL (a `#`
    becomes a fragment → 404) or leak into HTML attributes. do_GET unquote()s on serving,
    so this round-trips; unreserved names (e.g. down_walk, frame-0.png) are unchanged."""
    return "/" + "/".join(quote(str(p), safe="") for p in parts)


def _atomic_json(path: Path, payload: dict) -> None:
    """Write JSON beside its destination and publish it with one replace."""
    text = json.dumps(payload, ensure_ascii=False, indent=2) + "\n"
    fd, tmp_name = tempfile.mkstemp(dir=str(path.parent), prefix=f".{path.name}-", suffix=".tmp")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            handle.write(text)
        os.replace(tmp_name, path)
    except BaseException:
        if os.path.exists(tmp_name):
            os.unlink(tmp_name)
        raise


def _notifications_path(run_dir: Path) -> Path:
    return run_dir / ".sprite-notifications.json"


def _load_notifications_unlocked(run_dir: Path) -> list[dict]:
    path = _notifications_path(run_dir)
    if not path.is_file():
        return []
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
        items = payload.get("notifications") if isinstance(payload, dict) else None
        return items if isinstance(items, list) else []
    except (OSError, ValueError, json.JSONDecodeError):
        return []


def _add_notification(run_dir: Path, kind: str, *, state: str | None = None,
                      phase: int | None = None, success: bool = True,
                      detail: dict | None = None) -> dict:
    with _notification_lock:
        items = _load_notifications_unlocked(run_dir)
        item = {
            "id": uuid.uuid4().hex,
            "kind": kind,
            "state": state,
            "phase": phase,
            "success": success,
            "detail": detail or {},
            "createdAt": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
            "read": False,
        }
        items.append(item)
        items = items[-100:]
        _atomic_json(_notifications_path(run_dir), {"version": 1, "notifications": items})
        return copy.deepcopy(item)


def list_notifications(run_dir: Path) -> dict:
    with _notification_lock:
        items = _load_notifications_unlocked(run_dir)
        snapshot = list(reversed(copy.deepcopy(items)))
    return {
        "notifications": snapshot,
        "unread": sum(1 for item in snapshot if not item.get("read")),
    }


def mark_notifications_read(run_dir: Path, payload: dict) -> dict:
    notification_id = str(payload.get("id") or "")
    mark_all = bool(payload.get("all"))
    with _notification_lock:
        items = _load_notifications_unlocked(run_dir)
        for item in items:
            if mark_all or (notification_id and item.get("id") == notification_id):
                item["read"] = True
        _atomic_json(_notifications_path(run_dir), {"version": 1, "notifications": items})
        unread = sum(1 for item in items if not item.get("read"))
    return {"ok": True, "unread": unread}


def _base_image_path(run_dir: Path) -> Path | None:
    for candidate in sorted(run_dir.glob("base-source.*")):
        if candidate.suffix.lower() in (".png", ".jpg", ".jpeg", ".webp"):
            return candidate
    return None


def _base_reference_path(run_dir: Path) -> Path | None:
    for candidate in sorted(run_dir.glob("base-reference.*")):
        if candidate.suffix.lower() in (".png", ".jpg", ".jpeg", ".webp"):
            return candidate
    return None


def _decode_base_upload(payload: dict):
    """Validate a browser image data URL and return a normalized RGBA image."""
    if Image is None:
        raise RuntimeError("Pillow is required for base image upload")
    data_url = str(payload.get("dataUrl") or "")
    match = re.fullmatch(r"data:image/(png|jpeg|jpg|webp);base64,(.+)", data_url, re.DOTALL | re.IGNORECASE)
    if not match:
        raise ValueError("PNG, JPEG, or WebP image data is required")
    try:
        raw = base64.b64decode(match.group(2), validate=True)
    except (ValueError, binascii.Error) as exc:
        raise ValueError("invalid base64 image upload") from exc
    if len(raw) > 20 * 1024 * 1024:
        raise ValueError("base image is larger than 20 MB")
    try:
        with Image.open(io.BytesIO(raw)) as opened:
            opened.verify()
        with Image.open(io.BytesIO(raw)) as opened:
            image = opened.convert("RGBA")
    except Exception as exc:
        raise ValueError(f"cannot decode uploaded image: {exc}") from exc
    if image.width < 8 or image.height < 8 or image.width * image.height > 40_000_000:
        raise ValueError("base image dimensions are outside the supported range")
    return image


def _publish_png(image, target: Path) -> None:
    target.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp_name = tempfile.mkstemp(dir=str(target.parent), prefix=f".{target.stem}-", suffix=".png")
    os.close(fd)
    try:
        image.save(tmp_name, format="PNG")
        os.replace(tmp_name, target)
    except BaseException:
        if os.path.exists(tmp_name):
            os.unlink(tmp_name)
        raise


def save_base_upload(run_dir: Path, payload: dict) -> dict:
    """Backward-compatible direct base upload (no generation prompt)."""
    image = _decode_base_upload(payload)
    target = run_dir / "base-source.png"
    _publish_png(image, target)
    # Avoid an older extension winning the deterministic base-source glob.
    for old in run_dir.glob("base-source.*"):
        if old != target and old.suffix.lower() in (".jpg", ".jpeg", ".webp"):
            old.unlink(missing_ok=True)
    return {"ok": True, "baseUrl": _url("run", target.name), "width": image.width, "height": image.height}


def create_base_character(run_dir: Path, payload: dict) -> dict:
    """Use an uploaded reference as-is, or generate a new base from it and a prompt."""
    user_prompt = str(payload.get("prompt") or "").strip()[:4000]
    reference = run_dir / "base-reference.png"
    data_url = str(payload.get("dataUrl") or "").strip()
    reused_reference = not bool(data_url)
    if data_url:
        image = _decode_base_upload(payload)
        _publish_png(image, reference)
    else:
        saved_reference = _base_reference_path(run_dir)
        if saved_reference is None:
            raise ValueError("upload a reference image before creating a base character")
        if Image is None:
            raise RuntimeError("Pillow is required for base character generation")
        with Image.open(saved_reference) as opened:
            image = opened.convert("RGBA")
        if saved_reference != reference:
            _publish_png(image, reference)

    target = run_dir / "base-source.png"
    if not user_prompt:
        _publish_png(image, target)
        _add_notification(run_dir, "base_generated", state="__base__", detail={"generated": False})
        return {
            "ok": True, "generated": False,
            "baseUrl": _url("run", target.name),
            "width": image.width, "height": image.height,
            "referenceReused": reused_reference,
        }

    if not _base_generation_lock.acquire(blocking=False):
        raise RuntimeError("base character generation is already running")
    label = f"base-{time.strftime('%Y%m%d-%H%M%S')}-{uuid.uuid4().hex[:6]}"
    history_dir = run_dir / "base-generations"
    generated_path = history_dir / f"{label}.png"
    prompt_path = history_dir / f"{label}.txt"
    request = json.loads((run_dir / "sprite-request.json").read_text(encoding="utf-8"))
    style = str(request.get("style") or "match the supplied reference exactly")
    generation_prompt = f"""Create one production-ready base character image using the attached uploaded image as the identity and visual-style reference.

User request: {user_prompt}

Preserve the recognizable character identity, species, face, body proportions, palette, line weight, and rendering style of the reference. Apply the user's requested role, outfit, props, or design change clearly, while keeping it the same character. {style}

Output exactly one centered, isolated, full-body character in a neutral standing pose, facing the viewer or a slight three-quarter front view. Keep the entire silhouette visible with generous padding. Transparent background. No text, labels, border, sprite sheet, multiple views, multiple characters, scenery, or cast shadow.
""".strip()
    history_dir.mkdir(parents=True, exist_ok=True)
    prompt_path.write_text(generation_prompt + "\n", encoding="utf-8")
    try:
        with _generation_slots:
            generated = generate_image(
                "codex", generation_prompt, generated_path,
                refs=[reference], keep_session=False,
            )
        with Image.open(generated_path) as opened:
            generated_image = opened.convert("RGBA")
        _publish_png(generated_image, target)
        result = {
            "ok": True, "generated": True,
            "baseUrl": _url("run", target.name),
            "width": generated_image.width, "height": generated_image.height,
            "provider": generated.provider,
            "referenceReused": reused_reference,
        }
        _add_notification(
            run_dir, "base_generated", state="__base__",
            detail={"generated": True, "provider": generated.provider},
        )
        return result
    except (Exception, SystemExit) as exc:
        _add_notification(
            run_dir, "base_failed", state="__base__", success=False,
            detail={"error": str(exc)},
        )
        raise
    finally:
        _base_generation_lock.release()


def _state_direction(request: dict, state: str) -> str:
    directions = (request.get("directions") or {}).get("set") or []
    for direction in sorted(directions, key=len, reverse=True):
        if state == direction or state.startswith(direction + "_"):
            return direction
    return state.split("_", 1)[0]


def _ordinal(value: int) -> str:
    words = {
        1: "first", 2: "second", 3: "third", 4: "fourth", 5: "fifth",
        6: "sixth", 7: "seventh", 8: "eighth", 9: "ninth", 10: "tenth",
    }
    if value in words:
        return words[value]
    if 10 <= value % 100 <= 20:
        suffix = "th"
    else:
        suffix = {1: "st", 2: "nd", 3: "rd"}.get(value % 10, "th")
    return f"{value}{suffix}"


def _generation_prompt(request: dict, state: str, extra_prompt: str, phase: int | None,
                       pose_template: bool = False, direction_anchor: bool = False,
                       directional_reference_pack: bool = False) -> str:
    spec = request["states"][state]
    frame_count = int(spec.get("frames", 4))
    direction = _state_direction(request, state)
    is_idle = state.endswith("_idle")
    is_walk = state.endswith("_walk")
    is_custom = bool(spec.get("custom_animation")) or not (is_idle or is_walk)
    custom_metadata = spec.get("custom_animation") or {}
    is_directional_custom = (
        is_custom
        and bool(custom_metadata.get("directional_skeleton"))
        and direction in _IDLE_DIRECTION_VIEW
    )
    if is_directional_custom:
        # A directional attack acts in place, so use the explicit facing view
        # rather than the locomotion wording used by a walk cycle.
        view = _IDLE_DIRECTION_VIEW[direction]
    elif is_custom and spec.get("custom_animation"):
        view = "the same canonical facing direction as the supplied base character"
    else:
        view_map = _IDLE_DIRECTION_VIEW if is_idle else _DIRECTION_VIEW
        view = view_map.get(direction, direction.replace("_", " "))
    action = str(spec.get("action") or "animation")
    if is_idle and frame_count == 4:
        phases = list(_IDLE_PHASES)
    elif is_walk and frame_count == 4:
        phases = list(_WALK_PHASES)
    else:
        phases = []
        for index in range(frame_count):
            if index == 0:
                stage = "clear anticipation or starting pose"
            elif index == frame_count - 1:
                stage = "clear finish or recovery pose"
            else:
                progress = round(index * 100 / max(1, frame_count - 1))
                stage = f"distinct in-between pose at about {progress}% of the action"
            phases.append(f"Frame {index + 1}: {stage} for '{action}'")
    facing_rule = (
        "The head, torso, hips, legs, and feet must all face this same direction. The character stays in place."
        if is_idle else
        "The head, torso, hips, legs, and feet must all face this same direction. "
        "Keep a fixed root and ground line unless the requested action explicitly needs a lunge or displacement."
        if is_custom else
        "The head, torso, hips, legs, and feet must all face and move in this same direction."
    )
    motion_rules = (
        "This is a breathing idle, not a walk cycle. Lock both feet to the ground in the exact same "
        "positions in every panel. No stepping, stride, leg alternation, foot sliding, or locomotion. "
        "Keep the root position and ground line fixed. Motion must be subtle and limited to breathing "
        "in the chest/shoulders and a very small body bob; a restrained ear or tail secondary motion is allowed."
        if is_idle else
        "The left/right leg alternation is mandatory. Frames 1 and 3 must use opposite leading legs. "
        "Frames 2 and 4 are gathered passing poses, not copies of a leading-leg pose."
        if is_walk else
        "Make the requested action unmistakable as a readable game animation. Every frame must be a distinct "
        "chronological pose with consistent handedness, limb continuity, scale, ground line, and facing. "
        "Do not duplicate poses or add unrelated locomotion."
    )
    focus = ""
    if phase is not None:
        focus = (
            f"\nThis is a targeted reroll for {phases[phase]}. Make that panel especially clear, "
            f"while still returning the complete {frame_count}-panel cycle so identity and motion can be checked."
        )
    extra = f"\nUser correction: {extra_prompt.strip()}" if extra_prompt.strip() else ""
    screen_axis_rule = ""
    if direction.endswith("_right") or direction == "right":
        screen_axis_rule = (
            "\nScreen-axis lock: RIGHT means the right-hand edge of the output image from the viewer's "
            "perspective, not the character's anatomical right. Never mirror the pose to face screen-left."
        )
    elif direction.endswith("_left") or direction == "left":
        screen_axis_rule = (
            "\nScreen-axis lock: LEFT means the left-hand edge of the output image from the viewer's "
            "perspective, not the character's anatomical left. Never mirror the pose to face screen-right."
        )
    pose_contract = ""
    if pose_template:
        frame_phrase = "four-frame" if frame_count == 4 else f"{frame_count}-frame"
        pose_index = 3 if direction_anchor else 2
        strip_index = pose_index + 1 if phase is not None else (4 if direction_anchor else 3)
        if phase is not None:
            pose_reference = (
                f"The {_ordinal(pose_index)} attached image is the exact target-frame pose guide and the "
                f"{_ordinal(strip_index)} is the complete {frame_phrase} pose strip."
            )
        else:
            pose_reference = (
                f"The {_ordinal(strip_index)} attached image is the complete {frame_phrase} pose strip."
            )
        anchor_reference = ""
        if direction_anchor:
            anchor_reference = (
                " The second attached image is an accepted sprite of this same character in the target "
                "direction. It is authoritative for screen-left/screen-right facing, head/torso/hip angle, "
                "and the side on which asymmetric equipment appears; do not copy its idle motion."
            )
        pose_contract = f"""
Pose skeleton lock: the first attached image is the ONLY identity, species, outfit, palette, and rendering reference.{anchor_reference} {pose_reference}
Use the pose guide only for geometry and timing. Match its panel order, facing, head/torso/hip angle, limb placement, leading foot, left/right foot crossing, ground contact, silhouette, scale, and root position as closely as possible. Do not copy any character identity, clothing, colors, facial features, or accessories from the grayscale pose guide. When identity and pose references differ, take appearance exclusively from the first image and pose exclusively from the guide.
"""
    reference_pack_contract = ""
    if directional_reference_pack:
        reference_pack_contract = """
Directional reference-pack rule: an additional attached sprite is a screen-axis and layout reference only. Use it to resolve front/back/side/three-quarter facing, ground line, silhouette placement, and left-versus-right orientation. If it is a four-frame walk strip, use it only for motion rhythm, foot contacts, and leading-foot alternation. Never copy its species, face, clothing, palette, props, or accessories; those remain locked to the first base-character image.
"""
    style = str(request.get("style") or "match the supplied reference exactly")
    phase_contract = "\n".join(f"{index + 1}. {description}" for index, description in enumerate(phases))
    return f"""Create a production-ready 2D game sprite strip from the supplied base character.

Identity lock: the first attached image is the sole source of character identity. Preserve its exact species, face, body proportions, clothing, helmet, backpack, tail, palette, outline weight, accessories, and pixel-art rendering. Do not redesign, substitute, or beautify the character. Any later attached image is a pose/layout guide only and must never contribute a different cat, outfit, colors, face, or props.
Direction: {direction} — {view}. {facing_rule}{screen_axis_rule}
Action: {action}.
Motion contract, left to right, exactly {frame_count} panels:
{phase_contract}
{motion_rules}{focus}{extra}
{pose_contract}
{reference_pack_contract}

Output contract: one horizontal strip containing exactly {frame_count} isolated full-body sprites, in the specified order, evenly spaced, equal scale and ground line. Use a perfectly flat solid #FF00FF background. No text, labels, arrows, borders, grid, scenery, cast shadow, extra character, or extra panel. Keep generous magenta separation between panels. Do not add motion trails, slash arcs, glow, particles, or speed lines unless the user explicitly requested them. Outside colors already locked by the identity reference, never use pink, purple, fuchsia, magenta, or any color close to #FF00FF on the character, weapon, outline, highlight, shadow, or effect; those colors are reserved exclusively for the removable background.
Style contract: {style}
""".strip()


def _accepted_direction_anchor_ref(run_dir: Path, request: dict, state: str) -> Path | None:
    """Return an accepted same-character idle frame for this state's screen direction.

    Grayscale pose guides are easy for an image model to mirror.  A generated
    idle frame from the same direction provides an unambiguous full-colour
    screen-axis reference while the base image remains the identity source.
    """
    direction = _state_direction(request, state)
    anchor_state = f"{direction}_idle"
    if state == anchor_state or anchor_state not in (request.get("states") or {}):
        return None
    try:
        manifest = load_consistent_frames_manifest(
            run_dir, allow_pending_states=True) or {"rows": []}
        row = next(
            (candidate for candidate in manifest.get("rows", [])
             if candidate.get("state") == anchor_state),
            None,
        )
        if not row:
            return None
        curation, _ = load_curation_report(run_dir)
        selected = (
            (((curation or {}).get("states") or {}).get(anchor_state) or {}).get("selected") or []
        )
        indices = list(selected) + list(range(int(row.get("frames") or 0)))
        seen: set[int] = set()
        for raw_index in indices:
            try:
                index = int(raw_index)
            except (TypeError, ValueError):
                continue
            if index in seen:
                continue
            seen.add(index)
            try:
                path = run_dir / row_frame_rel(row, index)
            except (SystemExit, ValueError, TypeError, IndexError):
                continue
            if path.is_file():
                return path
    except (OSError, ValueError, SystemExit):
        return None
    return None


def _directional_reference_pack_anchor(run_dir: Path, request: dict, state: str) -> Path | None:
    """Return a same-direction layout or gait reference when no accepted anchor exists."""
    direction = _state_direction(request, state)
    if not direction:
        return None
    suffix = "walk" if state.endswith("_walk") else "idle"
    candidates = [
        run_dir / "references" / "anchors" / f"{direction}_{suffix}.png",
        DEFAULT_DIRECTION_REFERENCE_PACK / f"{direction}_{suffix}.png",
    ]
    for candidate in candidates:
        if candidate.is_file():
            return candidate
    return None


def _generation_refs(run_dir: Path, request: dict, state: str,
                     pose_refs: list[Path] | None = None,
                     direction_anchor_ref: Path | None = None,
                     directional_reference_pack_ref: Path | None = None) -> list[Path]:
    refs: list[Path] = []
    base = _base_image_path(run_dir)
    if base:
        refs.append(base)
    # Explicitly supplied anchors are trusted by the caller (and retained for
    # the curation API), but normal generation deliberately passes none: old
    # colorful anchors can be mistaken for a second identity by the model.
    if direction_anchor_ref and direction_anchor_ref.is_file() and direction_anchor_ref not in refs:
        refs.append(direction_anchor_ref)
    if (not direction_anchor_ref and directional_reference_pack_ref
            and directional_reference_pack_ref.is_file()
            and directional_reference_pack_ref not in refs):
        refs.append(directional_reference_pack_ref)
    for pose_ref in pose_refs or []:
        if pose_ref.is_file() and pose_ref not in refs:
            refs.append(pose_ref)
    # Keep the provider input compact and deterministic: identity first, then
    # grayscale pose guides. Previously selected generated frames are omitted
    # because stale candidates can carry another character's identity.
    return refs[:5]


def _extract_state(run_dir: Path, state: str) -> dict:
    env = dict(os.environ)
    env["PYTHONPATH"] = str(SCRIPTS_DIR.parent) + os.pathsep + env.get("PYTHONPATH", "")
    proc = subprocess.run(
        [sys.executable, str(SCRIPTS_DIR / "extract_sprite_row_frames.py"),
         "--run-dir", str(run_dir), "--states", state, "--allow-slot-fallback"],
        capture_output=True, text=True, env=env,
    )
    return {"ok": proc.returncode == 0, "stdout": proc.stdout, "stderr": proc.stderr,
            "returncode": proc.returncode}


def _generation_run_busy(run_dir: Path) -> bool:
    run_key = str(run_dir.resolve())
    with _generation_job_locks_guard:
        return any(key[0] == run_key and lock.locked()
                   for key, lock in _generation_job_locks.items())


def recover_orphan_generations(run_dir: Path) -> list[str]:
    """Publish completed studio outputs left in `.takes/` by a stopped server.

    Image generation writes to a unique take path before the commit step. If the
    server closes in that small window, the expensive image is still valid but
    the request has no primary raw/manifest row. Recover only when no generation
    for this run is active, and roll back the promotion if extraction fails.
    """
    if _generation_run_busy(run_dir):
        return []
    recovered: list[str] = []
    request_path = run_dir / "sprite-request.json"
    with _generation_commit_lock:
        request = json.loads(request_path.read_text(encoding="utf-8"))
        for state, spec in (request.get("states") or {}).items():
            primary = run_dir / raw_rel(request, state)
            if primary.is_file() or (spec.get("takes") or []):
                continue
            if _state_has_generated_frames(run_dir, request, state):
                continue
            take_dir = (run_dir / take_raw_rel(request, state, "placeholder")).parent
            if not take_dir.is_dir():
                continue
            candidates = [
                path for path in take_dir.glob("studio-*.png")
                if path.is_file() and not path.name.endswith(".raw.png")
                and time.time() - path.stat().st_mtime >= 3
            ]
            if not candidates:
                continue
            source = max(candidates, key=lambda path: path.stat().st_mtime)
            source_sidecar = Path(str(source) + ".raw.png")
            primary_sidecar = Path(str(primary) + ".raw.png")
            primary.parent.mkdir(parents=True, exist_ok=True)
            os.replace(source, primary)
            if source_sidecar.is_file():
                os.replace(source_sidecar, primary_sidecar)
            extracted = _extract_state(run_dir, state)
            if extracted["ok"]:
                recovered.append(state)
                _add_notification(
                    run_dir, "state_generated", state=state,
                    detail={"recovered": True, "frameCount": int(spec.get("frames", 0))},
                )
                continue
            source.parent.mkdir(parents=True, exist_ok=True)
            if primary.is_file():
                os.replace(primary, source)
            if primary_sidecar.is_file():
                os.replace(primary_sidecar, source_sidecar)
    return recovered


def _select_generated_phase(run_dir: Path, state: str, phase: int, start: int, phase_count: int) -> None:
    curation, _ = load_curation_report(run_dir)
    payload = curation or empty_curation()
    entry = (payload.setdefault("states", {})).setdefault(state, {})
    selected = []
    for value in entry.get("selected") or []:
        try:
            index = int(value)
        except (TypeError, ValueError):
            continue
        if index % phase_count != phase:
            selected.append(index)
    selected.append(start + phase)
    selected.sort(key=lambda index: index % phase_count)
    entry["selected"] = selected
    order = [int(value) for value in (entry.get("order") or []) if str(value).lstrip("-").isdigit()]
    target = start + phase
    entry["order"] = selected + [index for index in order if index not in selected and index != target]
    write_curation_atomic(run_dir, payload)


def generate_state_take(run_dir: Path, payload: dict) -> dict:
    """Generate one sprite strip, append it as a take, and extract only that state."""
    state = str(payload.get("state") or "")
    extra_prompt = str(payload.get("extraPrompt") or "")[:4000]
    phase_raw = payload.get("phase")
    phase = None if phase_raw is None else int(phase_raw)
    request_path = run_dir / "sprite-request.json"
    request = json.loads(request_path.read_text(encoding="utf-8"))
    if state not in (request.get("states") or {}):
        raise ValueError(f"unknown state: {state}")
    phase_count = int(request["states"][state].get("frames", 0))
    if phase_count < 2 or phase_count > 8:
        raise ValueError(f"studio generation supports 2 to 8 frames; {state} has {phase_count}")
    if phase is not None and phase not in range(phase_count):
        raise ValueError(f"phase must be between 0 and {phase_count - 1}")
    if _base_image_path(run_dir) is None:
        raise ValueError("upload a base image before generating sprites")
    job_lock = _generation_job_lock(run_dir, state, phase)
    if not job_lock.acquire(blocking=False):
        target = "full section" if phase is None else f"frame {phase + 1}"
        raise RuntimeError(f"generation is already running for {state} {target}")
    label = f"studio-{time.strftime('%Y%m%d-%H%M%S')}-{uuid.uuid4().hex[:6]}"
    take_rel = take_raw_rel(request, state, label)
    take_path = run_dir / take_rel
    pose_refs = _skeleton_generation_refs(run_dir, state, phase)
    # Existing generated rows and the global directional pack may belong to a
    # different character. They remain visible for curation, but are not fed
    # back into generation as identity references.
    direction_anchor_ref = None
    directional_reference_pack_ref = None
    prompt = _generation_prompt(
        request, state, extra_prompt, phase,
        bool(pose_refs), bool(direction_anchor_ref),
        bool(directional_reference_pack_ref and not direction_anchor_ref),
    )
    prompt_path = run_dir / "prompts" / "studio" / state / f"{label}.txt"
    prompt_path.parent.mkdir(parents=True, exist_ok=True)
    prompt_path.write_text(prompt + "\n", encoding="utf-8")
    notify = payload.get("notify", True) is not False
    try:
        take_path.parent.mkdir(parents=True, exist_ok=True)
        with _generation_slots:
            generated = generate_image(
                "codex", prompt, take_path,
                refs=_generation_refs(
                    run_dir, request, state, pose_refs, direction_anchor_ref,
                    directional_reference_pack_ref),
                keep_session=False,
            )

        # Generation is parallel; publication is serialized. Re-read the
        # request here so a take committed by another state is never lost.
        with _generation_commit_lock:
            latest_request = json.loads(request_path.read_text(encoding="utf-8"))
            if state not in (latest_request.get("states") or {}):
                raise RuntimeError(f"section disappeared while generation was running: {state}")
            primary_path = run_dir / raw_rel(latest_request, state)
            publish_as_primary = (
                not primary_path.is_file()
                and not (latest_request["states"][state].get("takes") or [])
            )
            start = 0 if publish_as_primary else state_frame_total(latest_request, state)
            previous_takes = json.loads(json.dumps(
                latest_request["states"][state].get("takes") or []))
            primary_sidecar = Path(str(primary_path) + ".raw.png")
            take_sidecar = Path(str(take_path) + ".raw.png")
            if publish_as_primary:
                primary_path.parent.mkdir(parents=True, exist_ok=True)
                os.replace(take_path, primary_path)
                if take_sidecar.is_file():
                    os.replace(take_sidecar, primary_sidecar)
            else:
                latest_request["states"][state].setdefault("takes", []).append(
                    {"label": label, "frames": phase_count})
                _atomic_json(request_path, latest_request)
            extracted = _extract_state(run_dir, state)
            if not extracted["ok"]:
                if publish_as_primary:
                    take_path.parent.mkdir(parents=True, exist_ok=True)
                    if primary_path.is_file():
                        os.replace(primary_path, take_path)
                    if primary_sidecar.is_file():
                        os.replace(primary_sidecar, take_sidecar)
                else:
                    latest_request["states"][state]["takes"] = previous_takes
                    _atomic_json(request_path, latest_request)
                raise RuntimeError(
                    (extracted["stderr"] or extracted["stdout"] or "frame extraction failed").strip())
            if phase is not None:
                _select_generated_phase(run_dir, state, phase, start, phase_count)
            else:
                curation, _ = load_curation_report(run_dir)
                current = (((curation or {}).get("states") or {}).get(state) or {}).get("selected") or []
                if not current:
                    for target_phase in range(phase_count):
                        _select_generated_phase(run_dir, state, target_phase, start, phase_count)
        result = {
            "ok": True, "state": state, "take": label,
            "generatedIndices": list(range(start, start + phase_count)),
            "targetIndex": start + phase if phase is not None else None,
            "provider": generated.provider,
            "poseTemplateUsed": bool(pose_refs),
            "publishedAsPrimary": publish_as_primary,
        }
        if notify:
            _add_notification(
                run_dir, "phase_generated" if phase is not None else "state_generated",
                state=state, phase=phase,
                detail={"take": label, "frameCount": phase_count},
            )
        return result
    except (Exception, SystemExit) as exc:
        if notify:
            _add_notification(
                run_dir, "phase_failed" if phase is not None else "state_failed",
                state=state, phase=phase, success=False, detail={"error": str(exc)},
            )
        raise
    finally:
        job_lock.release()


def _auto_generation_key(run_dir: Path) -> str:
    return str(run_dir.resolve())


def _auto_generation_path(run_dir: Path) -> Path:
    return run_dir / "studio-auto-generation.json"


def _persist_auto_generation_job(run_dir: Path, job: dict) -> None:
    _atomic_json(_auto_generation_path(run_dir), copy.deepcopy(job))


def _load_persisted_auto_generation_job(run_dir: Path) -> dict | None:
    path = _auto_generation_path(run_dir)
    if not path.is_file():
        return None
    try:
        job = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None
    if not isinstance(job, dict) or not job.get("id") or not isinstance(job.get("states"), list):
        return None
    job.setdefault("total", len(job["states"]))
    job.setdefault("results", [])
    job["completed"] = len(job["results"])
    return job


def _state_has_generated_frames(run_dir: Path, request: dict, state: str) -> bool:
    state_dir = run_dir / frames_dir_rel(request, state)
    if not state_dir.is_dir():
        return False
    return any(
        path.is_file() and not path.name.endswith(".plain.png")
        for path in state_dir.glob("frame-*.png")
    )


def auto_generation_status(run_dir: Path) -> dict:
    key = _auto_generation_key(run_dir)
    resume = False
    with _auto_generation_jobs_lock:
        current = _auto_generation_jobs.get(key)
        if current is None:
            current = _load_persisted_auto_generation_job(run_dir)
            if current is None:
                return {"status": "idle", "total": 0, "completed": 0}
            if current.get("status") in ("queued", "running"):
                current["status"] = "queued"
                current["resumed"] = True
                current["resumedAt"] = time.strftime("%Y-%m-%dT%H:%M:%S%z")
                current["currentState"] = None
                current["currentIndex"] = None
                resume = key not in _auto_generation_workers
                if resume:
                    _auto_generation_workers.add(key)
                _persist_auto_generation_job(run_dir, current)
            _auto_generation_jobs[key] = current
        snapshot = copy.deepcopy(current)
    if resume:
        threading.Thread(
            target=_run_auto_generation,
            args=(run_dir.resolve(), str(snapshot["id"]), list(snapshot["states"])),
            name=f"sprite-auto-resume-{run_dir.name}",
            daemon=True,
        ).start()
    return snapshot


def _retryable_generation_quality_failure(error: BaseException) -> bool:
    """Return whether a fresh take can fix a generated-image extraction defect."""
    return "chroma-adjacent pixels" in str(error).lower()


_CHROMA_QUALITY_RETRY_PROMPT = (
    "The previous take could not be extracted because foreground pixels blended with the #FF00FF "
    "background. Generate a clean replacement. Use no motion trail, slash arc, glow, particle, or "
    "speed line. Keep every foreground edge crisp and use no pink, purple, fuchsia, magenta, or "
    "chroma-adjacent color anywhere in the sprite. Convey the motion only through the body and weapon pose."
)


def _run_auto_generation(run_dir: Path, job_id: str, states: list[str]) -> None:
    key = _auto_generation_key(run_dir)
    try:
        with _auto_generation_jobs_lock:
            job = _auto_generation_jobs.get(key)
            if job is None or job.get("id") != job_id:
                return
            job["status"] = "running"
            _persist_auto_generation_job(run_dir, job)

        for index, state in enumerate(states):
            with _auto_generation_jobs_lock:
                job = _auto_generation_jobs.get(key)
                if job is None or job.get("id") != job_id:
                    return
                completed_states = {
                    str(item.get("state")) for item in job.get("results", [])
                    if isinstance(item, dict) and item.get("state")
                }
                if state in completed_states:
                    continue
                job["currentState"] = state
                job["currentIndex"] = index
                _persist_auto_generation_job(run_dir, job)

            recovered = False
            if job.get("resumed") and not job.get("regenerateExisting"):
                try:
                    request = json.loads((run_dir / "sprite-request.json").read_text(encoding="utf-8"))
                    recovered = _state_has_generated_frames(run_dir, request, state)
                except (OSError, json.JSONDecodeError):
                    recovered = False
            try:
                if recovered:
                    result = {"poseTemplateUsed": True, "recovered": True}
                else:
                    try:
                        result = generate_state_take(
                            run_dir, {"state": state, "notify": False})
                    except (Exception, SystemExit) as first_error:
                        if not _retryable_generation_quality_failure(first_error):
                            raise
                        result = generate_state_take(run_dir, {
                            "state": state,
                            "notify": False,
                            "extraPrompt": _CHROMA_QUALITY_RETRY_PROMPT,
                        })
                        result["qualityRetry"] = True
            except (Exception, SystemExit) as exc:
                with _auto_generation_jobs_lock:
                    job = _auto_generation_jobs.get(key)
                    if job is None or job.get("id") != job_id:
                        return
                    job["status"] = "failed"
                    job["error"] = str(exc)
                    job["failedState"] = state
                    job["currentState"] = None
                    job["finishedAt"] = time.strftime("%Y-%m-%dT%H:%M:%S%z")
                    kind = job.get("kind") or "auto"
                    label = job.get("label")
                    _persist_auto_generation_job(run_dir, job)
                _add_notification(
                    run_dir,
                    "custom_animation_failed" if kind == "custom_animation" else "auto_failed",
                    state=state,
                    success=False,
                    detail={"error": str(exc), "name": label, "total": len(states)},
                )
                return
            with _auto_generation_jobs_lock:
                job = _auto_generation_jobs.get(key)
                if job is None or job.get("id") != job_id:
                    return
                job["results"].append({
                    "state": state,
                    "poseTemplateUsed": bool(result.get("poseTemplateUsed")),
                    "recovered": bool(result.get("recovered")),
                    "qualityRetry": bool(result.get("qualityRetry")),
                })
                job["completed"] = len(job["results"])
                _persist_auto_generation_job(run_dir, job)

        with _auto_generation_jobs_lock:
            job = _auto_generation_jobs.get(key)
            if job is None or job.get("id") != job_id:
                return
            kind = job.get("kind") or "auto"
            label = job.get("label")
        _add_notification(
            run_dir,
            "custom_animation_generated" if kind == "custom_animation" else "auto_completed",
            state=states[0] if states else None,
            detail={"name": label, "total": len(states)},
        )
        with _auto_generation_jobs_lock:
            job = _auto_generation_jobs.get(key)
            if job is None or job.get("id") != job_id:
                return
            job["status"] = "completed"
            job["completed"] = len(job.get("results", []))
            job["currentState"] = None
            job["currentIndex"] = None
            job["finishedAt"] = time.strftime("%Y-%m-%dT%H:%M:%S%z")
            _persist_auto_generation_job(run_dir, job)
    finally:
        with _auto_generation_jobs_lock:
            _auto_generation_workers.discard(key)


def start_auto_generation(run_dir: Path, payload: dict | None = None) -> dict:
    """Generate requested or missing states in request order."""
    payload = payload or {}
    if _base_image_path(run_dir) is None:
        raise ValueError("create a base character before starting automatic generation")
    require_skeleton = payload.get("requireSkeleton", True) is not False
    if require_skeleton and _active_skeleton_profile(run_dir) is None:
        raise ValueError("save a pose skeleton before starting automatic generation")

    request_path = run_dir / "sprite-request.json"
    request = json.loads(request_path.read_text(encoding="utf-8"))
    if require_skeleton:
        active_profile = _active_skeleton_profile(run_dir)
        profile_specs = active_profile[1].get("stateSpecs") if active_profile else None
        changed = False
        if isinstance(profile_specs, dict):
            for state, spec in profile_specs.items():
                if state not in request.get("states", {}):
                    request.setdefault("states", {})[state] = copy.deepcopy(spec)
                    changed = True
        if changed:
            _atomic_json(request_path, request)
    request_states = list((request.get("states") or {}).keys())
    requested = payload.get("states")
    if requested is not None:
        if not isinstance(requested, list):
            raise ValueError("states must be a list")
        requested_set = {str(state) for state in requested}
        unknown = sorted(requested_set.difference(request_states))
        if unknown:
            raise ValueError(f"unknown states: {', '.join(unknown)}")
        states = [state for state in request_states if state in requested_set]
    else:
        states = request_states
    only_missing = not bool(payload.get("regenerateExisting"))
    if only_missing:
        states = [
            state for state in states
            if not _state_has_generated_frames(run_dir, request, state)
        ]

    key = _auto_generation_key(run_dir)
    with _auto_generation_jobs_lock:
        existing = _auto_generation_jobs.get(key)
        if existing and existing.get("status") in ("queued", "running"):
            raise RuntimeError("automatic generation is already running for this character")
        job_id = uuid.uuid4().hex
        job = {
            "id": job_id,
            "status": "queued" if states else "completed",
            "total": len(states),
            "completed": 0,
            "currentState": None,
            "currentIndex": None,
            "states": states,
            "results": [],
            "skeletonProfileId": _skeleton_profile_summary(run_dir).get("profileId") if require_skeleton else None,
            "kind": str(payload.get("kind") or "auto"),
            "label": str(payload.get("label") or "")[:60] or None,
            "startedAt": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
            "regenerateExisting": bool(payload.get("regenerateExisting")),
        }
        if not states:
            job["finishedAt"] = job["startedAt"]
        _auto_generation_jobs[key] = job
        _persist_auto_generation_job(run_dir, job)
        if states:
            _auto_generation_workers.add(key)

    if states:
        threading.Thread(
            target=_run_auto_generation,
            args=(run_dir.resolve(), job_id, states),
            name=f"sprite-auto-{run_dir.name}",
            daemon=True,
        ).start()
    return copy.deepcopy(job)

CONTENT_TYPES = {
    ".html": "text/html; charset=utf-8",
    ".js": "text/javascript; charset=utf-8",
    ".css": "text/css; charset=utf-8",
    ".png": "image/png",
    ".json": "application/json; charset=utf-8",
}


class ExclusiveThreadingHTTPServer(ThreadingHTTPServer):
    """Refuse a second studio server on the same Windows port."""

    allow_reuse_address = False

    def server_bind(self) -> None:
        if hasattr(socket, "SO_EXCLUSIVEADDRUSE"):
            self.socket.setsockopt(socket.SOL_SOCKET, socket.SO_EXCLUSIVEADDRUSE, 1)
        super().server_bind()



# ── 픽셀 격자 자동 측정 ──────────────────────────────────────────────
# fit.pixel_perfect 계약이 없는 런(예: --pngs-dir 임포트)에서도 격자 오버레이를 켠다:
# 인접픽셀 색경계 위치가 한 간격의 배수에 몰려 있으면 그 간격이 블록 피치다.
# 축별 브루트포스(경계 질량 ≥80% 인 최대 간격). 측정 실패한 줄은 격자를 그리지 않는다
# (가짜 격자 금지). 결과는 (경로, mtime) 키로 캐시.
_PITCH_CACHE: dict = {}


def _axis_pitch(edge_mass, length):
    total = sum(edge_mass)
    if total <= 0 or length < 8:
        return None
    best = None
    for pitch in range(2, min(96, length // 3) + 1):
        phase = [0] * pitch
        for pos, mass in enumerate(edge_mass):
            if mass:
                phase[pos % pitch] += mass
        if max(phase) / total >= 0.8:
            best = pitch
    return best


def detect_pixel_pitch(path):
    """프레임 한 장의 블록 피치(셀px/논리px)를 측정한다. 실패 시 None."""
    if Image is None:
        return None
    try:
        stat = os.stat(path)
    except OSError:
        return None
    key = (str(path), stat.st_mtime_ns)
    if key in _PITCH_CACHE:
        return _PITCH_CACHE[key]
    pitch = None
    try:
        with Image.open(path) as im:
            im = im.convert("RGBA")
            px = im.load()
            w, h = im.size
            col = [0] * max(0, w - 1)
            row = [0] * max(0, h - 1)
            for y in range(h):
                for x in range(w - 1):
                    a, b = px[x, y], px[x + 1, y]
                    if abs(a[0]-b[0]) + abs(a[1]-b[1]) + abs(a[2]-b[2]) + abs(a[3]-b[3]) > 48:
                        col[x] += 1
            for x in range(w):
                for y in range(h - 1):
                    a, b = px[x, y], px[x, y + 1]
                    if abs(a[0]-b[0]) + abs(a[1]-b[1]) + abs(a[2]-b[2]) + abs(a[3]-b[3]) > 48:
                        row[y] += 1
        pw, ph = _axis_pitch(col, w), _axis_pitch(row, h)
        if pw and ph:
            if max(pw, ph) % min(pw, ph) == 0 or abs(pw - ph) <= 1:
                pitch = min(pw, ph)
        else:
            pitch = pw or ph
        if pitch is not None and pitch < 2:
            pitch = None
    except OSError:
        pitch = None
    _PITCH_CACHE[key] = pitch
    return pitch


_REF_DIRECTIONS = ("down45", "up45", "down", "side", "up", "left", "right", "front", "back")


def _state_refs(run_dir, state, request):
    """상태 하나의 생성 레퍼런스 체인(방향 앵커/basis row/레이아웃 가이드).

    directional-anchor 규약의 관례 유도 — run dir 에 실재하는 파일만 노출한다.
    """
    refs = []
    declared = list((request.get("directions") or {}).get("set") or [])
    direction = _state_direction(request, state) if declared else None
    if direction not in declared:
        direction = None
        for d in sorted(_REF_DIRECTIONS, key=len, reverse=True):
            if state == d or state.startswith(d + "_"):
                direction = d
                break
    if direction is not None:
        # Do not advertise a raw directional anchor as generation material.
        # Older runs may contain a different character in that file; the
        # studio now uses the uploaded base plus grayscale skeleton guides as
        # the only generation inputs, so showing the stale colour anchor here
        # would be misleading even though it is retained for history.
        base = state[len(direction) + 1:] if state.startswith(direction + "_") else None
        if base and direction != "down":
            basis_rel = raw_rel(request, f"down_{base}")
            basis = run_dir / basis_rel
            if basis.is_file():
                refs.append({"role": "basis", "name": basis.name, "url": _url("run", *basis_rel.split("/"))})
    guide = run_dir / "references" / "layout-guides" / f"{state}.png"
    if guide.is_file():
        refs.append({"role": "guide", "name": guide.name, "url": _url("run", "references", "layout-guides", f"{state}.png")})
    # imported runs (--pngs-dir): references/imported/<state>/<role>-<name>.png → 생성 재료 칩.
    # role 파싱 SSoT = curation.imported_ref_role. 미지 role 은 스킵한다 — import 가 fail-loud
    # 로 걸러 여기 도달하지 않지만, 손으로 놓인 파일도 조용히 guide 로 relabel 하지 않는다.
    imported_dir = run_dir / "references" / "imported" / state
    if imported_dir.is_dir():
        for ref in sorted(imported_dir.glob("*.png")):
            role = imported_ref_role(ref.name)
            if role is None:
                continue
            refs.append({"role": role, "name": ref.name,
                         "url": _url("run", "references", "imported", state, ref.name)})
    return refs


def _transient_generation_mismatch(run_dir: Path, error: BaseException) -> bool:
    """Return whether a manifest count mismatch is plausibly an in-flight extract.

    The in-process commit lock is authoritative for webview generations. The mtime/lock-file
    checks cover an extractor started by another process, whose Python lock is necessarily a
    different object. We only retry the narrow row-count mismatch and retain fail-loud behavior
    for every other manifest corruption class.
    """
    message = str(error)
    if not re.search(r"row '.+' has \d+ frame\(s\), request expects \d+", message):
        return False
    if _generation_run_busy(run_dir) or (run_dir / ".sprite-gen.lock").is_file():
        return True
    request_path = run_dir / "sprite-request.json"
    manifest_path = run_dir / "frames" / "frames-manifest.json"
    try:
        request_mtime = request_path.stat().st_mtime
        manifest_mtime = manifest_path.stat().st_mtime
    except OSError:
        return False
    return request_mtime > manifest_mtime and (time.time() - request_mtime) < 120


def build_run_state(run_dir: Path) -> dict:
    """Assemble the run snapshot the SPA needs. Read under the run dir's shared read_guard
    so a concurrent `--force` re-import (which holds the exclusive publish_guard for its
    swap) can never expose a half-published state to `/api/run` — the reader sees either
    the complete prior run or the complete new run (reader isolation).

    Studio take publication updates ``sprite-request.json`` before the extractor swaps in
    the matching frames manifest. The in-process generation commit lock covers that entire
    request+extract transaction; readers must join it as well, otherwise a refresh in that
    narrow window sees the new requested candidate count with the old manifest and reports
    a false corruption error.
    """
    deadline = time.monotonic() + _RUN_SNAPSHOT_RETRY_SECONDS
    while True:
        try:
            with _generation_commit_lock, read_guard(run_dir):
                return _build_run_state_impl(run_dir)
        except SystemExit as exc:
            if not _transient_generation_mismatch(run_dir, exc) or time.monotonic() >= deadline:
                raise
        time.sleep(_RUN_SNAPSHOT_RETRY_INTERVAL)


def _build_run_state_impl(run_dir: Path) -> dict:
    """Assemble the run snapshot the SPA needs, from the canonical SSoT files."""
    request = json.loads((run_dir / "sprite-request.json").read_text(encoding="utf-8"))
    # No generation yet (no manifest AND no physical frames) → serve the request/state scaffold
    # (legitimate). A present-but-corrupt/inconsistent manifest, or an orphan (frames without a
    # manifest), fails loud (load_consistent_frames_manifest raises) and surfaces as HTTP 500 in
    # do_GET — never a silent empty-rows / stale-frame fallback (No Silent Fallback / Consistency).
    frames_manifest = load_consistent_frames_manifest(run_dir, allow_pending_states=True) or {"rows": []}
    rows_by_state = {row["state"]: row for row in frames_manifest.get("rows", [])}

    cell = request["cell"]
    cell_state = {
        "width": int(cell.get("width", cell.get("size", 0))),
        "height": int(cell.get("height", cell.get("size", 0))),
        # 안전영역/여백 알림 계산용 (여백 침범 = 정보성, 리롤 대상 아님)
        "safeMarginX": int(cell.get("safe_margin_x", cell.get("safe_margin", 0))),
        "safeMarginY": int(cell.get("safe_margin_y", cell.get("safe_margin", 0))),
    }

    # 픽셀퍼펙트 격자: 논리 픽셀 1칸이 셀 픽셀 몇 칸인가. extract 의 pp_scale 과 같은 식이어야
    # 큐레이터 오버레이가 "실제로 스냅된 격자"를 그린다 (셀 래스터가 아니라).
    fit = request.get("fit") or {}
    pixel_perfect = None
    if fit.get("pixel_perfect"):
        logical_height = int(fit.get("logical_height", cell_state["height"]))
        scale = max(1, cell_state["height"] // max(1, logical_height))
        pixel_perfect = {"logicalHeight": logical_height, "scale": scale, "source": "request", "label": f"{logical_height}px"}

    states = []
    for state, entry in request["states"].items():
        row = rows_by_state.get(state, {})
        files = row.get("files", [])
        labels = row.get("labels", [])
        frame_count = state_frame_total(request, state)
        sequence_frames = int(entry.get("frames", frame_count))
        state_raw_rel = raw_rel(request, state)
        raw_present = (run_dir / state_raw_rel).is_file()
        state_frames_rel = frames_dir_rel(request, state)
        frames = []
        for index in range(frame_count):
            # 파일 위치 SSoT = manifest row files (병합 후보 등 비패턴 경로 포함).
            # row 가 없거나(index 초과 포함) 미생성이면 리졸버의 예약 위치로 표시.
            row_files = row.get("files") or []
            if index < len(row_files):
                rel = row_files[index]
            else:
                rel = f"{state_frames_rel}/frame-{index}.png"
            present = (run_dir / rel).is_file()
            frame = {"index": index, "url": _url(*rel.split("/")), "present": present}
            # pp 해제 토글 표시본: 원본 화질(orig/ 고해상본) 우선, 없으면 셀 크기 .plain.png.
            # 둘 중 하나라도 있으면 큐레이터가 전/후 토글을 켠다.
            head, _, tail = rel.rpartition("/")
            orig_rel = f"{head}/orig/{tail}"
            plain_rel = rel[: -len(".png")] + ".plain.png"
            if (run_dir / orig_rel).is_file():
                frame["plainUrl"] = _url(*orig_rel.split("/"))
            elif (run_dir / plain_rel).is_file():
                frame["plainUrl"] = _url(*plain_rel.split("/"))
            if index < len(labels):
                frame["label"] = labels[index]
            if present and Image is not None:
                # 실제 스프라이트 픽셀 크기(투명 패딩 제외 알파 bbox) — 사이즈 통일 검수용
                try:
                    with Image.open(run_dir / rel) as im:
                        frame["size"] = [im.width, im.height]
                        alpha = im.getchannel("A") if "A" in im.getbands() else None
                        bbox = alpha.getbbox() if alpha is not None else im.getbbox()
                        if bbox:
                            frame["contentSize"] = [bbox[2] - bbox[0], bbox[3] - bbox[1]]
                            # 최종 픽셀 콘텐츠 bbox(셀 좌표) — 원본 뷰의 "최종 대응 격자"
                            # (칸 수 = 최종 픽셀 수)가 이 상자를 균등 분할해 그린다
                            frame["contentBox"] = list(bbox)
                except OSError:
                    pass
            frames.append(frame)
        state_scale = None
        if pixel_perfect is not None:
            state_scale = pixel_perfect["scale"]
        else:
            for fr in frames:
                if fr.get("present"):
                    # measure from the real (decoded) file path, not fr["url"] — the url is
                    # percent-encoded for HTTP, so a special-char state name would point the
                    # measurement at a nonexistent encoded dir → pixelScale silently null.
                    row_files_m = row.get("files") or []
                    rel_m = row_files_m[fr["index"]] if fr["index"] < len(row_files_m) else f"{state_frames_rel}/frame-{fr['index']}.png"
                    state_scale = detect_pixel_pitch(run_dir / rel_m)
                    break
        states.append(
            {
                "name": state,
                "rawPresent": raw_present,
                "pixelScale": state_scale,
                "refs": _state_refs(run_dir, state, request),
                "fps": int(entry.get("fps", 6)),
                "loop": bool(entry.get("loop", True)),
                "action": entry.get("action", ""),
                "customAnimation": entry.get("custom_animation"),
                # The sequence remains four animation phases even when generation
                # takes append more candidates to the pool.
                "requestFrames": sequence_frames,
                "candidateFrames": frame_count,
                "extractOk": bool(row.get("ok", bool(files))),
                "frames": frames,
            }
        )

    # 방향 계약 런: 뷰가 방향 그룹(앵커 우선)으로 묶고 미러 방향(생성 생략)을 표시한다.
    directions_cfg = request.get("directions")
    direction_groups = None
    if directions_cfg and directions_cfg.get("set"):
        suffix = directions_cfg.get("anchor_suffix", "idle")
        direction_groups = []
        for direction in directions_cfg["set"]:
            anchor = f"{direction}_{suffix}"
            # Direction names may share prefixes (down / down_right / down_left).
            # Resolve through the declared direction set instead of startswith so
            # each generated state appears in exactly one of the eight sections.
            members = [s for s in request["states"] if _state_direction(request, s) == direction]
            # 앵커를 그룹 맨 앞으로 (요청 순서 보존, 앵커만 승격)
            if anchor in members:
                members = [anchor, *[m for m in members if m != anchor]]
            direction_groups.append({
                "direction": direction,
                "anchor": anchor if anchor in request["states"] else None,
                "states": members,
            })
        for target, source in (directions_cfg.get("mirror") or {}).items():
            direction_groups.append({"direction": target, "mirrorOf": source, "states": []})

    # 방향 앵커 파일 (references/anchors/*.png) — 파일트리 표시용
    anchors_dir = run_dir / "references" / "anchors"
    anchor_files = []
    if anchors_dir.is_dir():
        for path in sorted(anchors_dir.glob("*.png")):
            anchor_files.append({"name": path.name, "url": _url("run", "references", "anchors", path.name)})

    curation, curation_report = load_curation_report(run_dir)
    curation = curation or empty_curation()
    # 원본 베이스(아이덴티티 truth)가 있으면 큐레이터 최상단에 참조 줄로 노출
    base_path = _base_image_path(run_dir)
    base_url = _url("run", base_path.name) if base_path else None
    base_reference_path = _base_reference_path(run_dir)
    base_reference_url = _url("run", base_reference_path.name) if base_reference_path else None
    # 뷰 계약 자가 보고 (run-contract.md §3): base 참조 줄 / 생성 재료 칩 / 픽셀 격자
    # 충족 여부. 셋 다 없으면 "소스 없는 뷰" — 세션마다 경험이 갈라지는 신호.
    has_base = base_url is not None
    refs_states = sum(1 for st in states if st.get("refs"))
    has_grid = pixel_perfect is not None or any(st.get("pixelScale") for st in states)
    contract = {
        "base": has_base,
        "refs": refs_states > 0,
        "refsStates": refs_states,
        "grid": has_grid,
        "sourceless": not (has_base or refs_states > 0 or has_grid),
    }
    return {
        "characterId": request["character"]["id"],
        "runDir": str(run_dir),
        "baseUrl": base_url,
        "baseReferenceUrl": base_reference_url,
        "cell": cell_state,
        "pixelPerfect": pixel_perfect if pixel_perfect is not None else ({"source": "auto", "label": "auto", "scale": None} if any(st.get("pixelScale") for st in states) else None),
        "schemaVersion": SCHEMA_VERSION,
        "runRevision": run_revision(run_dir),
        "directionGroups": direction_groups,
        "anchorFiles": anchor_files,
        "states": states,
        "curation": curation,
        # 세대 불일치로 이번 로드에서 무효화(드롭)된 행 + 원문 백업 파일명 — 뷰가
        # 배너로 알린다 (stderr 만으로는 사용자가 못 본다; 조용한 소실 금지).
        "curationDropped": curation_report["dropped"],
        "curationBackup": curation_report["backup"],
        "iso": request.get("iso"),
        "lang": CurationHandler.lang,
        "hasAtlas": (run_dir / "sprite-sheet-alpha.png").is_file(),
        "fitPixelPerfect": bool((request.get("fit") or {}).get("pixel_perfect")),
        "skeletonProfile": _skeleton_profile_summary(run_dir),
        "skeletonAssignment": copy.deepcopy(request.get("studio_skeleton") or {}),
        "contract": contract,
    }


def write_curation_atomic(run_dir: Path, payload: dict) -> None:
    """Atomically replace curation.json (temp file in the same dir + os.replace). Stamps the
    sidecar with the current run generation (`run_revision`) AND per-state `revision`
    segment fingerprints (stamp_curation), so a later regeneration invalidates only the
    rows it actually touched. Before replacing, any state entry in the existing file that
    this write would lose (missing from the payload, or stamped for an incompatible
    generation) triggers a `curation.stale-<hash>.json` backup of the old file — an
    autosave can never permanently destroy selections without an observable copy.
    `runRevision` is a transport-only echo field and is not stored."""
    if payload.get("kind") != "sprite-gen-curation":
        raise ValueError("payload is not a sprite-gen-curation document")
    payload = stamp_curation(run_dir, payload)
    target = run_dir / CURATION_FILENAME
    if target.is_file():
        old_text = target.read_text(encoding="utf-8")
        try:
            old = json.loads(old_text)
        except json.JSONDecodeError:
            old = None
        if isinstance(old, dict):
            new_states = payload.get("states") or {}
            same_generation = old.get("run_revision") == payload.get("run_revision")
            for name, old_entry in (old.get("states") or {}).items():
                new_entry = new_states.get(name)
                if not isinstance(old_entry, dict):
                    continue
                if not isinstance(new_entry, dict):
                    lost = True
                else:
                    old_rev, new_rev = old_entry.get("revision"), new_entry.get("revision")
                    if isinstance(old_rev, list) and isinstance(new_rev, list):
                        lost = old_rev != new_rev[:len(old_rev)]
                    else:
                        # 레거시 스탬프 없는 항목: 같은 런 세대의 정상 편집이면 호환
                        lost = not same_generation
                if lost:
                    backup_stale_curation(run_dir, old_text)
                    break
    text = json.dumps(payload, ensure_ascii=False, indent=2) + "\n"
    fd, tmp_name = tempfile.mkstemp(dir=str(run_dir), prefix=".curation-", suffix=".tmp")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            handle.write(text)
        os.replace(tmp_name, target)
    except BaseException:
        if os.path.exists(tmp_name):
            os.unlink(tmp_name)
        raise


_heal_lock = threading.Lock()


def maybe_heal(run_dir: Path) -> dict | None:
    """실시간 계약 (수홍 확정 2026-07-14): 뷰에 '재추출' 개념이 없다.

    frames/ 는 (raw + request + 현재 엔진 + 큐레이션)의 파생 캐시다 — 요청이
    들어올 때마다 행별 engine_revision 을 현재 엔진과 비교해, 다르면 raw 에서
    조용히 다시 굽는다 (heal_run). 신선하면 해시 비교 몇 ms 로 끝난다.
    ThreadingHTTPServer 라 락으로 단일 비행을 보장한다 (동시 재추출 금지).
    실패는 뷰를 죽이지 않고 노트로 관측 가능하게 남긴다 — 이전 세대는
    스테이징 통짜 스왑 덕에 바이트 그대로다.
    """
    with _heal_lock:
        try:
            report = heal_run(run_dir)
        except (Exception, SystemExit) as exc:
            return {"healed": [], "kept_stale": [], "failed": [],
                    "notes": [f"heal skipped: {exc}"]}
    if report["healed"] or report["kept_stale"] or report.get("failed") or report["notes"]:
        return report
    return None


def _zip_paths(base: Path, paths: list[Path]) -> bytes:
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, "w", zipfile.ZIP_DEFLATED) as archive:
        for path in paths:
            archive.write(path, path.relative_to(base).as_posix())
    return buffer.getvalue()


def _bake_state_sequence(run_dir: Path, state: str, request: dict,
                         manifest: dict, curation: dict | None) -> tuple[list[int], list[Image.Image]]:
    if state not in (request.get("states") or {}):
        raise ValueError(f"unknown state: {state}")
    cell = request["cell"]
    cell_width = int(cell.get("width", cell.get("size", 0)))
    cell_height = int(cell.get("height", cell.get("size", 0)))
    if cell_width <= 0 or cell_height <= 0:
        raise ValueError("cell width and height must be positive")
    matching_rows = [item for item in manifest.get("rows", []) if item.get("state") == state]
    if len(matching_rows) != 1:
        raise ValueError(f"frames manifest has no unique row for state: {state}")
    row = matching_rows[0]
    files = row.get("files") or []
    expected_total = state_frame_total(request, state)
    if len(files) != expected_total:
        raise ValueError(
            f"section {state} is still updating: {len(files)} frames published, "
            f"{expected_total} expected")
    expected_prefix = frames_dir_rel(request, state) + "/"
    physical = sorted(
        f"{expected_prefix}{path.name}"
        for path in (run_dir / frames_dir_rel(request, state)).glob("frame-*.png")
        if not path.name.endswith(".plain.png")
    )
    if sorted(files) != physical:
        raise ValueError(f"section {state} frame files are still updating")

    ordered, transforms = state_plan(curation, state, expected_total)
    if not ordered:
        raise ValueError(f"section {state} has no selected frames")
    variant = frame_variant(curation, state)
    pixel_ops = state_pixel_ops(curation, state)
    snap_scale = pixel_snap_scale(request) if variant == "pixel" else None
    cell_size = (cell_width, cell_height)
    baked_frames: list[Image.Image] = []
    for frame_index in ordered:
        source_index = source_frame_index(curation, state, frame_index, expected_total)
        source_path = run_dir / row_frame_rel(row, source_index, variant)
        if not source_path.is_file():
            raise ValueError(f"selected frame is missing: {source_path}")
        with Image.open(source_path) as opened:
            frame = apply_pixel_edits(opened.convert("RGBA"), pixel_ops.get(frame_index))
        baked_frames.append(apply_transform(
            frame, transforms.get(frame_index), cell_size, snap_scale=snap_scale))
    return ordered, baked_frames


def _horizontal_strip(frames: list[Image.Image]) -> Image.Image:
    if not frames:
        raise ValueError("cannot build an empty sprite strip")
    width, height = frames[0].size
    strip = Image.new("RGBA", (width * len(frames), height), (0, 0, 0, 0))
    for column, frame in enumerate(frames):
        if frame.size != (width, height):
            raise ValueError("pose template frames do not share one cell size")
        strip.alpha_composite(frame, (column * width, 0))
    return strip


def _pose_guide(frame: Image.Image) -> Image.Image:
    """Remove color identity while retaining limb boundaries and exact silhouette."""
    rgba = frame.convert("RGBA")
    gray = ImageOps.grayscale(rgba.convert("RGB"))
    posterized = gray.point(lambda value: 72 if value < 85 else (146 if value < 170 else 224))
    guide = ImageOps.colorize(posterized, black="#43515a", white="#edf2f4").convert("RGBA")
    guide.putalpha(rgba.getchannel("A"))
    return guide


def build_state_png(run_dir: Path, state: str) -> tuple[bytes, str]:
    """Bake one state's selected sequence into a transparent horizontal PNG strip."""
    if Image is None:
        raise RuntimeError("Pillow is required for PNG export")
    with _generation_commit_lock, read_guard(run_dir):
        request = json.loads((run_dir / "sprite-request.json").read_text(encoding="utf-8"))
        manifest = load_frames_manifest(run_dir / "frames" / "frames-manifest.json")
        curation = load_curation(run_dir)
        _ordered, frames = _bake_state_sequence(run_dir, state, request, manifest, curation)
        strip = _horizontal_strip(frames)
        output = io.BytesIO()
        strip.save(output, format="PNG", compress_level=9)
        character = str((request.get("character") or {}).get("id") or run_dir.name)
        safe_character = re.sub(r"[^A-Za-z0-9._-]+", "_", character).strip("._") or "sprite"
        safe_state = re.sub(r"[^A-Za-z0-9._-]+", "_", state).strip("._") or "state"
        return output.getvalue(), f"{safe_character}-{safe_state}.png"


def save_skeleton_profile(run_dir: Path, name: str | None = None) -> dict:
    """Publish skeleton-enabled curated rows as a studio-wide immutable pose profile."""
    if Image is None or ImageOps is None:
        raise RuntimeError("Pillow is required for skeleton profile export")
    with _generation_commit_lock, read_guard(run_dir):
        request = json.loads((run_dir / "sprite-request.json").read_text(encoding="utf-8"))
        manifest = load_frames_manifest(run_dir / "frames" / "frames-manifest.json")
        curation = load_curation(run_dir)
        curation_states = (curation.get("states") or {}) if isinstance(curation, dict) else {}
        required_states = [
            state for state in request.get("states", {})
            if (curation_states.get(state) or {}).get("skeleton_included", True) is not False
        ]
        baked: dict[str, list[Image.Image]] = {}
        invalid: list[str] = []
        for state in required_states:
            expected = int(request["states"][state].get("frames", 0))
            try:
                _ordered, frames = _bake_state_sequence(
                    run_dir, state, request, manifest, curation)
                if len(frames) != expected:
                    invalid.append(f"{state} ({len(frames)}/{expected} selected)")
                else:
                    baked[state] = frames
            except (OSError, ValueError, SystemExit) as exc:
                invalid.append(f"{state} ({exc})")
        if invalid:
            raise ValueError(
                "스켈레톤 저장 전 포함 대상으로 체크한 모든 섹션에서 요청 프레임 수만큼 선택하세요: "
                + ", ".join(invalid))
        source_character = str((request.get("character") or {}).get("id") or run_dir.name)
        cell = request["cell"]
        state_specs = {state: copy.deepcopy(request["states"][state]) for state in required_states}
        for spec in state_specs.values():
            spec.pop("takes", None)
        assignment = request.get("studio_skeleton") if isinstance(request.get("studio_skeleton"), dict) else {}
        previous_profile_id = str(assignment.get("profileId") or "")
        requested_name = re.sub(r"\s+", " ", str(name or assignment.get("name") or "")).strip()
        profile_name = requested_name or _infer_skeleton_name({
            "profileId": "", "states": {state: {} for state in required_states},
            "stateSpecs": state_specs,
        })
        prompts = {
            str(spec.get("action") or "").strip()
            for spec in state_specs.values() if isinstance(spec, dict)
        }
        prompts.discard("")
        action_prompt = str(assignment.get("prompt") or "").strip()
        if not action_prompt and len(prompts) == 1:
            action_prompt = next(iter(prompts))
        frame_counts = {
            int(spec.get("frames", 0))
            for spec in state_specs.values() if isinstance(spec, dict)
        }

    profile_id = f"pose-{time.strftime('%Y%m%d-%H%M%S')}-{uuid.uuid4().hex[:6]}"
    root = _skeleton_root(run_dir)
    profile_dir = root / "profiles" / profile_id
    profile_dir.mkdir(parents=True, exist_ok=False)
    states_meta: dict[str, dict] = {}
    try:
        for state, frames in baked.items():
            safe_state = re.sub(r"[^A-Za-z0-9._-]+", "_", state).strip("._") or "state"
            guides = [_pose_guide(frame) for frame in frames]
            strip_rel = f"states/{safe_state}.png"
            strip_path = profile_dir / strip_rel
            strip_path.parent.mkdir(parents=True, exist_ok=True)
            _horizontal_strip(guides).save(strip_path, format="PNG", compress_level=9)
            phase_rels = []
            for phase, guide in enumerate(guides):
                phase_rel = f"phases/{safe_state}/frame-{phase + 1}.png"
                phase_path = profile_dir / phase_rel
                phase_path.parent.mkdir(parents=True, exist_ok=True)
                guide.save(phase_path, format="PNG", compress_level=9)
                phase_rels.append(phase_rel)
            states_meta[state] = {"strip": strip_rel, "phases": phase_rels, "frames": len(frames)}

        metadata = {
            "version": 1,
            "profileId": profile_id,
            "savedAt": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
            "name": profile_name,
            "sourceCharacterId": source_character,
            "cell": cell,
            "actionPrompt": action_prompt or None,
            "frameCount": next(iter(frame_counts)) if len(frame_counts) == 1 else None,
            "directions": list(_DIRECTION_VIEW),
            "states": states_meta,
            "stateSpecs": state_specs,
        }
        _atomic_json(profile_dir / "profile.json", metadata)
        root.mkdir(parents=True, exist_ok=True)
        _atomic_json(root / "active.json", {
            "version": 1, "profileId": profile_id, "savedAt": metadata["savedAt"]})
        with _generation_commit_lock:
            latest_request = json.loads((run_dir / "sprite-request.json").read_text(encoding="utf-8"))
            latest_request["studio_skeleton"] = {
                "mode": "existing",
                "profileId": profile_id,
                "name": profile_name,
            }
            _atomic_json(run_dir / "sprite-request.json", latest_request)
    except BaseException:
        shutil.rmtree(profile_dir, ignore_errors=True)
        raise
    replaced_profile_id = None
    replacement_cleanup_warning = None
    if previous_profile_id and previous_profile_id != profile_id:
        previous = _skeleton_profile_by_id(run_dir, previous_profile_id)
        same_logical_profile = (
            previous is not None
            and _skeleton_contract(previous[1]) == _skeleton_contract(metadata)
            and _infer_skeleton_name(previous[1]) == profile_name
        )
        if same_logical_profile:
            try:
                delete_skeleton_profile(run_dir, previous_profile_id)
                replaced_profile_id = previous_profile_id
            except (OSError, ValueError) as exc:
                replacement_cleanup_warning = str(exc)
    return {
        "ok": True,
        "profileId": profile_id,
        "sourceCharacterId": source_character,
        "stateCount": len(states_meta),
        "savedAt": metadata["savedAt"],
        "name": profile_name,
        "replacedProfileId": replaced_profile_id,
        "warning": replacement_cleanup_warning,
    }


def build_download(run_dir: Path, kind: str) -> tuple[bytes, str] | dict:
    """내보내기 버튼 3종 = '지금 보이는 라이브 상태의 다운로드' (수홍 확정 2026-07-14).

    게임/어디에 적용한다는 의미가 아니다 — 현재 (프레임 캐시 + 큐레이션)를
    합성 스크립트로 계산해 파일로 손에 쥐여준다. 계산 산출물은 런 폴더에도
    남는다 (런 폴더 = 작업장, 다운로드 = 핸드오프). 실패 시 dict(에러)."""
    request = json.loads((run_dir / "sprite-request.json").read_text(encoding="utf-8"))
    character = str(request.get("character", {}).get("id") or run_dir.name)
    if kind == "atlas":
        result = run_compose(run_dir)
        if not result["ok"]:
            return result
        files = [run_dir / "sprite-sheet-alpha.png", run_dir / "manifest.json"]
        files = [f for f in files if f.is_file()]
        return _zip_paths(run_dir, files), f"{character}-atlas.zip"
    if kind == "pngs":
        result = run_export(run_dir)
        if not result["ok"]:
            return result
        out = run_dir / "curated"
        exported = (result.get("export") or {}).get("files")
        if not isinstance(exported, list):
            return {"ok": False, "error": "PNG exporter did not report its written files"}
        files: list[Path] = []
        for value in exported:
            candidate = Path(str(value)).resolve()
            try:
                candidate.relative_to(out.resolve())
            except ValueError:
                return {"ok": False, "error": f"PNG exporter reported a path outside curated/: {candidate}"}
            if not candidate.is_file():
                return {"ok": False, "error": f"exported PNG is missing: {candidate}"}
            files.append(candidate)
        return _zip_paths(run_dir, files), f"{character}-pngs.zip"
    if kind == "gifs":
        result = run_export_gif(run_dir)
        if not result["ok"]:
            return result
        out = run_dir / "exports"
        return _zip_paths(run_dir, sorted(out.glob("*.gif"))), f"{character}-gifs.zip"
    return {"ok": False, "error": f"unknown download kind: {kind}"}


def _run_script(name: str, run_dir: Path) -> dict:
    proc = subprocess.run(
        [sys.executable, str(SCRIPTS_DIR / name), "--run-dir", str(run_dir)],
        capture_output=True,
        text=True,
    )
    return {
        "ok": proc.returncode == 0,
        "returncode": proc.returncode,
        "stdout": proc.stdout,
        "stderr": proc.stderr,
    }


def run_compose(run_dir: Path) -> dict:
    """Re-run the atlas compose step so curation bakes into atlas/manifest."""
    return _run_script("compose_sprite_atlas.py", run_dir)


def run_export(run_dir: Path) -> dict:
    """Export only the curated sequence back to named PNGs under <run-dir>/curated/."""
    proc = subprocess.run(
        [sys.executable, str(SCRIPTS_DIR / "export_curated_pngs.py"),
         "--run-dir", str(run_dir), "--selected-only"],
        capture_output=True,
        text=True,
    )
    result = {
        "ok": proc.returncode == 0,
        "returncode": proc.returncode,
        "stdout": proc.stdout,
        "stderr": proc.stderr,
    }
    if result["ok"] and result["stdout"]:
        try:
            result["export"] = json.loads(result["stdout"])
        except json.JSONDecodeError:
            pass
    return result


def run_export_gif(run_dir: Path) -> dict:
    """Export one clean transparent GIF per state under <run-dir>/exports/.

    Reuses compose_sprite_gif.py --run-dir, which applies the same curation
    selection/order/transform as the atlas compose (curation.py SSoT)."""
    result = _run_script("compose_sprite_gif.py", run_dir)
    if result["ok"] and result["stdout"]:
        try:
            result["gif"] = json.loads(result["stdout"])
        except json.JSONDecodeError:
            pass
    return result


class CurationHandler(BaseHTTPRequestHandler):
    run_dir: Path = Path(".")
    initial_run_dir: Path = Path(".")
    studio_root: Path = Path(".")
    lang: str = "en"

    def log_message(self, *_args):  # quieter console
        pass

    # --- helpers -------------------------------------------------------------

    def _send_json(self, payload: dict, status: int = 200) -> None:
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _send_file(self, path: Path) -> None:
        if not path.is_file():
            self._send_json({"error": "not found", "path": str(path)}, 404)
            return
        data = path.read_bytes()
        self._send_file_data(path, data)

    def _send_file_data(self, path: Path, data: bytes) -> None:
        self.send_response(200)
        self.send_header("Content-Type", CONTENT_TYPES.get(path.suffix, "application/octet-stream"))
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(data)

    def _send_run_file(self, path: Path) -> None:
        # Snapshot bytes while holding the run read lock, then release the lock
        # before writing to a potentially slow or disconnected browser socket.
        # Holding read_guard during send can starve /api/run's writer/heal path
        # when a refreshed page aborts dozens of image requests at once.
        with read_guard(self.run_dir):
            if not path.is_file():
                data = None
            else:
                data = path.read_bytes()
        if data is None:
            self._send_json({"error": "not found", "path": str(path)}, 404)
            return
        self._send_file_data(path, data)

    @staticmethod
    def _safe_path(base: Path, rel: str) -> Path | None:
        """Resolve `rel` under `base`, refusing anything that escapes it."""
        base = base.resolve()
        candidate = (base / unquote(rel)).resolve()
        try:
            candidate.relative_to(base)
        except ValueError:
            return None
        return candidate

    def _read_body(self) -> dict:
        length = int(self.headers.get("Content-Length", 0))
        raw = self.rfile.read(length) if length else b"{}"
        return json.loads(raw.decode("utf-8"))

    def _download_run_dir(self, parsed) -> Path:
        character_id = str((parse_qs(parsed.query).get("characterId") or [""])[0]).strip()
        if not character_id:
            return self.run_dir
        return select_studio_character(
            self.studio_root, self.initial_run_dir, character_id)

    # --- routes --------------------------------------------------------------

    def do_GET(self) -> None:
        parsed = urlparse(self.path)
        path = parsed.path
        if path in ("/", "/index.html"):
            self._send_file(CURATOR_DIR / "index.html")
            return
        if path == "/api/run":
            try:
                recovered = recover_orphan_generations(self.run_dir)
                snapshot = build_run_state(self.run_dir)
                snapshot["studioCharacters"] = studio_character_list(
                    self.studio_root, self.initial_run_dir, self.run_dir)
                snapshot["activeCharacterId"] = next(
                    (item["id"] for item in snapshot["studioCharacters"] if item["active"]),
                    self.run_dir.name,
                )
                snapshot["skeletonProfiles"] = list_skeleton_profiles(self.run_dir)
                if recovered:
                    snapshot["recoveredGenerations"] = recovered
                self._send_json(snapshot)
            except (Exception, SystemExit) as exc:  # incl. load_frames_manifest fail-loud; no silent fallback
                self._send_json({"error": str(exc)}, 500)
            return
        if path == "/api/characters/base":
            character_id = str(
                (parse_qs(parsed.query).get("characterId") or [""])[0]
            ).strip()
            try:
                character_run_dir = select_studio_character(
                    self.studio_root, self.initial_run_dir, character_id)
                base_path = _base_image_path(character_run_dir)
                if base_path is None:
                    raise ValueError("base image not found")
                with read_guard(character_run_dir):
                    data = base_path.read_bytes()
                self._send_file_data(base_path, data)
            except (Exception, SystemExit) as exc:
                self._send_json({"error": str(exc)}, 404)
            return
        if path == "/api/skeletons":
            self._send_json({"profiles": list_skeleton_profiles(self.run_dir)})
            return
        if path == "/api/auto-generation":
            self._send_json(auto_generation_status(self.run_dir))
            return
        if path == "/api/auto-generations":
            characters = studio_character_list(
                self.studio_root, self.initial_run_dir, self.run_dir)
            self._send_json({
                "characters": {
                    character["id"]: character.get("autoGeneration") or {
                        "status": "idle", "total": 0, "completed": 0
                    }
                    for character in characters
                }
            })
            return
        if path == "/api/notifications":
            self._send_json(list_notifications(self.run_dir))
            return
        if path == "/download/state-png":
            state = (parse_qs(parsed.query).get("state") or [""])[0]
            try:
                download_run_dir = self._download_run_dir(parsed)
                recover_orphan_generations(download_run_dir)
                maybe_heal(download_run_dir)
                data, filename = build_state_png(download_run_dir, state)
                request = json.loads((download_run_dir / "sprite-request.json").read_text(encoding="utf-8"))
                character_id = str((request.get("character") or {}).get("id") or download_run_dir.name)
            except (Exception, SystemExit) as exc:
                self._send_json({"error": str(exc)}, 500)
                return
            self.send_response(200)
            self.send_header("Content-Type", "image/png")
            self.send_header("Content-Disposition", f'attachment; filename="{filename}"')
            self.send_header("X-Filename", filename)
            self.send_header("X-Character-Id", character_id)
            self.send_header("Content-Length", str(len(data)))
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(data)
            return
        if path.startswith("/download/"):
            kind = path[len("/download/"):]
            try:
                download_run_dir = self._download_run_dir(parsed)
                recover_orphan_generations(download_run_dir)
                maybe_heal(download_run_dir)
                built = build_download(download_run_dir, kind)
                request = json.loads((download_run_dir / "sprite-request.json").read_text(encoding="utf-8"))
                character_id = str((request.get("character") or {}).get("id") or download_run_dir.name)
            except (Exception, SystemExit) as exc:
                self._send_json({"error": str(exc)}, 500)
                return
            if isinstance(built, dict):
                self._send_json(built, 500)
                return
            data, filename = built
            self.send_response(200)
            self.send_header("Content-Type", "application/zip")
            self.send_header("Content-Disposition", f'attachment; filename="{filename}"')
            self.send_header("X-Filename", filename)
            self.send_header("X-Character-Id", character_id)
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)
            return
        if path == "/api/progress":
            # 가벼운 생성 진행 스냅샷 (트리 실시간 갱신용 폴링 대상): 상태별 raw 유무 +
            # 추출 프레임 수 + 런 세대. /api/run 전체 스냅샷(프레임 이미지 오픈)보다 훨씬 싸다.
            try:
                # 페이지가 열린 채 엔진이 바뀌어도 다음 폴에서 자가치유된다 —
                # 프레임 세대가 바뀌면 runRevision 변화로 클라이언트가 리로드한다.
                with read_guard(self.run_dir):
                    request = json.loads((self.run_dir / "sprite-request.json").read_text(encoding="utf-8"))
                    progress = []
                    for state in request["states"]:
                        state_frames = frames_dir_rel(request, state)
                        state_raw = raw_rel(request, state)
                        state_dir = self.run_dir / state_frames
                        count = 0
                        if state_dir.is_dir():
                            count = sum(1 for f in state_dir.glob("frame-*.png") if not f.name.endswith(".plain.png"))
                        progress.append({
                            "name": state,
                            "raw": (self.run_dir / state_raw).is_file(),
                            "frames": count,
                            # 트리 썸네일용 실제 경로 URL (클라이언트 패턴 조립 금지)
                            "rawUrl": _url("run", *state_raw.split("/")),
                            "frame0Url": _url(*f"{state_frames}/frame-0.png".split("/")),
                            "relRaw": state_raw,
                            "relFrames": state_frames,
                        })
                    payload = {"states": progress, "runRevision": run_revision(self.run_dir)}
                self._send_json(payload)
            except (Exception, SystemExit) as exc:
                self._send_json({"error": str(exc)}, 500)
            return
        if path.startswith("/curator/"):
            resolved = self._safe_path(CURATOR_DIR, path[len("/curator/"):])
            if resolved is None:
                self._send_json({"error": "path escapes curator dir"}, 403)
                return
            self._send_file(resolved)
            return
        if path.startswith("/frames/") or path.startswith("/run/"):
            rel = path[len("/run/"):] if path.startswith("/run/") else path[1:]
            resolved = self._safe_path(self.run_dir, rel)
            if resolved is None:
                self._send_json({"error": "path escapes run dir"}, 403)
                return
            self._send_run_file(resolved)
            return
        # bare static asset (curator.js / curator.css served from /)
        asset = self._safe_path(CURATOR_DIR, path.lstrip("/"))
        if asset is None:
            self._send_json({"error": "path escapes curator dir"}, 403)
            return
        if asset.is_file():
            self._send_file(asset)
            return
        self._send_json({"error": "not found", "path": path}, 404)

    def do_POST(self) -> None:
        path = urlparse(self.path).path
        try:
            if path == "/api/characters/create":
                payload = self._read_body()
                created = create_studio_character(
                    self.studio_root, self.initial_run_dir, str(payload.get("name") or ""),
                    payload.get("skeleton"))
                self._send_json({"ok": True, "character": created})
                return
            if path == "/api/characters/select":
                payload = self._read_body()
                selected = select_studio_character(
                    self.studio_root, self.initial_run_dir, str(payload.get("id") or ""))
                with _character_lock:
                    type(self).run_dir = selected
                self._send_json({"ok": True, "id": str(payload.get("id") or "")})
                return
            if path == "/api/characters/delete":
                payload = self._read_body()
                deleted = delete_studio_character(
                    self.studio_root,
                    self.initial_run_dir,
                    self.run_dir,
                    str(payload.get("id") or ""),
                )
                with _character_lock:
                    type(self).run_dir = Path(deleted["activeRunDir"]).resolve()
                self._send_json({
                    key: value for key, value in deleted.items()
                    if key != "activeRunDir"
                })
                return
            if path == "/api/base-upload":
                payload = self._read_body()
                with publish_guard(self.run_dir):
                    result = save_base_upload(self.run_dir, payload)
                self._send_json(result)
                return
            if path == "/api/base-create":
                payload = self._read_body()
                result = create_base_character(self.run_dir, payload)
                self._send_json(result)
                return
            if path == "/api/generate-state":
                payload = self._read_body()
                result = generate_state_take(self.run_dir, payload)
                self._send_json(result)
                return
            if path == "/api/auto-generate":
                payload = self._read_body()
                result = start_auto_generation(self.run_dir, payload)
                self._send_json(result, 202 if result.get("status") != "completed" else 200)
                return
            if path == "/api/animations/create":
                active = auto_generation_status(self.run_dir)
                if active.get("status") in ("queued", "running"):
                    raise RuntimeError("wait for the current automatic generation to finish")
                payload = self._read_body()
                created = create_custom_animation(self.run_dir, payload)
                generation = start_auto_generation(self.run_dir, {
                    "states": created["states"],
                    "requireSkeleton": False,
                    "kind": "custom_animation",
                    "label": created["name"],
                })
                created["generation"] = generation
                self._send_json(created, 202 if generation.get("status") != "completed" else 200)
                return
            if path == "/api/notifications/read":
                payload = self._read_body()
                self._send_json(mark_notifications_read(self.run_dir, payload))
                return
            if path == "/api/skeleton/save":
                payload = self._read_body()
                result = save_skeleton_profile(self.run_dir, str(payload.get("name") or "") or None)
                self._send_json(result)
                return
            if path == "/api/skeletons/delete":
                active = auto_generation_status(self.run_dir)
                if active.get("status") in ("queued", "running"):
                    raise RuntimeError("wait for the current automatic generation to finish")
                payload = self._read_body()
                result = delete_skeleton_profile(
                    self.run_dir, str(payload.get("profileId") or ""))
                self._send_json(result)
                return
            if path == "/api/curation":
                payload = self._read_body()
                # Serialize the curation write with a concurrent --force publish (same
                # publish_guard the swap holds), and reject a payload whose states are no
                # longer in the current run. So a stale autosave from a webview still on the
                # pre-re-import run can neither interleave with the swap nor land old-state
                # curation on the new run (Consistency/Isolation — observable 409, not a
                # silent overwrite). This uses the rwlock, not the pipeline write lock, so
                # normal curation edits still never block on a running compose/extract.
                with publish_guard(self.run_dir):
                    # reject a stale autosave: the POST must echo the runRevision it was
                    # loaded with. If the run generation changed under this session — a
                    # `--force` re-import or a re-extract, even one keeping the same state
                    # names but swapping the candidate images — old selections/transforms
                    # must not apply to the new frames (Consistency: observable 409, not a
                    # silent overwrite). runRevision is a content fingerprint of the frames.
                    stale = payload.get("runRevision") != run_revision(self.run_dir)
                    if not stale:
                        write_curation_atomic(self.run_dir, payload)
                if stale:
                    self._send_json({"error": "curation is from a different run generation "
                                     "(the run changed under this session; reload the view)"}, 409)
                else:
                    saved_curation, _ = load_curation_report(self.run_dir)
                    revisions = {
                        name: entry.get("revision")
                        for name, entry in ((saved_curation or {}).get("states") or {}).items()
                        if isinstance(entry, dict)
                    }
                    self._send_json({
                        "ok": True,
                        "runRevision": run_revision(self.run_dir),
                        "stateRevisions": revisions,
                    })
                return
            if path == "/api/compose":
                result = run_compose(self.run_dir)
                self._send_json(result, 200 if result["ok"] else 500)
                return
            if path == "/api/export":
                result = run_export(self.run_dir)
                self._send_json(result, 200 if result["ok"] else 500)
                return
            if path == "/api/export-gif":
                result = run_export_gif(self.run_dir)
                self._send_json(result, 200 if result["ok"] else 500)
                return
        except (Exception, SystemExit) as exc:
            self._send_json({"error": str(exc)}, 500)
            return
        self._send_json({"error": "not found", "path": path}, 404)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run-dir", required=True, type=Path)
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=0, help="0 picks a free port")
    parser.add_argument("--no-open", action="store_true", help="do not auto-open the browser")
    parser.add_argument("--lang", choices=["en", "ko"], default="en", help="initial UI language (toggleable in the webview)")
    args = parser.parse_args()

    run_dir = args.run_dir.expanduser().resolve()
    if not (run_dir / "sprite-request.json").is_file():
        raise SystemExit(f"not a sprite-gen run dir (no sprite-request.json): {run_dir}")
    if not CURATOR_DIR.is_dir():
        raise SystemExit(f"missing curator SPA dir: {CURATOR_DIR}")

    handler = partial(CurationHandler)
    CurationHandler.run_dir = run_dir
    CurationHandler.initial_run_dir = run_dir
    CurationHandler.studio_root = run_dir.parent
    CurationHandler.lang = args.lang
    server = ExclusiveThreadingHTTPServer((args.host, args.port), handler)
    host, port = server.server_address
    url = f"http://{host}:{port}/"
    print(f"sprite-gen curation webview: {url}")
    print(f"  run-dir: {run_dir}")
    # 뷰 계약 자가 보고 — base 참조 줄 / 생성 재료 칩 / 픽셀 격자 충족 여부를 한 줄로.
    # 셋 다 없으면 "소스 없는 뷰" 경고 (관측 가능하게 — No Silent Fallback).
    try:
        snapshot = build_run_state(run_dir)
        c = snapshot.get("contract", {})
        n_states = len(snapshot.get("states", []))
        print(f"  view-contract: base={'yes' if c.get('base') else 'no'} · "
              f"refs={c.get('refsStates', 0)}/{n_states} states · "
              f"grid={'yes' if c.get('grid') else 'no'}")
        if c.get("sourceless"):
            print("  WARNING: sourceless view — no base-source, no generation-material refs, no pixel grid. "
                  "이 뷰는 세션마다 경험이 갈라진다 (run-contract.md §3/§4: _base/_refs 동봉 또는 fit.pixel_perfect 권장).")
    except Exception as exc:  # 계약 보고 실패는 서빙을 막지 않는다 — 관측만
        print(f"  view-contract: unavailable ({exc})")
    print("  Ctrl-C to stop.")
    if not args.no_open:
        webbrowser.open(url)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nstopped.")
    finally:
        server.server_close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
