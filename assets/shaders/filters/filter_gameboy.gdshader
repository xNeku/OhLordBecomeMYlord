shader_type canvas_item;
// Filtro 4 · Game Boy: cuatro verdes, como la pantalla original.
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest, repeat_disable;
uniform vec3 c0 = vec3(0.059, 0.220, 0.059); // #0f380f
uniform vec3 c1 = vec3(0.188, 0.384, 0.188); // #306230
uniform vec3 c2 = vec3(0.545, 0.675, 0.059); // #8bac0f
uniform vec3 c3 = vec3(0.608, 0.737, 0.059); // #9bbc0f
void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	l = pow(l, 0.7);
	vec3 outc = l < 0.12 ? c0 : (l < 0.40 ? c1 : (l < 0.68 ? c2 : c3));
	if (l < 0.02) outc = c0; // el fondo negro queda en el verde mas oscuro
	COLOR = vec4(outc, 1.0);
}
