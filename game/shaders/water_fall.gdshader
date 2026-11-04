shader_type spatial;
render_mode unshaded, cull_disabled;

// The cascade sheet: pale falling water with white foam streaks scrolling down
// it, and soft side fades so the box sections stop reading as rectangles.
// Unshaded on purpose — painted water must not take the amber bulb's tint.
// No RNG and no screen reads: the same TIME gives the same frame on the Mobile
// and the GL Compatibility renderer alike.

uniform vec4 water_color : source_color = vec4(0.51, 0.65, 0.76, 1.0);
uniform vec4 foam_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float alpha : hint_range(0.0, 1.0) = 0.85;
uniform float speed = 1.4;
uniform float streak_scale = 3.0;
uniform float foam_amount : hint_range(0.0, 1.0) = 0.55;
uniform float edge_fade : hint_range(0.0, 0.5) = 0.12;
uniform float light_level : hint_range(0.0, 1.0) = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float value_noise(float x) {
	float i = floor(x);
	float f = fract(x);
	float a = hash(vec2(i, 3.7));
	float b = hash(vec2(i + 1.0, 3.7));
	return mix(a, b, f * f * (3.0 - 2.0 * f));
}

void fragment() {
	// Streaks run with the fall: a repeating scroll down the sheet, broken into
	// columns so it reads as separate rills of foam rather than one band.
	float scroll = UV.y * streak_scale - TIME * speed;
	float column = UV.x * 34.0;
	float wobble = value_noise(column * 0.7) * 4.0;
	float drift = floor(scroll + wobble);
	float foam = value_noise(column + drift * 7.3);
	foam = smoothstep(0.62, 0.95, foam);
	// Taper each scroll step so the streaks have heads and tails, not bands.
	float phase = fract(scroll + wobble);
	foam *= smoothstep(0.0, 0.35, phase) * smoothstep(1.0, 0.6, phase);
	// Side fades: the flat boxes lose their rectangular edges.
	float side = smoothstep(0.0, edge_fade, UV.x) * smoothstep(1.0, 1.0 - edge_fade, UV.x);
	vec3 col = mix(water_color.rgb, foam_color.rgb, foam * foam_amount) * light_level;
	ALBEDO = col;
	ALPHA = alpha * side;
}
