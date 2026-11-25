shader_type canvas_item;
// Dibuja instancias de un atlas. Por instancia:
//   COLOR (color de instancia) = tinte y alfa
//   INSTANCE_CUSTOM.x = columna (fotograma), .y = fila (sprite), .z = destello blanco 0..1
uniform sampler2D atlas : filter_nearest, repeat_disable;
uniform vec2 grid = vec2(2.0, 4.0); // columnas, filas del atlas
// true en estructuras (blanco y negro): el golpe invierte blanco<->negro en vez de blanquear
uniform bool flash_invert = false;

varying vec4 custom;

void vertex() {
	custom = INSTANCE_CUSTOM;
}

void fragment() {
	vec2 uv = (vec2(UV.x, 1.0 - UV.y) + custom.xy) / grid; // QuadMesh en 2D llega con la V invertida
	vec4 c = texture(atlas, uv);
	vec3 base = c.rgb * COLOR.rgb;
	vec3 rgb = flash_invert ? mix(base, vec3(1.0) - base, step(0.5, custom.z)) : mix(base, vec3(1.0), custom.z);
	COLOR = vec4(rgb, c.a * COLOR.a);
}
