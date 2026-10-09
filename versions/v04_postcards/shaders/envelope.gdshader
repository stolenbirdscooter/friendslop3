shader_type spatial;
// Patchwork hot-air envelope: alternating gores, a cream belly band with stitched
// dashes, and darker patch rectangles where it has been mended.
uniform vec4 col_a : source_color = vec4(0.91, 0.34, 0.29, 1.0);
uniform vec4 col_b : source_color = vec4(0.95, 0.7, 0.24, 1.0);
uniform vec4 col_c : source_color = vec4(0.25, 0.7, 0.65, 1.0);
uniform vec4 band : source_color = vec4(1.0, 0.96, 0.86, 1.0);
uniform float gores = 12.0;
uniform float glow = 0.0; // burner light from below
varying vec3 opos;
void vertex() { opos = VERTEX; }

float hash(vec2 p) { return fract(sin(dot(p, vec2(41.3, 289.1))) * 15731.743); }

void fragment() {
	float ang = atan(opos.z, opos.x) / 6.28318 + 0.5;
	float g = floor(ang * gores);
	float k = mod(g, 3.0);
	vec3 c = k < 0.5 ? col_a.rgb : (k < 1.5 ? col_b.rgb : col_c.rgb);
	float yy = opos.y;
	// belly band
	float bandm = step(abs(yy + 0.05), 0.11);
	c = mix(c, band.rgb, bandm);
	float dash = step(0.5, fract(ang * gores * 4.0)) * step(abs(abs(yy + 0.05) - 0.085), 0.008);
	c = mix(c, vec3(0.17, 0.11, 0.16), dash);
	// seams
	float seam = smoothstep(0.012, 0.0, abs(fract(ang * gores) - 0.5) - 0.488);
	c *= 1.0 - seam * 0.35;
	// mended patches
	vec2 cell = floor(vec2(ang * gores * 2.0, yy * 6.0));
	float h = hash(cell);
	vec2 f = fract(vec2(ang * gores * 2.0, yy * 6.0));
	float patch = step(0.86, h) * step(0.2, f.x) * step(f.x, 0.8) * step(0.25, f.y) * step(f.y, 0.75);
	c = mix(c, c * 0.72 + vec3(0.06, 0.03, 0.0), patch);
	ALBEDO = c;
	EMISSION = vec3(1.0, 0.55, 0.2) * glow * smoothstep(0.1, -0.9, yy) * 0.6;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float b = smoothstep(-0.02, 0.06, ndl) * 0.72 + smoothstep(0.5, 0.56, ndl) * 0.28;
	b *= smoothstep(0.2, 0.5, ATTENUATION);
	DIFFUSE_LIGHT += LIGHT_COLOR / PI * b;
	vec3 h = normalize(LIGHT + VIEW);
	SPECULAR_LIGHT += LIGHT_COLOR / PI * smoothstep(0.96, 0.975, dot(NORMAL, h)) * b * 0.5;
}
