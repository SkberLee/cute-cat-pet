# scripts/pixel_anim.gd
## AnimatedSprite2D with AnimationPlayer-like aliases used by smokes and shot.gd.
extends AnimatedSprite2D

var current_animation: StringName:
	get:
		return animation
	set(v):
		if sprite_frames and sprite_frames.has_animation(v):
			play(v)

var current_animation_length: float:
	get:
		return PixelUtil.anim_len(self, String(animation))

func has_animation(name: StringName) -> bool:
	return sprite_frames != null and sprite_frames.has_animation(name)
