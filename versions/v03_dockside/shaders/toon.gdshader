shader_type spatial;
// Storybook toon: two hard light bands, cool ambient shadows, rubbery gloss blob, warm rim.
uniform vec4 albedo : source_color = vec4(1.0);
uniform float gloss = 0.0;
uniform float rim_amount = 0.25;
uniform float grain = 0.0; // subtle hand-painted mottling

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

varying vec3 wpos;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 c = albedo.rgb;
	if (grain > 0.0) {
		vec2 g = floor(wpos.xz * 2.0 + wpos.y * 1.3);
		c *= 1.0 - grain * hash(g);
	}
	ALBEDO = c;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float a = ATTENUATION;
	float band = smoothstep(-0.02, 0.05, ndl) * 0.72 + smoothstep(0.5, 0.56, ndl) * 0.28;
	band *= smoothstep(0.2, 0.5, a);
	DIFFUSE_LIGHT += LIGHT_COLOR / PI * band;
	float rim = smoothstep(0.6, 0.66, 1.0 - dot(NORMAL, VIEW)) * rim_amount * band;
	DIFFUSE_LIGHT += LIGHT_COLOR / PI * rim;
	if (gloss > 0.0) {
		vec3 h = normalize(LIGHT + VIEW);
		float s = smoothstep(0.975, 0.988, dot(NORMAL, h)) * gloss * band;
		SPECULAR_LIGHT += LIGHT_COLOR / PI * s * 0.9;
	}
}
