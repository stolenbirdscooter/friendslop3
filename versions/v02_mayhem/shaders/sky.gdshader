shader_type sky;
uniform vec4 top_color : source_color = vec4(0.36, 0.6, 0.84, 1.0);
uniform vec4 horizon_color : source_color = vec4(1.0, 0.86, 0.7, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.98, 0.93, 0.9, 1.0);
uniform vec4 sun_color : source_color = vec4(1.0, 0.92, 0.7, 1.0);
uniform float star_amount = 0.0;

float hash(vec3 p) { return fract(sin(dot(p, vec3(12.9898, 78.233, 45.164))) * 43758.5453); }

void sky() {
	float y = EYEDIR.y;
	vec3 c = mix(horizon_color.rgb, top_color.rgb, smoothstep(-0.02, 0.55, y));
	c = mix(c, bottom_color.rgb, smoothstep(0.0, -0.25, y));
	if (LIGHT0_ENABLED) {
		float d = dot(EYEDIR, LIGHT0_DIRECTION);
		c += sun_color.rgb * smoothstep(0.9975, 0.9985, d) * 1.4;
		c += sun_color.rgb * pow(max(d, 0.0), 48.0) * 0.35;
		c += sun_color.rgb * pow(max(d, 0.0), 6.0) * 0.12;
	}
	if (star_amount > 0.0 && y > 0.0) {
		vec3 cell = floor(EYEDIR * 220.0);
		float s = step(0.997, hash(cell));
		c += vec3(s) * star_amount * smoothstep(0.0, 0.3, y);
	}
	COLOR = c;
}
