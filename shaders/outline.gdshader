// Inverted-hull outline drawn as the toon material's next pass. UV.x scales the width per part.
shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;

uniform vec4 outline_color : source_color = vec4(0.29, 0.204, 0.149, 1.0);
uniform float thickness = 0.02;

void vertex() {
	VERTEX += NORMAL * thickness * UV.x;
}

void fragment() {
	if (UV.x < 0.01) {
		discard;   // parts without an outline (floor tiles, eyes, blush)
	}
	ALBEDO = outline_color.rgb;
}
