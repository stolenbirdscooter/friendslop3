shader_type spatial;
// An endless undulating sea of cloud. Displaced in the vertex stage, toon-lit.
uniform sampler2D noise : repeat_enable, filter_linear_mipmap;
uniform vec4 top_color : source_color = vec4(1.0, 0.98, 0.95, 1.0);
uniform vec4 low_color : source_color = vec4(0.78, 0.74, 0.92, 1.0);
uniform float height = 7.0;
varying float h;

float field(vec2 p) {
	float a = textureLod(noise, p * 0.0055 + vec2(TIME * 0.0035, TIME * 0.0018), 0.0).r;
	float b = textureLod(noise, p * 0.019 - vec2(TIME * 0.006, -TIME * 0.004), 0.0).r;
	return a * 0.68 + b * 0.32;
}

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float n = field(wp.xz);
	float e = 3.0;
	float nx = field(wp.xz + vec2(e, 0.0));
	float nz = field(wp.xz + vec2(0.0, e));
	float k = height * 2.0;
	VERTEX.y += (n - 0.5) * k;
	NORMAL = normalize(vec3(-(nx - n) * k / e, 1.0, -(nz - n) * k / e));
	h = n;
}

void fragment() {
	ALBEDO = mix(low_color.rgb, top_color.rgb, smoothstep(0.32, 0.7, h));
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float band = smoothstep(0.0, 0.25, ndl) * 0.6 + smoothstep(0.55, 0.62, ndl) * 0.4;
	DIFFUSE_LIGHT += LIGHT_COLOR / PI * band;
}
