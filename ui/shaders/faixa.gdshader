// Faixa carmesim inclinada com borda vermelho-sangue (porta do faixa.frag).
// O tamanho vem dos uniforms, então ela se ajusta aos personagens. Desenhe-a por cima do fundo
// (e do passe de luz) e DEPOIS os personagens.
shader_type canvas_item;
render_mode blend_premul_alpha;

uniform vec2 u_res = vec2(960.0, 540.0);
uniform vec2 u_center = vec2(836.0, 270.0);   // centro da faixa em px (origem no canto superior esquerdo)
uniform vec2 u_half = vec2(150.0, 340.0);     // meia largura e meia altura em px
uniform float u_tilt = 0.14;                  // inclinação em radianos (~8 graus)
uniform float u_border = 21.0;                // espessura da borda em px

float halftone(vec2 p, float pitch, float rad) {
	float c = 0.70710678;
	vec2 q = vec2(p.x * c + p.y * c, -p.x * c + p.y * c) / pitch;
	float dd = length(fract(q) - 0.5);
	return clamp((rad - dd) * pitch + 0.5, 0.0, 1.0);
}

void fragment() {
	vec2 px = UV * u_res;
	vec2 r = px - u_center;
	float ca = cos(u_tilt);
	float sa = sin(u_tilt);
	vec2 l = vec2(r.x * ca + r.y * sa, -r.x * sa + r.y * ca);

	vec2 q = abs(l) - u_half;
	float sd = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0);

	float aa = 1.5;
	float fill = 1.0 - smoothstep(-aa, aa, sd);
	float blood = 1.0 - smoothstep(-aa, aa, sd + u_border);
	float outer = 1.0 - smoothstep(-aa, aa, sd - 7.0);

	float glow = exp(-max(sd, 0.0) / 46.0) * 0.45 + exp(-max(sd, 0.0) / 14.0) * 0.30;

	vec3 CRIM = vec3(0.863, 0.078, 0.235);
	vec3 BLOOD = vec3(0.463, 0.024, 0.071);
	vec3 INK = vec3(0.055, 0.039, 0.071);

	float t = clamp((l.y + u_half.y * 0.1) / (u_half.y * 1.0), 0.0, 1.0);
	float dots = halftone(l, 11.0, 0.06 + 0.42 * t);
	vec3 inner = mix(CRIM, vec3(0.588, 0.031, 0.141), 0.6 * dots);
	float acc = step(abs(l.x + u_half.x - 34.0), 1.8) * step(abs(l.y), u_half.y - 30.0);
	inner = mix(inner, BLOOD, acc);
	inner *= 0.96 + 0.04 * sin(TIME * 1.57);

	vec3 body = mix(BLOOD, inner, blood);
	vec3 col = mix(INK, body, fill);

	float a = max(outer, 0.0);
	vec3 rgb = col * a;
	float ga = glow * (1.0 - outer);
	rgb += vec3(0.92, 0.12, 0.24) * ga;
	a = clamp(a + ga * 0.6, 0.0, 1.0);

	COLOR = vec4(rgb, a);
}
