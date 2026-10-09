shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque;
uniform vec4 color : source_color = vec4(0.17, 0.11, 0.16, 1.0);
uniform float width = 0.03;
void vertex() {
	VERTEX += NORMAL * width;
}
void fragment() {
	ALBEDO = color.rgb;
}
