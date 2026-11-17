extends Control

# FERRAMENTA DE DEBUG (pode ser removida: apague a pasta engine/debug/).
# Editor das camadas do menu.
#  - Coluna da esquerda: uma miniatura por camada (a de cima é a que fica na frente).
#    A barrinha de cima sobe a camada selecionada (para a frente); a de baixo desce.
#  - Um dedo move a camada, dois dedos (pinça) mudam o tamanho.
#  - Coluna da direita: olho (prévia sem botões), salvar, resetar, fechar e setas de navegação.
#  - Salvar grava o layout (fica assim nas próximas vezes que abrir o app) e gera
#    Arquivos > No meu iPhone > Ember > debug > layout_menu.txt para você me mandar.

signal fechado

const LayoutDebug = preload("res://engine/debug/LayoutDebug.gd")

const VIEW_W := 960.0
const VIEW_H := 540.0
const COR_SEL := Color(1.0, 0.9, 0.2)
const COR_CAIXA := Color(0.07, 0.06, 0.16, 0.88)
const COR_BORDA := Color(0.55, 0.4, 0.95)
const COR_ICONE := Color(1.0, 1.0, 1.0, 0.95)

const TAM := 52.0          # quadrado de camada
const TAM_DIR := 46.0      # ícones da direita
const GAP := 6.0
const BARRA_H := 16.0
const COL_ESQ := 12.0
const COL_DIR := VIEW_W - 12.0 - TAM_DIR
const Y_LISTA := 64.0
const Y_DIR := 72.0
const ICONES_DIR := ["olho", "salvar", "resetar", "fechar", "menu-", "menu+", "sub-", "sub+"]

var _menu: Variant = null
var _nomes: Array = []          # de trás para frente
var _sel: int = 0
var _dedos := {}
var _dist_antes: float = 0.0
var _msg: String = ""
var _msg_t: float = 0.0
var _toque: bool = false
var _previa: bool = false
var _acao_toque: String = ""
var _toque_pos: Vector2 = Vector2.ZERO
var _arrastou: bool = false


func abrir(menu: Variant) -> void:
	_menu = menu
	_toque = DisplayServer.is_touchscreen_available()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	position = Vector2.ZERO
	size = Vector2(VIEW_W, VIEW_H)
	mouse_filter = Control.MOUSE_FILTER_STOP
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


# ---------- geometria dos controles ----------

func _rect_barra(topo: bool) -> Rect2:
	if topo:
		return Rect2(COL_ESQ, Y_LISTA, TAM, BARRA_H)
	return Rect2(COL_ESQ, Y_LISTA + BARRA_H + GAP + float(_nomes.size()) * (TAM + GAP), TAM, BARRA_H)


func _rect_camada(linha: int) -> Rect2:
	return Rect2(COL_ESQ, Y_LISTA + BARRA_H + GAP + float(linha) * (TAM + GAP), TAM, TAM)


func _rect_icone(i: int) -> Rect2:
	return Rect2(COL_DIR, Y_DIR + float(i) * (TAM_DIR + GAP), TAM_DIR, TAM_DIR)


func _acao_em(p: Vector2) -> String:
	if _previa:
		return "olho" if _rect_icone(0).has_point(p) else ""
	for i in range(ICONES_DIR.size()):
		if _rect_icone(i).has_point(p):
			return str(ICONES_DIR[i])
	if _rect_barra(true).grow(3.0).has_point(p):
		return "frente"
	if _rect_barra(false).grow(3.0).has_point(p):
		return "tras"
	var n: int = _nomes.size()
	for linha in range(n):
		if _rect_camada(linha).has_point(p):
			return "camada:%d" % (n - 1 - linha)
	return ""


# ---------- ações ----------

func _executar(a: String) -> void:
	match a:
		"olho":
			_previa = not _previa
		"salvar":
			_salvar()
		"resetar":
			_resetar()
		"fechar":
			_fechar()
		"menu-":
			_menu.debug_navegar(-1, 0)
		"menu+":
			_menu.debug_navegar(1, 0)
		"sub-":
			_menu.debug_navegar(0, -1)
		"sub+":
			_menu.debug_navegar(0, 1)
		"frente":
			_mudar_ordem(1)
		"tras":
			_mudar_ordem(-1)
		_:
			if a.begins_with("camada:"):
				_sel = clampi(int(a.get_slice(":", 1)), 0, maxi(0, _nomes.size() - 1))


func _mudar_ordem(d: int) -> void:
	var n: String = _nome_sel()
	if n == "":
		return
	_menu.debug_mover_ordem(n, d)
	_atualizar_nomes()


func _resetar() -> void:
	var n: String = _nome_sel()
	if n != "":
		_menu.debug_layout().erase(n)
		_msg = "Camada resetada."
		_msg_t = 1.5


