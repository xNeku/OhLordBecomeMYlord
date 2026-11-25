shader_type canvas_item;
// Dibuja instancias de un atlas. Por instancia:
//   COLOR (color de instancia) = tinte y alfa
//   INSTANCE_CUSTOM.x = columna (fotograma), .y = fila (sprite), .z = destello blanco 0..1
uniform sampler2D atlas : filter_nearest, repeat_disable;
uniform vec2 grid = vec2(2.0, 4.0); // columnas, filas del atlas

varying vec4 custom;

void vertex() {
	custom = INSTANCE_CUSTOM;
}

void fragment() {
	vec2 uv = (UV + custom.xy) / grid;
	vec4 c = texture(atlas, uv);
	vec3 rgb = mix(c.rgb * COLOR.rgb, vec3(1.0), custom.z);
	COLOR = vec4(rgb, c.a * COLOR.a);
}
