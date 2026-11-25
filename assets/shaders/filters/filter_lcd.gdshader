shader_type canvas_item;
// Filtro 2 · LCD: rejilla de pixeles visible, como una pantalla de consola de mano.
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest, repeat_disable;
uniform float cell = 3.0;                       // pixeles de pantalla por pixel de juego
uniform float grid_strength : hint_range(0.0, 1.0) = 0.45;
void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	vec2 p = mod(FRAGCOORD.xy, cell);
	float g = (p.x < 1.0 || p.y < 1.0) ? 1.0 : 0.0;
	c *= 1.0 - grid_strength * g;
	c = mix(c, vec3(dot(c, vec3(0.299, 0.587, 0.114))), 0.12); // un punto menos saturado
	COLOR = vec4(c * 1.05, 1.0);
}
