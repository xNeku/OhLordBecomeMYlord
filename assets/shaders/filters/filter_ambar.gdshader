shader_type canvas_item;
// Filtro 3 · Fosforo ambar: monitor monocromo de los 80, con lineas de barrido.
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest, repeat_disable;
uniform vec3 dark = vec3(0.06, 0.02, 0.0);
uniform vec3 light = vec3(1.0, 0.70, 0.16);
uniform float scanline : hint_range(0.0, 1.0) = 0.25;
uniform float line_height = 3.0;
void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float l = pow(dot(c, vec3(0.299, 0.587, 0.114)), 0.8);
	float row = mod(floor(FRAGCOORD.y / line_height), 2.0);
	vec3 outc = mix(dark, light, clamp(l * 1.4, 0.0, 1.0)) * (1.0 - scanline * row);
	COLOR = vec4(outc, 1.0);
}
