// Passe de luz do fundo (porta do luz_vermelha.frag).
// Lê o que já foi desenhado na tela (o fundo), dessatura e pinta com luz vermelha vinda da direita,
// com raios, pulso e uma luz fria fraca do lado oposto. Desenhe este nó DEPOIS do fundo e ANTES da
// faixa e dos personagens.
shader_type canvas_item;

uniform sampler2D u_scene : hint_screen_texture, filter_linear;
uniform vec2 u_res = vec2(960.0, 540.0);
uniform float u_desat : hint_range(0.0, 1.0) = 1.0;     // 1 = preto e branco total
uniform vec2 u_lightPos = vec2(1.12, 0.40);              // origem da luz (0..1, y de baixo para cima)
uniform float u_intensity : hint_range(0.0, 2.0) = 1.0;
uniform float u_rays : hint_range(0.0, 1.0) = 0.5;
uniform float u_cool : hint_range(0.0, 1.0) = 0.35;
uniform float u_wind : hint_range(0.0, 1.0) = 0.5;

void fragment() {
	vec3 col = texture(u_scene, SCREEN_UV).rgb;
	vec2 v_uv = vec2(UV.x, 1.0 - UV.y);
	float aspect = u_res.x / u_res.y;
	float luma = dot(col, vec3(0.299, 0.587, 0.114));

	// 1) dessaturação + contraste leve
	vec3 g = vec3(luma);
	g = clamp((g - 0.5) * 1.12 + 0.5 - 0.03, 0.0, 1.0);
	col = mix(col, g, u_desat);

	// 2) distância e ângulo até a fonte de luz
	vec2 p = vec2(v_uv.x * aspect, v_uv.y);
	vec2 lp = vec2(u_lightPos.x * aspect, u_lightPos.y);
	vec2 d = p - lp;
	float dist = length(d);
	float pulse = 0.90 + 0.10 * sin(TIME * 1.57 + 0.6) + 0.10 * (u_wind - 0.5);
	float I = u_intensity * pulse;
	float fall = exp(-dist * 1.35);
	float core = exp(-dist * 3.2);

	// 3) tingimento
	vec3 shadowRed = vec3(0.55, 0.05, 0.12);
	vec3 midRed = vec3(1.00, 0.16, 0.26);
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	vec3 tint = mix(shadowRed, midRed, smoothstep(0.0, 0.8, lum));
	col = mix(col, col * tint * 1.55, clamp(fall * 0.95 * I, 0.0, 1.0));

	// 4) brilho (screen) perto da fonte
	vec3 glow = vec3(1.0, 0.12, 0.22) * (core * 0.75 + fall * 0.22) * I;
	col = vec3(1.0) - (vec3(1.0) - col) * (vec3(1.0) - clamp(glow, 0.0, 1.0));

	// 5) raios
	float ang = atan(d.y, -d.x);
	float r1 = 0.5 + 0.5 * sin(ang * 17.0 + TIME * 0.35 + sin(ang * 5.0 + TIME * 0.2) * 1.4);
	float r2 = 0.5 + 0.5 * sin(ang * 31.0 - TIME * 0.27 + 1.3);
	float rays = pow(r1, 5.0) * 0.7 + pow(r2, 7.0) * 0.5;
	rays *= fall * u_rays * I;
	col += vec3(1.0, 0.10, 0.20) * rays * 0.55;

	// 6) luz fria fraca no lado oposto
	float coolF = exp(-length(p - vec2(-0.15 * aspect, 0.30)) * 1.5) * u_cool;
	col = mix(col, col * vec3(0.78, 0.92, 1.18) + vec3(0.00, 0.03, 0.08), clamp(coolF, 0.0, 1.0) * 0.7);

	// 7) vinheta
	vec2 q = v_uv - 0.5;
	col *= 1.0 - dot(q, q) * 0.55;

	COLOR = vec4(clamp(col, 0.0, 1.0), 1.0);
}