func _retangulos() -> Dictionary:
	var r := {}
	for n in _nomes:
		r[n] = _menu.debug_rect(str(n))
	return r


# Só o que foi mexido (o resto fica no padrão).
func _ajustes_usados() -> Dictionary:
	var r := {}
	var l: Dictionary = _menu.debug_layout()
	for k in l.keys():
		var v: Variant = l[k]
		if typeof(v) != TYPE_DICTIONARY:
			continue
		if absf(float(v.get("x", 0.0))) > 0.01 or absf(float(v.get("y", 0.0))) > 0.01 or absf(float(v.get("esc", 1.0)) - 1.0) > 0.0005:
			r[k] = v
	return r


func _salvar() -> void:
	var erro: String = LayoutDebug.salvar(_ajustes_usados(), _retangulos(), _menu.debug_ordem())
	_msg = "Salvo! Fica assim ao abrir o app. Arquivo em Ember/debug." if erro == "" else erro
	_msg_t = 4.0


func _fechar() -> void:
	fechado.emit()
	queue_free()


# ---------- toques: botões, arrastar e pinçar ----------

# Lê os toques direto da tela (_input), sem depender do tamanho deste Control: o Menu pai pode
# ter tamanho 0 para fins de toque, e aí nenhum _gui_input chega.
func _input(ev: InputEvent) -> void:
	if _toque:
		var t := ev as InputEventScreenTouch
		if t != null:
			if t.pressed:
				_dedos[t.index] = t.position
				if _dedos.size() == 1:
					_acao_toque = _acao_em(t.position)
					_toque_pos = t.position
					_arrastou = false
			else:
				if _dedos.size() == 1 and _acao_toque != "" and not _arrastou and _acao_em(t.position) == _acao_toque:
					_executar(_acao_toque)
				if _dedos.size() <= 1:
					_acao_toque = ""
				_dedos.erase(t.index)
			_dist_antes = 0.0
			get_viewport().set_input_as_handled()
			return
		var d := ev as InputEventScreenDrag
		if d != null:
			_dedos[d.index] = d.position
			if _acao_toque != "":
				if d.position.distance_to(_toque_pos) > 14.0:
					_arrastou = true
				get_viewport().set_input_as_handled()
				return
			if _previa:
				get_viewport().set_input_as_handled()
				return
			var n: String = _nome_sel()
			if n != "":
				if _dedos.size() >= 2:
					var ks: Array = _dedos.keys()
					var dist: float = (_dedos[ks[0]] as Vector2).distance_to(_dedos[ks[1]])
					if _dist_antes > 4.0 and dist > 4.0:
						var a: Dictionary = _ajuste(n)
						a["esc"] = clampf(float(a["esc"]) * dist / _dist_antes, 0.05, 8.0)
					_dist_antes = dist
				else:
					_mover(n, d.relative)
			get_viewport().set_input_as_handled()
		return
	# mouse (computador)
	var mb := ev as InputEventMouseButton
	if mb != null:
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_acao_toque = _acao_em(mb.position)
				_toque_pos = mb.position
				_arrastou = false
			else:
				if _acao_toque != "" and not _arrastou and _acao_em(mb.position) == _acao_toque:
					_executar(_acao_toque)
				_acao_toque = ""
			get_viewport().set_input_as_handled()
		elif mb.pressed and not _previa and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			var nn: String = _nome_sel()
			if nn != "":
				var aa: Dictionary = _ajuste(nn)
				aa["esc"] = clampf(float(aa["esc"]) + (0.03 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else -0.03), 0.05, 8.0)
			get_viewport().set_input_as_handled()
		return
	var mm := ev as InputEventMouseMotion
	if mm != null and (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		if _acao_toque != "":
			if mm.position.distance_to(_toque_pos) > 14.0:
				_arrastou = true
		elif not _previa:
			var n2: String = _nome_sel()
			if n2 != "":
				_mover(n2, mm.relative)
		get_viewport().set_input_as_handled()


func _mover(nome: String, rel: Vector2) -> void:
	var a: Dictionary = _ajuste(nome)
	a["x"] = float(a["x"]) + rel.x
	a["y"] = float(a["y"]) + rel.y


# ---------- desenho ----------

func _caixa(r: Rect2, fundo: Color, borda: Color, raio: int, larg: int) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fundo
	sb.border_color = borda
	sb.set_border_width_all(larg)
	sb.set_corner_radius_all(raio)
	draw_style_box(sb, r)


func _icone(nome: String, c: Vector2, cor: Color) -> void:
	match nome:
		"olho":
			draw_polyline(PackedVector2Array([c + Vector2(-17, 0), c + Vector2(-9, -8), c + Vector2(0, -11), c + Vector2(9, -8), c + Vector2(17, 0)]), cor, 2.5)
			draw_polyline(PackedVector2Array([c + Vector2(-17, 0), c + Vector2(-9, 8), c + Vector2(0, 11), c + Vector2(9, 8), c + Vector2(17, 0)]), cor, 2.5)
			draw_circle(c, 5.0, cor)
		"salvar":
			draw_rect(Rect2(c + Vector2(-14, -14), Vector2(28, 28)), cor, false, 2.5)
			draw_rect(Rect2(c + Vector2(-7, -14), Vector2(14, 8)), cor, false, 2.0)
			draw_rect(Rect2(c + Vector2(-8, 3), Vector2(16, 11)), cor, false, 2.0)
		"resetar":
			draw_arc(c, 13.0, -0.3, PI * 1.55, 24, cor, 2.5)
			var fim: Vector2 = c + Vector2(cos(PI * 1.55), sin(PI * 1.55)) * 13.0
			draw_polyline(PackedVector2Array([fim + Vector2(-7, 1), fim, fim + Vector2(2, 8)]), cor, 2.5)
		"fechar":
			draw_line(c + Vector2(-11, -11), c + Vector2(11, 11), cor, 3.0)
			draw_line(c + Vector2(11, -11), c + Vector2(-11, 11), cor, 3.0)
		"menu-":
			for o in [-5.0, 5.0]:
				draw_polyline(PackedVector2Array([c + Vector2(o + 4, -10), c + Vector2(o - 4, 0), c + Vector2(o + 4, 10)]), cor, 2.5)
		"menu+":
			for o in [-5.0, 5.0]:
				draw_polyline(PackedVector2Array([c + Vector2(o - 4, -10), c + Vector2(o + 4, 0), c + Vector2(o - 4, 10)]), cor, 2.5)
		"sub-":
			draw_polyline(PackedVector2Array([c + Vector2(-10, 5), c + Vector2(0, -5), c + Vector2(10, 5)]), cor, 2.5)
		"sub+":
			draw_polyline(PackedVector2Array([c + Vector2(-10, -5), c + Vector2(0, 5), c + Vector2(10, -5)]), cor, 2.5)
		"frente":
			draw_polyline(PackedVector2Array([c + Vector2(-8, 3), c + Vector2(0, -3), c + Vector2(8, 3)]), cor, 2.0)
		"tras":
			draw_polyline(PackedVector2Array([c + Vector2(-8, -3), c + Vector2(0, 3), c + Vector2(8, -3)]), cor, 2.0)


func _draw() -> void:
	if _previa:
		var r0: Rect2 = _rect_icone(0)
		_caixa(r0, COR_CAIXA, COR_SEL, 12, 2)
		_icone("olho", r0.get_center(), COR_SEL)
		return
	var nome_sel: String = _nome_sel()
	if nome_sel != "":
		draw_rect(_menu.debug_rect(nome_sel), COR_SEL, false, 3.0)
	# barras de ordem
	for topo in [true, false]:
		var rb: Rect2 = _rect_barra(topo)
		_caixa(rb, COR_CAIXA, COR_BORDA, 8, 2)
		_icone("frente" if topo else "tras", rb.get_center(), COR_ICONE)
	# camadas (a da frente fica no topo)
	var n: int = _nomes.size()
	for linha in range(n):
		var i: int = n - 1 - linha
		var r: Rect2 = _rect_camada(linha)
		var sel: bool = i == _sel
		_caixa(r, COR_CAIXA, COR_SEL if sel else COR_BORDA, 10, 3 if sel else 2)
		var tex: Texture2D = _menu.debug_textura(str(_nomes[i]))
		if tex != null:
			var ts: Vector2 = tex.get_size()
			var e: float = minf((TAM - 10.0) / maxf(ts.x, 1.0), (TAM - 10.0) / maxf(ts.y, 1.0))
			draw_texture_rect(tex, Rect2(r.get_center() - ts * e * 0.5, ts * e), false)
	# ícones da direita
	for i in range(ICONES_DIR.size()):
		var ri: Rect2 = _rect_icone(i)
		_caixa(ri, COR_CAIXA, COR_BORDA, 12, 2)
		_icone(str(ICONES_DIR[i]), ri.get_center(), COR_ICONE)
	var fonte: Font = ThemeDB.fallback_font
	if nome_sel != "":
		var a: Dictionary = _ajuste(nome_sel)
		var info: String = "%s   x %.0f   y %.0f   tamanho %.2f" % [nome_sel, float(a["x"]), float(a["y"]), float(a["esc"])]
		draw_string(fonte, Vector2(0.0, VIEW_H - 10.0), info, HORIZONTAL_ALIGNMENT_CENTER, VIEW_W, 14, COR_SEL)
	if _msg_t > 0.0:
		draw_string(fonte, Vector2(0.0, 30.0), _msg, HORIZONTAL_ALIGNMENT_CENTER, VIEW_W, 16, COR_SEL)