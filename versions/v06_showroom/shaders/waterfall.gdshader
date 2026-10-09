shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 col : source_color = vec4(0.62, 0.84, 0.95, 1.0);
uniform vec4 foam : source_color = vec4(1.0, 1.0, 1.0, 1.0);
float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() {
	// streaks falling downward, fading into mist toward the bottom
	float x = floor(UV.x * 14.0);
	float speed = 0.6 + hash(vec2(x, 1.0)) * 0.6;
	float s = fract(UV.y * 3.0 - TIME * speed + hash(vec2(x, 3.0)));
	float streak = smoothstep(0.55, 0.95, s);
	float edge = smoothstep(0.0, 0.15, UV.x) * smoothstep(1.0, 0.85, UV.x);
	vec3 c = mix(col.rgb, foam.rgb, streak * 0.8 + smoothstep(0.7, 1.0, UV.y) * 0.5);
	ALBEDO = c;
	ALPHA = edge * (1.0 - smoothstep(0.55, 1.0, UV.y)) * (0.55 + streak * 0.4);
}
