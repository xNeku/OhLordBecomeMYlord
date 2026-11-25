shader_type canvas_item;
// Filtro 1 · CRT: lineas de barrido, mascara RGB suave, curvatura y viñeta.
// Uso: un ColorRect a pantalla completa (mouse_filter = ignore) en un CanvasLayer por encima de todo, con este material.
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest, repeat_disable;
uniform float curvature : hint_range(0.0, 0.2) = 0.06;
uniform float scanline : hint_range(0.0, 1.0) = 0.35;
uniform float vignette : hint_range(0.0, 1.0) = 0.45;
uniform float line_height = 3.0; // alto en pixeles de pantalla de cada linea de barrido (= escala del juego)
void fragment() {
	vec2 uv = SCREEN_UV * 2.0 - 1.0;
	uv *= 1.0 + curvature * dot(uv, uv);
	vec2 suv = uv * 0.5 + 0.5;
	if (suv.x < 0.0 || suv.x > 1.0 || suv.y < 0.0 || suv.y > 1.0) { COLOR = vec4(0.0, 0.0, 0.0, 1.0); }
	else {
		vec3 c = texture(screen_tex, suv).rgb;
		float row = mod(floor(FRAGCOORD.y / line_height), 2.0);
		c *= 1.0 - scanline * row;
		float col = mod(FRAGCOORD.x, 3.0);
		c *= vec3(col < 1.0 ? 1.0 : 0.88, col >= 1.0 && col < 2.0 ? 1.0 : 0.88, col >= 2.0 ? 1.0 : 0.88);
		float v = 1.0 - vignette * dot(uv * 0.55, uv * 0.55);
		COLOR = vec4(c * v * 1.08, 1.0);
	}
}
