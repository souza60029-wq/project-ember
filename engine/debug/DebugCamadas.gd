extends Control

# FERRAMENTA DE DEBUG (pode ser removida: apague a pasta engine/debug/).
# Editor das camadas do menu: mostra TODAS as camadas com moldura, e você arrasta (um dedo) e
# aumenta/diminui (dois dedos, ou os botões - e +) cada uma. Salvar aplica na tela inicial e grava
# user://debug/layout_menu.txt (Arquivos > No meu iPhone > Ember > debug) para você me mandar.

signal fechado

const LayoutDebug = preload("res://engine/debug/LayoutDebug.gd")

const VIEW_W := 960.0
const VIEW_H := 540.0
const COR_SEL := Color(1.0, 0.9, 0.2)
const COR_OUTRAS := Color(0.5, 0.9, 1.0, 0.55)

var _menu: Variant = null
var _nomes: Array = []
var _sel: int = 0
var _dedos := {}
var _dist_antes: float = 0.0
var _msg: String = ""
var _msg_t: float = 0.0
var _toque: bool = false


func abrir(menu: Variant) -> void:
	_menu = menu
	_toque = DisplayServer.is_touchscreen_available()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_montar_botoes()
	_atualizar_nomes()


func _process(delta: float) -> void:
	if _msg_t > 0.0:
		_msg_t -= delta
	_atualizar_nomes()
	queue_redraw()


func _atualizar_nomes() -> void:
	var antes: String = _nome_sel()
	_nomes = _menu.debug_camadas()
	var i: int = _nomes.find(antes)
	_sel = i if i >= 0 else clampi(_sel, 0, maxi(0, _nomes.size() - 1))


func _nome_sel() -> String:
	if _nomes.is_empty() or _sel >= _nomes.size():
		return ""
	return str(_nomes[_sel])


func _ajuste(nome: String) -> Dictionary:
	var l: Dictionary = _menu.debug_layout()
	if not l.has(nome):
		l[nome] = {"x": 0.0, "y": 0.0, "esc": 1.0}
	return l[nome]


func _botao(texto: String, r: Rect2, acao: Callable) -> void:
	var b := Button.new()
	b.text = texto
	b.position = r.position
	b.size = r.size
	b.add_theme_font_size_override("font_size", 18)
	for par in [["normal", Color(0.12, 0.1, 0.28, 0.92)], ["hover", Color(0.2, 0.15, 0.42, 0.95)], ["pressed", Color(0.35, 0.25, 0.7, 0.95)]]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = par[1]
		sb.border_color = Color(0.55, 0.4, 0.95)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(8)
		b.add_theme_stylebox_override(str(par[0]), sb)
	b.pressed.connect(acao)
	add_child(b)


func _montar_botoes() -> void:
	var w: float = 122.0
	var y1: float = 410.0
	var y2: float = 466.0
	var g: float = 6.0
	var linha1: Array = [["< Camada", _camada.bind(-1)], ["Camada >", _camada.bind(1)], ["Tamanho -", _escala.bind(-0.02)], ["Tamanho +", _escala.bind(0.02)], ["Resetar", _resetar]]
	for i in range(linha1.size()):
		_botao(str(linha1[i][0]), Rect2(10.0 + float(i) * (w + g), y1, w, 48.0), linha1[i][1])
	var linha2: Array = [["< Menu", _navegar.bind(-1, 0)], ["Menu >", _navegar.bind(1, 0)], ["^ Sub", _navegar.bind(0, -1)], ["v Sub", _navegar.bind(0, 1)], ["Salvar", _salvar], ["Copiar txt", _copiar], ["Fechar", _fechar]]
	for i in range(linha2.size()):
		_botao(str(linha2[i][0]), Rect2(10.0 + float(i) * (w + g), y2, w, 56.0), linha2[i][1])


func _camada(d: int) -> void:
	if _nomes.is_empty():
		return
	_sel = posmod(_sel + d, _nomes.size())


func _escala(d: float) -> void:
	var n: String = _nome_sel()
	if n == "":
		return
	var a: Dictionary = _ajuste(n)
	a["esc"] = clampf(float(a["esc"]) + d, 0.05, 8.0)


func _resetar() -> void:
	var n: String = _nome_sel()
	if n != "":
		_menu.debug_layout().erase(n)


