shader_type canvas_item;
uniform float radius : hint_range(0.0, 50.0) = 20.0;

void fragment() {
	vec2 s = 1.0 / TEXTURE_PIXEL_SIZE;
	float r = radius;
	vec2 c = UV * s;
	vec2 rc = s - c;

	if (c.x < r && c.y < r && distance(c, vec2(r)) > r) discard;
	if (rc.x < r && c.y < r && distance(vec2(rc.x, c.y), vec2(r)) > r) discard;
	if (c.x < r && rc.y < r && distance(vec2(c.x, rc.y), vec2(r)) > r) discard;
	if (rc.x < r && rc.y < r && distance(vec2(rc.x, rc.y), vec2(r)) > r) discard;
	COLOR = texture(TEXTURE, UV);
}
