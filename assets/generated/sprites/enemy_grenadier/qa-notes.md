# Directional QA notes

- Identity source: `base-source.png` from `p0_sources/enemy_grenadier_concept_v1.png`.
- Direction/layout references: `references/anchors/*_idle.png` from the validated player-cat pack `8way_cat_player_validated`.
- Walk rhythm references: `references/anchors/*_walk.png` from the same validated pack.
- Reference images constrain screen-axis, ground line, silhouette placement, and foot-phase only.
- Do not copy the reference character's face, outfit, palette, props, or accessories.
- All 16 rows now extract into a complete manifest and atlas. Runtime integration remains blocked until every walk row passes the semantic foot-phase gate; the current passing rows are `down_walk`, `right_walk`, `up_walk`, `up_right_walk`, and `down_left_walk`. `left_walk`, `down_right_walk`, and `up_left_walk` still require a human-reviewed leg swap before gameplay wiring.
