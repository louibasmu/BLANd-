shader_type canvas_item;

void fragment() {
	vec2 offset = TEXTURE_PIXEL_SIZE * 1.5;
	COLOR = texture(TEXTURE, UV) * 0.25;
	COLOR += texture(TEXTURE, UV + vec2(offset.x, 0.0)) * 0.125;
	COLOR += texture(TEXTURE, UV - vec2(offset.x, 0.0)) * 0.125;
	COLOR += texture(TEXTURE, UV + vec2(0.0, offset.y)) * 0.125;
	COLOR += texture(TEXTURE, UV - vec2(0.0, offset.y)) * 0.125;
	COLOR += texture(TEXTURE, UV + offset) * 0.0625;
	COLOR += texture(TEXTURE, UV - offset) * 0.0625;
	COLOR += texture(TEXTURE, UV + vec2(offset.x, -offset.y)) * 0.0625;
	COLOR += texture(TEXTURE, UV + vec2(-offset.x, offset.y)) * 0.0625;
}
