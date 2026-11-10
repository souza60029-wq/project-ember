extends RefCounted

# Mede sprites em pixels para sugerir altura do personagem e alcance dos golpes.
# Considera sprites alinhados pelo centro dos pés (base no meio da imagem).

const CORPO_LARGURA: float = 50.0
const CORPO_ALTURA: float = 120.0


static func _imagem(caminho: String) -> Image:
	if not FileAccess.file_exists(caminho):
		return null
	var img: Image = Image.load_from_file(caminho)
	if img == null or img.is_empty():
		return null
	return img


# Altura em pixels da parte visível do sprite (0 se não der para medir).
static func altura_do_sprite(caminho: String) -> int:
	var img: Image = _imagem(caminho)
	if img == null:
		return 0
	return img.get_used_rect().size.y


# Hitbox sugerida (na escala 1, como o JSON guarda) a partir do sprite de impacto do golpe.
# Vai da frente do corpo até a ponta do sprite. Devolve {} se não conseguir medir.
static func hitbox_sugerida(g: Dictionary, altura_px: int, pasta: String) -> Dictionary:
	var lista: Array = g["frames"]
	if lista.is_empty():
		return {}
	var idx: int = int(g.get("sprite_impacto", -1))
	if idx < 0 or idx >= lista.size():
		idx = lista.size() / 2
	var img: Image = _imagem(pasta + str(lista[idx]))
	if img == null:
		return {}
	var r: Rect2i = img.get_used_rect()
	if r.size.x <= 0 or r.size.y <= 0:
		return {}
	var esc: float = maxf(0.1, float(altura_px) / CORPO_ALTURA)
	var meio: float = float(img.get_width()) * 0.5
	var ponta: float = (float(r.end.x) - meio) / esc
	var frente: float = CORPO_LARGURA * 0.5
	var x0: float = minf(frente, ponta - 10.0)
	var y0: float = (float(r.position.y) - float(img.get_height())) / esc
	return {
		"x": int(x0),
		"y": int(y0),
		"w": maxi(1, int(ponta - x0)),
		"h": maxi(1, int(float(r.size.y) / esc)),
	}
