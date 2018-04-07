shader_type spatial;
render_mode cull_disabled, depth_test_disable, skip_vertex_transform, world_vertex_coords, unshaded;

uniform sampler2D font_texture : hint_albedo;
uniform vec2 viewport_size;
uniform float clip_factor;
uniform float clip_offset;

varying vec4 frag_color;
varying vec2 frag_uv;

void vertex() {
	
	// (0.0f, window_width_, window_height_, 0.0f, 0.0f, 1.0f);
	// (T left, T right, T bottom, T top, T near, T far)
	
	float left = 0.0;
	float right = 960.0;
	float bottom = 720.0;
	float top = 0.0;
	float near = 0.0;
	float far = 1.0;
	
	float dx = right - left;
	float dy = top - bottom;
	float dz = far - near;
	
	float tx = -(right + left) / dx;
	float ty = -(top + bottom) / dy;
	float tz = -(far + near) / dz;
	
	mat4 proj_mtx = mat4(
		vec4(2.0 / dx, 0.0, 0.0, tx),
		vec4(0.0, 2.0 / dy, 0.0, ty),
		vec4(0.0, 0.0, -2.0 / dz, tz),
		vec4(0.0, 0.0, 0.0, 1.0)
	);
	
	VERTEX = (INV_PROJECTION_MATRIX * vec4(VERTEX, 1.0)).xyz;
	frag_color = COLOR;
	frag_uv = UV;
	
}

// this is kind of awful and it would be nice if there is a better way
bool is_within_clip_rect(vec4 clip_rect, vec2 point) {
	return (point.x >= clip_rect.x && point.x <= clip_rect.z &&
			point.y >= (clip_rect.w - clip_rect.y) / 6.0 && point.y <= clip_rect.w);
}

void fragment() {
	
	vec2 screen_pos = vec2(FRAGCOORD.x, viewport_size.y - FRAGCOORD.y + clip_offset);
	vec4 clip_rect = vec4(NORMAL.x, NORMAL.y, UV2.x, UV2.y);
	if (!is_within_clip_rect(clip_rect, screen_pos)) {
		if (viewport_size.x == clip_rect.z && viewport_size.y == clip_rect.w) {
			ALBEDO = frag_color.rgb * texture(font_texture, frag_uv).rgb;
			ALPHA = frag_color.a * texture(font_texture, frag_uv).a;
		} else {
			ALPHA = 0.0;
		}
	} else {
		ALBEDO = frag_color.rgb * texture(font_texture, frag_uv).rgb;
		ALPHA = frag_color.a * texture(font_texture, frag_uv).a;
	}
	
}