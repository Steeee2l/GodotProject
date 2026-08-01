# Validated 8-way player-cat reference pack

This pack is built from the already accepted player sprite set in
`assets/characters/cat_8way`. It is the directional/layout reference for new
sprite-gen runs; it is not an identity reference. Each idle anchor is frame 0
of the corresponding direction, and each walk strip is a four-frame horizontal
strip assembled from the accepted walk frames.

Direction order follows the project convention:
`down`, `down_right`, `right`, `up_right`, `up`, `up_left`, `left`, `down_left`.

Generation prompts must preserve the requested character's silhouette and
equipment while borrowing only camera angle, ground contact, and walk timing
from this pack.
