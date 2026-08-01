# P0 generated source assets

These images were generated on 2026-08-01 as the first P0 source pack for the
asset checklist. They are not yet wired into runtime scenes.

- combat_vfx_sheet_v1.png: 3×3 source sheet for muzzle flashes, impacts, explosion, rocket trail, and melee slash.
- mission_status_icon_sheet_v1.png: 3×4 source sheet for mission, extraction, threat, boss, and objective icons.
- consumable_icon_sheet_v1.png: 3×4 source sheet for food, medical, ammunition, mod parts, and scrap.
- enemy_grenadier_concept_v1.png: one-facing character identity reference for the future 8-direction grenadier run.
- player_hit_front_strip_v1.png: four-frame front-facing hit-reaction source strip for sprite-gen conversion.

Before runtime use, slice sheets into individual PNGs, run the sprite-gen
chroma/edge/frame QA, assign stable names and pivots, and register the final
assets in the relevant catalog. The generated sheets intentionally remain
versioned source references so later regeneration does not overwrite them.
