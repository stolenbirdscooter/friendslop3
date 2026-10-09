shader_type spatial;
// Basket weave: over-under strands with rounded shading, toon-lit.
uniform vec4 light_col : source_color = vec4(0.84, 0.6, 0.33, 1.0);
uniform vec4 dark_col : source_color = vec4(0.55, 0.35, 0.17, 1.0);
uniform vec2 density = vec2(22.0, 7.0);
varying vec3 opos;
varying vec3 onrm;
void vertex() { opos = VERTEX; onrm = NORMAL; }
void fragment() {
	// project onto the face plane so every side of a box gets a weave
	vec2 p = abs(onrm.x) > 0.5 ? opos.zy : (abs(onrm.z) > 0.5 ? opos.xy : opos.xz);
	vec2 g = p * density;
	vec2 cell = floor(g);
	vec2 f = fract(g);
	float over = mod(cell.x + cell.y, 2.0);
	float strand = over > 0.5 ? sin(f.y * 3.14159) : sin(f.x * 3.14159);
	float gap = smoothstep(0.0, 0.12, min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y)));
	vec3 c = mix(dark_col.rgb, light_col.rgb, strand * 0.75 + 0.25) * mix(0.6, 1.0, gap);
	ALBEDO = c;
}
void light() {
	float ndl = dot(NORMAL, LIGHT);
	float b = smoothstep(-0.02, 0.05, ndl) * 0.72 + smoothstep(0.5, 0.56, ndl) * 0.28;
	b *= smoothstep(0.2, 0.5, ATTENUATION);
	DIFFUSE_LIGHT += LIGHT_COLOR / PI * b;
}
