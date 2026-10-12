// Comic look for every 3D model: flat light in three bands, halftone dots in
// the shadows, and two extras the kitchen switches per object:
// - muted: background things fade toward the paper colour, so the eye goes
//   to the "main actors" (like the backgrounds in comics and anime);
// - pop: things that need attention get extra saturation and a pulsing
//   misprinted rim (magenta on one side, cyan on the other).
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, hint_default_white;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform vec4 tint : source_color = vec4(1.0);
uniform float muted : hint_range(0.0, 1.0) = 0.0;
uniform float pop : hint_range(0.0, 1.0) = 0.0;
uniform vec3 light_dir = vec3(-0.45, 0.85, 0.5);
uniform vec4 shadow_color : source_color = vec4(0.36, 0.30, 0.58, 1.0);
uniform vec4 paper : source_color = vec4(0.97, 0.93, 0.85, 1.0);
uniform float halftone_size = 5.0;

varying vec3 world_normal;

void vertex() {
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec4 base = texture(albedo_texture, UV) * albedo_color * tint;
	vec3 n = normalize(world_normal);
	float ndl = dot(n, normalize(light_dir));
	float lit = ndl > 0.3 ? 1.0 : (ndl > -0.2 ? 0.74 : 0.52);
	vec3 col = base.rgb * mix(shadow_color.rgb, vec3(1.0), lit);
	// Halftone dots, bigger where it's darker.
	vec2 cell = fract(FRAGCOORD.xy / halftone_size) - 0.5;
	float dots = step(length(cell), (1.0 - lit) * 0.75);
	col = mix(col, col * 0.72, dots);
	float gray = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, mix(vec3(gray), paper.rgb, 0.5), muted * 0.7);
	if (pop > 0.0) {
		col = mix(vec3(gray), col, 1.0 + 0.4 * pop);
		vec3 view_n = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
		float rim = pow(1.0 - clamp(view_n.z, 0.0, 1.0), 1.6);
		vec3 ink = view_n.x > 0.0 ? vec3(1.0, 0.16, 0.66) : vec3(0.1, 0.86, 1.0);
		col = mix(col, ink, pop * rim * (0.75 + 0.25 * sin(TIME * 7.0)));
	}
	ALBEDO = clamp(col, 0.0, 1.0);
}
