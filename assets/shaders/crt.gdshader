shader_type canvas_item;
// Full-screen CRT pass: subtle curvature, chromatic fringe, scanlines,
// vignette, grain. `glitch` (0..1) adds horizontal tearing and is driven by
// hull damage — the diegetic HUD degradation from the original game.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float intensity : hint_range(0.0, 1.0) = 0.85;
uniform float glitch : hint_range(0.0, 1.0) = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 cc = uv - 0.5;
	uv += cc * dot(cc, cc) * 0.045 * intensity;

	float row = floor(uv.y * 48.0);
	float tear = step(1.0 - glitch * 0.12, hash(vec2(row, floor(TIME * 9.0))));
	uv.x += tear * glitch * 0.035 * sin(TIME * 47.0 + row);

	float ca = 0.0012 * intensity + glitch * 0.004;
	vec3 col;
	col.r = texture(screen_tex, uv + vec2(ca, 0.0)).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv - vec2(ca, 0.0)).b;

	float scan = 0.5 + 0.5 * sin(FRAGCOORD.y * 1.5708);
	col *= mix(1.0, 0.84 + 0.16 * scan, intensity);

	float vig = smoothstep(0.95, 0.30, length(cc) * 1.2);
	col *= mix(1.0, vig, 0.6 * intensity);

	col += (hash(FRAGCOORD.xy + vec2(TIME * 61.0, TIME * 17.0)) - 0.5) * 0.03 * intensity;
	col *= 1.0 - glitch * 0.15 * step(0.97, hash(vec2(floor(TIME * 20.0), 3.0)));

	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		col = vec3(0.0);
	}
	COLOR = vec4(col, 1.0);
}
