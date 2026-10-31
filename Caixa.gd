extends RefCounted

var offset_x: float
var offset_y: float
var largura: float
var altura: float

func _init(ox: float, oy: float, w: float, h: float):
	offset_x = ox
	offset_y = oy
	largura = w
	altura = h

# Retorna a posição absoluta da caixa, dado onde o personagem esta parado
func obter_retangulo_absoluto(pos_x: float, pos_y: float, virado_para_direita: bool) -> Rect2:
	var ox = offset_x
	if not virado_para_direita:
		ox = -offset_x - largura  # espelha a caixa se o personagem estiver virado pra esquerda
	return Rect2(pos_x + ox, pos_y + offset_y, largura, altura)

static func colidem(a: Rect2, b: Rect2) -> bool:
	return a.intersects(b)