func _navegar(da: int, ds: int) -> void:
	_menu.debug_navegar(da, ds)


func _retangulos() -> Dictionary:
	var r := {}
	for n in _nomes:
		r[n] = _menu.debug_rect(str(n))
	return r


func _salvar() -> void:
	var erro: String = LayoutDebug.salvar(_menu.debug_layout(), _retangulos())
	_msg = "Salvo e aplicado. Arquivo: Ember/debug/layout_menu.txt" if erro == "" else erro
	_msg_t = 4.0


func _copiar() -> void:
	DisplayServer.clipboard_set(LayoutDebug.texto(_menu.debug_layout(), _retangulos()))
	_msg = "Texto copiado. Cole numa mensagem para me mandar."
	_msg_t = 3.0


func _fechar() -> void:
	fechado.emit()
	queue_free()


# ---------- arrastar e pinçar ----------

func _gui_input(ev: InputEvent) -> void:
	var n: String = _nome_sel()
	if n == "":
		return
	if _toque:
		var t := ev as InputEventScreenTouch
		if t != null:
			if t.pressed:
				_dedos[t.index] = t.position
			else:
				_dedos.erase(t.index)
			_dist_antes = 0.0
			accept_event()
			return
		var d := ev as InputEventScreenDrag
		if d != null:
			_dedos[d.index] = d.position
			if _dedos.size() >= 2:
				var ks: Array = _dedos.keys()
				var dist: float = (_dedos[ks[0]] as Vector2).distance_to(_dedos[ks[1]])
				if _dist_antes > 4.0 and dist > 4.0:
					var a: Dictionary = _ajuste(n)
					a["esc"] = clampf(float(a["esc"]) * dist / _dist_antes, 0.05, 8.0)
				_dist_antes = dist
			else:
				_mover(n, d.relative)
			accept_event()
		return
	var mb := ev as InputEventMouseButton
	if mb != null and mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		_escala(0.03 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else -0.03)
		accept_event()
		return
	var mm := ev as InputEventMouseMotion
	if mm != null and (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		_mover(n, mm.relative)
		accept_event()


func _mover(nome: String, rel: Vector2) -> void:
	var a: Dictionary = _ajuste(nome)
	a["x"] = float(a["x"]) + rel.x
	a["y"] = float(a["y"]) + rel.y


# ---------- desenho ----------

func _draw() -> void:
	var fonte: Font = ThemeDB.fallback_font
	for i in range(_nomes.size()):
		var nome: String = str(_nomes[i])
		var r: Rect2 = _menu.debug_rect(nome)
		var sel: bool = i == _sel
		draw_rect(r, COR_SEL if sel else COR_OUTRAS, false, 4.0 if sel else 1.5)
		draw_string(fonte, r.position + Vector2(6.0, 18.0 + float(i % 4) * 14.0), nome, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, COR_SEL if sel else COR_OUTRAS)
		if sel:
			for c in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
				draw_rect(Rect2(c - Vector2(8.0, 8.0), Vector2(16.0, 16.0)), COR_SEL)
	draw_rect(Rect2(0.0, 402.0, VIEW_W, 138.0), Color(0.0, 0.0, 0.0, 0.7))
	var n: String = _nome_sel()
	var info: String = "(nenhuma camada: coloque artes em ui/menu/)"
	if n != "":
		var a: Dictionary = _ajuste(n)
		var r2: Rect2 = _menu.debug_rect(n)
		info = "%s   x=%.0f  y=%.0f  tamanho x%.2f   (%.0f x %.0f px)" % [n, float(a["x"]), float(a["y"]), float(a["esc"]), r2.size.x, r2.size.y]
	draw_string(fonte, Vector2(10.0, 396.0), info, HORIZONTAL_ALIGNMENT_LEFT, VIEW_W - 20.0, 16, COR_SEL)
	if _msg_t > 0.0:
		draw_string(fonte, Vector2(10.0, 24.0), _msg, HORIZONTAL_ALIGNMENT_LEFT, VIEW_W - 20.0, 18, Color(0.6, 1.0, 0.6))
	draw_string(fonte, Vector2(10.0, 44.0), "1 dedo: mover   2 dedos: tamanho   DEBUG: apague engine/debug/ na versao final", HORIZONTAL_ALIGNMENT_LEFT, VIEW_W - 20.0, 12, Color(1.0, 1.0, 1.0, 0.7))
