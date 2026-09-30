// Enemy sprite effects: hit flash + pixel dissolve when defeated.
shader_type canvas_item;

uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0);
uniform float dissolve : hint_range(0.0, 1.0) = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec4 c = COLOR;
	vec2 px = floor(UV / TEXTURE_PIXEL_SIZE);
	if (hash(px) < dissolve) {
		discard;
	}
	c.rgb = mix(c.rgb, flash_color.rgb, flash);
	COLOR = c;
}
