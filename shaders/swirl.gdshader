// Battle transition: a spiral that swallows the screen.
shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 color_a : source_color = vec4(0.02, 0.0, 0.06, 1.0);
uniform vec4 color_b : source_color = vec4(0.30, 0.08, 0.48, 1.0);

void fragment() {
	vec2 px = floor(UV * vec2(320.0, 180.0)) / vec2(320.0, 180.0);
	vec2 p = (px - 0.5) * vec2(320.0 / 180.0, 1.0);
	float r = length(p);
	float a = atan(p.y, p.x) / 6.28318 + 0.5;
	float s = fract(a * 3.0 + r * 2.0);
	float cover = progress * 2.4 - r * 1.2 - 0.001;
	float on = step(s, cover);
	vec4 c = mix(color_a, color_b, step(0.5, fract(r * 6.0 - TIME * 2.0)) * 0.6);
	COLOR = vec4(c.rgb, on);
}
