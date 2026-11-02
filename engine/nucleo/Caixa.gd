extends RefCounted

enum Tipo { CORPO, ATAQUE, PUSH }

static func rect_hitbox(hb: Dictionary, pos: Vector2, virado_direita: bool) -> Rect2:
	var x: float = float(hb["x"])
	var w: float = float(hb["w"])
	if not virado_direita:
		x = -x - w
	return Rect2(pos.x + x, pos.y + float(hb["y"]), w, float(hb["h"]))

static func colidem(a: Rect2, b: Rect2) -> bool:
	return a.intersects(b)