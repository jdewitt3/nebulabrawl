// Earthbound-style psychedelic battle background.
// Rows of pixels wobble side to side while the color bands cycle.
shader_type canvas_item;

uniform vec4 col_a : source_color = vec4(0.05, 0.02, 0.12, 1.0);
uniform vec4 col_b : source_color = vec4(0.16, 0.06, 0.31, 1.0);
uniform vec4 col_c : source_color = vec4(0.12, 0.42, 0.54, 1.0);
uniform vec4 col_d : source_color = vec4(0.38, 0.25, 0.63, 1.0);
uniform int pattern = 0;        // 0 = diamonds, 1 = interlaced waves, 2 = spiral
uniform float speed = 1.0;
uniform float intensity = 0.0;  // 0..1, more wobble when things get dangerous
uniform float gray = 0.0;       // 0..1, drains color on defeat
uniform vec2 res = vec2(336.0, 196.0);

void fragment() {
	vec2 p = floor(UV * res);
	float t = TIME * speed;
	float amp = 6.0 + intensity * 10.0;
	float wob = sin(p.y * 0.09 + t * 2.3) * amp;
	if (pattern == 1 && mod(p.y, 2.0) < 1.0) {
		wob = -wob; // interlaced: odd rows move the other way
	}
	vec2 q = vec2(p.x + wob, p.y + sin(p.x * 0.04 + t * 1.3) * 3.0);
	float v;
	if (pattern == 0) {
		v = abs(fract(q.x / 24.0 + t * 0.1) - 0.5) + abs(fract(q.y / 24.0 - t * 0.05) - 0.5);
		v *= 4.0;
	} else if (pattern == 1) {
		v = q.y / 10.0 + sin(q.x / 18.0 + t) * 1.5;
	} else {
		vec2 c = q - res * 0.5;
		v = length(c) / 9.0 - t * 1.5 + atan(c.y, c.x) / 6.28318 * 4.0;
	}
	float band = mod(floor(v + t * 0.9), 4.0);
	vec4 col = band < 1.0 ? col_a : (band < 2.0 ? col_b : (band < 3.0 ? col_c : col_d));
	float g = dot(col.rgb, vec3(0.3, 0.59, 0.11));
	col.rgb = mix(col.rgb, vec3(g) * 0.5, gray);
	COLOR = col;
}
