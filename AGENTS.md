# Repository Guidelines

## Project Structure & Module Organization

This is a Godot 4.5.1 project. The main scene is scenes/main.tscn; gameplay logic lives in scripts/, with scripts/game_state.gd owning persistent progression. Reusable scenes and visual modules are under scenes/ and scenes/modules/.

Use assets/ for authored and generated runtime assets. The vendored sprite pipeline is in tools/sprite-gen; helpers and QA scripts are in tools/. Smoke tests and visual capture scenes are in tests/. Do not edit .godot/, build/, or generated output by hand.

## Build, Test, and Development Commands

- Open the repository in Godot 4.5.1 and press F6/F5 to run the project.
- Validate project loading headlessly: godot --headless --path . --editor --quit
- Export Windows: godot --headless --path . --export-release "Windows Desktop"
- Export Web: godot --headless --path . --export-release "Web"
- Run a targeted smoke test: godot --headless --path . --script res://tests/weapon_system_smoke_test.gd
- Run local smoke tests through `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_safe_godot_smoke_test.ps1 -ScriptPath <res://test_path>`. It refuses to start a second Godot process while the editor or embedded game is open.
- Prepare sprite generation: .\tools\run_sprite_pipeline.ps1 -CharacterId <id> -BaseImage <path> -PrepareOnly

The CI workflow in .github/workflows/build.yml validates the project and produces Windows and Web artifacts.

## Coding Style & Naming Conventions

Use four-space indentation in GDScript. Functions and variables use snake_case, constants use UPPER_SNAKE_CASE, and classes/scenes use PascalCase. Keep gameplay state in its owning system rather than duplicating it in UI code. Match existing node names. Directional sprites use: down, down_right, right, up_right, up, up_left, left, down_left.

## Testing Guidelines

Tests are Godot smoke tests named <feature>_smoke_test.gd; visual checks use matching .tscn scenes. Run focused tests while iterating, then project validation and the relevant export. There is no coverage threshold; add a focused smoke test for new gameplay when practical.

Never launch a headless editor, smoke test, import, or export while the interactive Godot editor or its embedded game is running. Both processes share project import state and `user://` data, which can destabilize the editor. Let the user perform visible playtests; run automated validation only after the interactive process has closed, always with a dedicated `--log-file`.

## Commit & Pull Request Guidelines

Recent commits use short prefixes such as feat:, fix:, and balance: (for example, feat: expand raid stealth and extraction loop). Keep commits focused. Pull requests should describe player-visible changes, list validation commands, call out save/data migrations, and include screenshots for UI, map, sprite, or shelter changes. Do not commit credentials, provider tokens, or local user:// save data.

## Sprite and Generated Asset Safety

For sprite changes, keep the base image, request JSON, raw rows, QA output, atlas, and manifest consistent. Verify frame counts and directional ordering with the existing QA scripts before wiring an atlas into gameplay.
