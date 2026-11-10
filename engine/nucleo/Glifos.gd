extends RefCounted

# Ícones de botão de controle para as dicas de tela (só aparecem no modo controle).
# Imagem própria opcional em res://ui/glifos/<estilo>_<tipo>.png (estilo: xbox ou ps).
# Tipos: A, B, X, Y, START, LB, RB, DPAD, DPAD_LR.

const PASTA := "res://ui/glifos/"

const COR_XBOX := {"A": Color(0.3, 0.75, 0.3), "B": Color(0.85, 0.25, 0.25), "X": Color(0.25, 0.5, 0.9), "Y": Color(0.9, 0.75, 0.2)}
const COR_PS := {"A": Color(0.55, 0.7, 0.95), "B": Color(0.95, 0.45, 0.5), "X": Color(0.9, 0.6, 0.85), "Y": Color(0.4, 0.85, 0.7)}


static func desenhar(c: CanvasItem, tipo: String, centro: Vector2, raio: float, ps: bool) -> void:
	var caminho: String = PASTA + ("ps_" if ps else "xbox_") + tipo + ".png"
	if ResourceLoader.exists(caminho):
		var tex: Texture2D = load(caminho) as Texture2D
		if tex != null:
			c.draw_texture_rect(tex, Rect2(centro - Vector2(raio, raio), Vector2(raio, raio) * 2.0), false)
			return
	match tipo:
		"A", "B", "X", "Y":
			_face(c, tipo, centro, raio, ps)
		"START":
			_pilula(c, centro, raio, "START")
		"LB":
			_pilula(c, centro, raio, "L1" if ps else "LB")
		"RB":
			_pilula(c, centro, raio, "R1" if ps else "RB")
		"DPAD", "DPAD_LR":
			_direcional(c, centro, raio, tipo == "DPAD_LR")


static func _face(c: CanvasItem, tipo: String, p: Vector2, r: float, ps: bool) -> void:
	var cores: Dictionary = COR_PS if ps else COR_XBOX
	var cor: Color = cores[tipo]
	c.draw_circle(p, r, Color(0.08, 0.08, 0.12, 0.9))
	c.draw_arc(p, r, 0.0, TAU, 24, cor, 2.0)
	if not ps:
		c.draw_string(ThemeDB.fallback_font, p + Vector2(-r, r * 0.38), tipo, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, int(r * 1.2), cor)
		return
	var k: float = r * 0.45
	match tipo:
		"A":
			c.draw_line(p + Vector2(-k, -k), p + Vector2(k, k), cor, 2.0)
			c.draw_line(p + Vector2(-k, k), p + Vector2(k, -k), cor, 2.0)
		"B":
			c.draw_arc(p, k, 0.0, TAU, 20, cor, 2.0)
		"X":
			c.draw_rect(Rect2(p - Vector2(k, k), Vector2(k, k) * 2.0), cor, false, 2.0)
		"Y":
			var tri := PackedVector2Array([p + Vector2(0, -k), p + Vector2(k, k), p + Vector2(-k, k), p + Vector2(0, -k)])
			c.draw_polyline(tri, cor, 2.0)


static func _pilula(c: CanvasItem, p: Vector2, r: float, texto: String) -> void:
	var w: float = r * (2.0 + 0.5 * texto.length())
	var rect := Rect2(p.x - w * 0.5, p.y - r * 0.8, w, r * 1.6)
	c.draw_rect(rect, Color(0.08, 0.08, 0.12, 0.9))
	c.draw_rect(rect, Color(1, 1, 1, 0.8), false, 1.5)
	c.draw_string(ThemeDB.fallback_font, Vector2(rect.position.x, p.y + r * 0.35), texto, HORIZONTAL_ALIGNMENT_CENTER, w, int(r * 1.0), Color.WHITE)


static func _direcional(c: CanvasItem, p: Vector2, r: float, so_lados: bool) -> void:
	c.draw_circle(p, r, Color(0.08, 0.08, 0.12, 0.9))
	var cor := Color(1, 1, 1, 0.9)
	var k: float = r * 0.28
	c.draw_rect(Rect2(p.x - r * 0.7, p.y - k * 0.5, r * 1.4, k), cor)
	if not so_lados:
		c.draw_rect(Rect2(p.x - k * 0.5, p.y - r * 0.7, k, r * 1.4), cor)
