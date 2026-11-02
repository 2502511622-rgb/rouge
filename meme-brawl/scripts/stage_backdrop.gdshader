shader_type canvas_item;
render_mode unshaded;
uniform float stage_clock = 0.0;
uniform float surge = 0.0;
uniform int stage_kind = 0;
void fragment() {
	vec2 uv = UV;
	// Quantized source sampling keeps a stable pixel cluster scale in motion.
	vec2 pixel_grid = vec2(1152.0,648.0);
	if (stage_kind == 3) {
		float water = smoothstep(0.34,0.42,uv.y)*(1.0-smoothstep(0.60,0.67,uv.y));
		float wave = sin(uv.y*170.0+stage_clock*(2.0+surge*9.0));
		uv.x += floor(wave*(0.55+surge*4.0))*water/1152.0;
		uv.y += floor(sin(uv.x*100.0+stage_clock*7.0)*surge*2.0)*water/648.0;
	}
	uv = (floor(uv*pixel_grid)+0.5)/pixel_grid;
	vec4 texel = texture(TEXTURE,uv);
	// Reserve the strongest contrast and brightest color accents for fighters.
	vec3 rgb = mix(vec3(dot(texel.rgb,vec3(0.299,0.587,0.114))),texel.rgb,0.84);
	rgb *= mix(0.87,0.97,smoothstep(0.2,0.85,UV.y));
	COLOR = vec4(rgb,texel.a);
}
