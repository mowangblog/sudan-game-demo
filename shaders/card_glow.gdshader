shader_type canvas_item;
// Card Quality Glow — 卡牌品质辉光
// 在卡牌边缘产生呼吸式金色光晕，品质越高越明显
// Renderer: Forward+ / Mobile / Compatibility 均可

// 辉光颜色（外部按品质设置金色偏移）
uniform vec4 glow_color : source_color = vec4(0.78, 0.66, 0.31, 1.0);
// 呼吸速度
uniform float breath_speed : hint_range(0.1, 2.0) = 0.6;
// 辉光强度系数
uniform float glow_intensity : hint_range(0.0, 1.0) = 0.5;
// 辉光扩散范围（UV空间）
uniform float glow_width : hint_range(0.05, 0.4) = 0.18;

void fragment() {
	vec4 base = texture(TEXTURE, UV);

	// 计算当前像素到四边的归一化距离
	float dist_left = UV.x;
	float dist_right = 1.0 - UV.x;
	float dist_top = UV.y;
	float dist_bottom = 1.0 - UV.y;
	float edge_dist = min(min(dist_left, dist_right), min(dist_top, dist_bottom));

	// 只在边缘范围内产生辉光
	float glow_factor = 1.0 - smoothstep(0.0, glow_width, edge_dist);

	// 呼吸动画：sin 在 0.6~1.0 间波动，避免完全消失
	float breath = 0.6 + 0.4 * sin(TIME * breath_speed);

	// 辉光 alpha：边缘衰减 × 呼吸 × 强度 × 原图透明度（只在有内容处辉光）
	float glow_alpha = glow_factor * breath * glow_intensity * base.a;

	// 叠加辉光
	COLOR = base + glow_color * glow_alpha;
}
