shader_type spatial;
uniform vec4 top_color : source_color = vec4(1.0, 0.99, 0.96, 1.0);
uniform vec4 shade_color : source_color = vec4(0.8, 0.77, 0.93, 1.0);
void fragment() {
	ALBEDO = vec3(1.0);
}
void light() {
	float ndl = dot(NORMAL, LIGHT);
	float band = smoothstep(-0.1, 0.25, ndl);
	DIFFUSE_LIGHT += mix(shade_color.rgb * 0.55, top_color.rgb, band) * LIGHT_COLOR / PI;
}
