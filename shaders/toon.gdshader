// Picture-book toon look: three soft bands, lilac shade, a faint watercolor-paper wash.
// Vertex color alpha: 1 = lit, 0.5 = glowing (lamp bulb), 0 = flat painted (blush, glass).
shader_type spatial;
render_mode specular_disabled, ambient_light_disabled;

uniform vec3 shadow_tint : source_color = vec3(0.9, 0.87, 0.97);
uniform vec4 tint : source_color = vec4(0.0);   // placement ghost: green fits, red blocked
uniform float light_scale = 0.3183;   // LIGHT_COLOR arrives pre-multiplied by PI
uniform float paper_strength = 0.07;
uniform float glow_boost = 1.6;

varying vec3 world_pos;
varying vec3 world_normal;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 an = abs(world_normal);
	vec2 p = an.y > 0.6 ? world_pos.xz : (an.x > an.z ? world_pos.zy : world_pos.xy);
	float wash = vnoise(p * 1.4) * 0.6 + vnoise(p * 5.0) * 0.4;
	float grain = hash(floor(p * 90.0));
	float paper = 1.0 - paper_strength * (wash * 0.8 + grain * 0.3);
	vec3 c = mix(COLOR.rgb * paper, tint.rgb, tint.a);
	float shaded = step(0.75, COLOR.a);
	float glow = step(0.25, COLOR.a) * (1.0 - shaded);
	ALBEDO = c * shaded;
	EMISSION = c * (1.0 - shaded) * (1.0 + glow * glow_boost);
}

void light() {
	float d = dot(NORMAL, LIGHT);
	float lit = smoothstep(-0.02, 0.05, d);
	float band = 0.72 + lit * 0.2 + smoothstep(0.55, 0.62, d) * 0.08;
	vec3 shade;
	if (LIGHT_IS_DIRECTIONAL) {
		// the sun: shadowed and turned-away sides fall to a lilac band instead of dark
		shade = mix(shadow_tint * band, vec3(band), lit * ATTENUATION);
	} else {
		// window and lamp light only add warmth where they reach
		shade = vec3(lit * band * ATTENUATION);
	}
	DIFFUSE_LIGHT += shade * LIGHT_COLOR * light_scale;
}
