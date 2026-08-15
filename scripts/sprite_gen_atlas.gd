class_name SpriteGenAtlas
extends RefCounted

## Runtime bridge for an atlas produced by tools/run_sprite_pipeline.ps1.
## The generated manifest is the source of truth for frame rectangles; this
## loader never guesses a grid from the texture dimensions.