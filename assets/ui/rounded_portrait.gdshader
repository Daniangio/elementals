shader_type canvas_item;

uniform float corner_radius = 0.065;
uniform float feather = 0.004;

void fragment() {
	vec2 q = abs(UV - vec2(0.5)) - vec2(0.5 - corner_radius);
	float distance_to_edge = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - corner_radius;
	vec4 color = texture(TEXTURE, UV);
	color.a *= 1.0 - smoothstep(-feather, feather, distance_to_edge);
	COLOR = color;
}
