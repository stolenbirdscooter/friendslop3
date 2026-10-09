shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 tint : source_color = vec4(1.0);
varying float yy;
void vertex() { yy = VERTEX.y / 60.0 + 0.5; }
void fragment() {
	float rim = pow(1.0 - abs(dot(NORMAL, VIEW)), 1.5);
	float fade = (1.0 - yy) * smoothstep(0.0, 0.05, yy);
	float pulse = 0.75 + 0.25 * sin(TIME * 2.0 - yy * 12.0);
	ALBEDO = tint.rgb * (0.35 + rim) * fade * pulse * 0.8;
	ALPHA = 1.0;
}
