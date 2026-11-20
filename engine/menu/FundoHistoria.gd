extends Control

# Fundo animado do menu: base + 7 camadas em folhas de sprites (ui/fundo_historia/*.webp).
# Todas as sequências duram 4 s e fecham o loop. Desenha em coordenadas de 960x540.
# Ordem (de trás para a frente): base, nuvens, raios, neblina do fundo, bandeira, poste, corrente,
# partículas, neblina da frente. Gerado por ferramentas/gerar_atlas_fundo.py.

const PASTA := "res://ui/fundo_historia/"
const VIEW := Rect2(0.0, 0.0, 960.0, 540.0)
const LOOP := 4.0

# arquivo, colunas na folha, quadros, tamanho do quadro, destino na tela
const CAMADAS := [
	{"arq": "nuvens", "cols": 12, "n": 48, "q": Vector2(320, 180), "dest": Rect2(0, 0, 960, 540)},
	{"arq": "raios", "cols": 25, "n": 48, "q": Vector2(160, 90), "dest": Rect2(0, 0, 960, 540)},
	{"arq": "neblina_fundo", "cols": 12, "n": 48, "q": Vector2(320, 180), "dest": Rect2(0, 0, 960, 540)},
	{"arq": "bandeira", "cols": 24, "n": 96, "q": Vector2(168, 379), "dest": Rect2(792, 0, 168, 379)},
	{"arq": "poste", "n": 0, "dest": Rect2(0, 0, 960, 540)},
	{"arq": "corrente", "cols": 12, "n": 48, "q": Vector2(333, 373), "dest": Rect2(0, 109, 333, 373)},
	{"arq": "particulas", "cols": 8, "n": 48, "q": Vector2(480, 270), "dest": Rect2(0, 0, 960, 540)},
	{"arq": "neblina_frente", "cols": 12, "n": 48, "q": Vector2(320, 180), "dest": Rect2(0, 0, 960, 540)},
]

var _base: Texture2D = null
var _texturas := {}
var _t: float = 0.0


func _ready() -> void:
	position = Vector2.ZERO
	size = Vector2(960.0, 540.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_base = _carregar("base")
	for c in CAMADAS:
		_texturas[str(c["arq"])] = _carregar(str(c["arq"]))


func existe() -> bool:
	return _base != null


func _carregar(nome: String) -> Texture2D:
	var caminho: String = PASTA + nome + ".webp"
	if ResourceLoader.exists(caminho):
		return load(caminho) as Texture2D
	return null


func _process(delta: float) -> void:
	_t = fposmod(_t + delta, LOOP)
	queue_redraw()


func _draw() -> void:
	if _base == null:
		return
	draw_texture_rect(_base, VIEW, false)
	for c in CAMADAS:
		var tex: Texture2D = _texturas.get(str(c["arq"]))
		if tex == null:
			continue
		var n: int = int(c["n"])
		if n <= 0:
			draw_texture_rect(tex, c["dest"], false)
			continue
		var i: int = int(_t / LOOP * float(n)) % n
		var cols: int = int(c["cols"])
		var q: Vector2 = c["q"]
		# recorta 0,5 px de cada lado para o filtro linear não pegar o quadro vizinho
		var src := Rect2(float(i % cols) * q.x + 0.5, float(i / cols) * q.y + 0.5, q.x - 1.0, q.y - 1.0)
		draw_texture_rect_region(tex, c["dest"], src)
