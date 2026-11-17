extends Control

# Navegador de arquivos do app (usado no iOS), no estilo do app Arquivos do iPhone:
# fundo preto, grade de pastas azuis, busca, e a pasta do app aparece como "Ember"
# (no lugar de "No meu iPhone"). Mostra as pastas e arquivos que o app guarda no aparelho (user://).
# No iOS o app só consegue ler o que está nessa pasta: Arquivos > No meu iPhone > Ember.
# No Android e no desktop o editor usa o explorador de arquivos do sistema.
# Toque numa pasta para abrir; toque nos arquivos para marcar (vários, se permitido) e em "Importar".
# Devolve os caminhos em "escolhido".

signal escolhido(caminhos: PackedStringArray)
signal cancelado

const Sprites = preload("res://engine/nucleo/Sprites.gd")

const RAIZ := "user://"
const VIEW_W := 960.0
const VIEW_H := 540.0
const COR_AZUL := Color(0.04, 0.52, 1.0)
const COR_BUSCA := Color(0.11, 0.11, 0.12)
const COR_TEXTO := Color(1.0, 1.0, 1.0)
const COR_SUAVE := Color(0.6, 0.6, 0.64)
const R_GRADE := Rect2(0.0, 124.0, 960.0, 352.0)
const COLUNAS: int = 5
const CELULA := Vector2(184.0, 176.0)
const IMAGENS := ["png", "webp", "jpg", "jpeg"]
const MAX_MINIATURAS := 60

var _titulo: String = ""
var _extensoes: Array = []
var _varios: bool = false
var _pasta: String = RAIZ
var _itens: Array = []   # {"nome","caminho","pasta":bool,"info":String}
var _marcados: Array = []
var _filtro: String = ""
var _scroll: float = 0.0
var _press_pos: Vector2 = Vector2.ZERO
var _press_scroll: float = 0.0
var _apertando: bool = false
var _arrastou: bool = false
var _campo_busca: LineEdit
var _miniaturas: int = 0


# extensoes: ["png", "jpg"] (minúsculas). inicio: pasta inicial (padrão: a pasta Ember, user://).
func abrir(titulo: String, extensoes: Array, varios: bool, inicio: String = RAIZ) -> void:
	_titulo = titulo
	_extensoes = extensoes
	_varios = varios
	_pasta = inicio if DirAccess.dir_exists_absolute(inicio) else RAIZ
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_campo_busca = LineEdit.new()
	_campo_busca.placeholder_text = "Buscar"
	_campo_busca.position = Vector2(66.0, 76.0)
	_campo_busca.size = Vector2(840.0, 36.0)
	_campo_busca.add_theme_font_size_override("font_size", 22)
	_campo_busca.add_theme_color_override("font_color", COR_TEXTO)
	_campo_busca.add_theme_color_override("font_placeholder_color", COR_SUAVE)
	var vazio := StyleBoxFlat.new()
	vazio.bg_color = Color(0, 0, 0, 0)
	for estado in ["normal", "focus", "read_only"]:
		_campo_busca.add_theme_stylebox_override(estado, vazio)
	_campo_busca.text_changed.connect(_ao_buscar)
	add_child(_campo_busca)
	_listar()


func _ao_buscar(t: String) -> void:
	_filtro = t.strip_edges().to_lower()
	_scroll = 0.0
	_listar()


func _nome_pasta(p: String) -> String:
	if p == RAIZ:
		return "Ember"
	return p.trim_suffix("/").get_file()


func _pai(p: String) -> String:
	var base: String = p.trim_suffix("/").get_base_dir()
	if base == "user:" or base == "user://" or base == "":
		return RAIZ
	return base + "/"


func _contar(caminho: String) -> int:
	var d := DirAccess.open(caminho)
	if d == null:
		return 0
	var n: int = d.get_directories().size()
	for f in d.get_files():
		if _extensoes.has(str(f).get_extension().to_lower()) and not str(f).begins_with("."):
			n += 1
	return n


func _tamanho(caminho: String) -> String:
	var f := FileAccess.open(caminho, FileAccess.READ)
	if f == null:
		return ""
	var b: int = f.get_length()
	f.close()
	if b >= 1048576:
		return "%.1f MB" % (float(b) / 1048576.0)
	return "%d KB" % maxi(1, int(round(float(b) / 1024.0)))


func _listar() -> void:
	_itens = []
	_miniaturas = 0
	var dir := DirAccess.open(_pasta)
	if dir != null:
		var pastas: Array = []
		var arquivos: Array = []
		for d in dir.get_directories():
			var n: String = str(d)
			if not n.begins_with(".") and (_filtro == "" or n.to_lower().contains(_filtro)):
				pastas.append(n)
		for f in dir.get_files():
			var n2: String = str(f)
			if not n2.begins_with(".") and _extensoes.has(n2.get_extension().to_lower()) and (_filtro == "" or n2.to_lower().contains(_filtro)):
				arquivos.append(n2)
		pastas.sort_custom(func(a, b): return str(a).naturalnocasecmp_to(str(b)) < 0)
		arquivos.sort_custom(func(a, b): return str(a).naturalnocasecmp_to(str(b)) < 0)
		for p in pastas:
			var cam: String = _pasta + str(p)
			var n_it: int = _contar(cam + "/")
			_itens.append({"nome": str(p), "caminho": cam + "/", "pasta": true, "info": "%d %s" % [n_it, "item" if n_it == 1 else "itens"]})
		for a in arquivos:
			var cam2: String = _pasta + str(a)
			_itens.append({"nome": str(a), "caminho": cam2, "pasta": false, "info": _tamanho(cam2)})
	_scroll = clampf(_scroll, 0.0, _max_scroll())
	queue_redraw()


func _linhas() -> int:
	return int(ceil(float(_itens.size()) / float(COLUNAS)))


func _max_scroll() -> float:
	return maxf(0.0, float(_linhas()) * CELULA.y - R_GRADE.size.y + 12.0)


func _rect_item(i: int) -> Rect2:
	var col: int = i % COLUNAS
	var lin: int = i / COLUNAS
	var x0: float = (VIEW_W - CELULA.x * float(COLUNAS)) * 0.5
	return Rect2(x0 + float(col) * CELULA.x, R_GRADE.position.y + float(lin) * CELULA.y - _scroll, CELULA.x, CELULA.y)


# ---------- entrada ----------

func _gui_input(ev: InputEvent) -> void:
	var mb := ev as InputEventMouseButton
	if mb != null:
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_scroll = clampf(_scroll - 60.0, 0.0, _max_scroll())
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_scroll = clampf(_scroll + 60.0, 0.0, _max_scroll())
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_apertando = true
				_arrastou = false
				_press_pos = mb.position
				_press_scroll = _scroll
			elif _apertando:
				_apertando = false
				if not _arrastou:
					_tocar(mb.position)
		queue_redraw()
		accept_event()
		return
	var mm := ev as InputEventMouseMotion
	if mm != null and _apertando:
		var dy: float = mm.position.y - _press_pos.y
		if absf(dy) > 10.0:
			_arrastou = true
		if _arrastou and _press_pos.y > R_GRADE.position.y:
			_scroll = clampf(_press_scroll - dy, 0.0, _max_scroll())
		queue_redraw()
		accept_event()


func _rect_voltar() -> Rect2:
	return Rect2(0.0, 0.0, 300.0, 64.0)


func _rect_importar() -> Rect2:
	return Rect2(VIEW_W - 250.0, 480.0, 240.0, 52.0)


func _rect_cancelar() -> Rect2:
	return Rect2(10.0, 480.0, 200.0, 52.0)


func _tocar(p: Vector2) -> void:
	if _rect_voltar().has_point(p):
		if _pasta == RAIZ:
			_cancelar()
		else:
			_pasta = _pai(_pasta)
			_scroll = 0.0
			_listar()
		return
	if p.y >= 478.0:
		if _rect_cancelar().has_point(p):
			_cancelar()
		elif _varios and not _marcados.is_empty() and _rect_importar().has_point(p):
			escolhido.emit(PackedStringArray(_marcados))
			queue_free()
		return
	if R_GRADE.has_point(p):
		for i in range(_itens.size()):
			if _rect_item(i).has_point(p):
				var it: Dictionary = _itens[i]
				if bool(it["pasta"]):
					_pasta = str(it["caminho"])
					_scroll = 0.0
					_listar()
				elif not _varios:
					escolhido.emit(PackedStringArray([str(it["caminho"])]))
					queue_free()
				else:
					var c: String = str(it["caminho"])
					if _marcados.has(c):
						_marcados.erase(c)
					else:
						_marcados.append(c)
				return


func _cancelar() -> void:
	cancelado.emit()
	queue_free()


# ---------- desenho ----------

func _draw() -> void:
	var fonte: Font = ThemeDB.fallback_font
	draw_rect(Rect2(0.0, 0.0, VIEW_W, VIEW_H), Color.BLACK)
	if _itens.is_empty():
		draw_string(fonte, Vector2(0.0, 290.0), "Nenhum item", HORIZONTAL_ALIGNMENT_CENTER, VIEW_W, 26, COR_SUAVE)
		draw_string(fonte, Vector2(0.0, 322.0), "Coloque arquivos pelo app Arquivos: No meu iPhone > Ember", HORIZONTAL_ALIGNMENT_CENTER, VIEW_W, 16, COR_SUAVE)
	for i in range(_itens.size()):
		var r: Rect2 = _rect_item(i)
		if r.end.y < R_GRADE.position.y or r.position.y > R_GRADE.end.y:
			continue
		_desenhar_item(i, r)
	# cabeçalho, busca e barra de baixo por cima da grade
	draw_rect(Rect2(0.0, 0.0, VIEW_W, 120.0), Color.BLACK)
	var voltar: String = "Cancelar" if _pasta == RAIZ else _nome_pasta(_pai(_pasta))
	draw_polyline(PackedVector2Array([Vector2(36.0, 16.0), Vector2(22.0, 32.0), Vector2(36.0, 48.0)]), COR_AZUL, 4.0)
	draw_string(fonte, Vector2(48.0, 42.0), voltar, HORIZONTAL_ALIGNMENT_LEFT, 240.0, 26, COR_AZUL)
	draw_string(fonte, Vector2(0.0, 42.0), _nome_pasta(_pasta), HORIZONTAL_ALIGNMENT_CENTER, VIEW_W, 28, COR_TEXTO)
	if _varios:
		draw_string(fonte, Vector2(VIEW_W - 300.0, 42.0), "%d marcado(s)" % _marcados.size(), HORIZONTAL_ALIGNMENT_RIGHT, 280.0, 20, COR_SUAVE)
	var busca := StyleBoxFlat.new()
	busca.bg_color = COR_BUSCA
	busca.set_corner_radius_all(12)
	draw_style_box(busca, Rect2(14.0, 72.0, 932.0, 44.0))
	draw_arc(Vector2(40.0, 92.0), 9.0, 0.0, TAU, 20, COR_SUAVE, 2.5)
	draw_line(Vector2(47.0, 99.0), Vector2(55.0, 107.0), COR_SUAVE, 2.5)
	draw_rect(Rect2(0.0, 476.0, VIEW_W, 64.0), Color(0.08, 0.08, 0.09))
	draw_line(Vector2(0.0, 476.0), Vector2(VIEW_W, 476.0), Color(1, 1, 1, 0.12), 1.0)
	draw_string(fonte, Vector2(10.0, 515.0), "Cancelar", HORIZONTAL_ALIGNMENT_CENTER, 200.0, 24, COR_SUAVE)
	if _varios:
		var ativo: bool = not _marcados.is_empty()
		var ri: Rect2 = _rect_importar()
		var pilula := StyleBoxFlat.new()
		pilula.bg_color = COR_AZUL if ativo else Color(0.2, 0.2, 0.22)
		pilula.set_corner_radius_all(26)
		draw_style_box(pilula, ri)
		draw_string(fonte, Vector2(ri.position.x, ri.position.y + 34.0), "Importar (%d)" % _marcados.size() if ativo else "Marque os arquivos", HORIZONTAL_ALIGNMENT_CENTER, ri.size.x, 22, Color.WHITE if ativo else COR_SUAVE)
	else:
		draw_string(fonte, Vector2(VIEW_W - 360.0, 515.0), _titulo, HORIZONTAL_ALIGNMENT_RIGHT, 340.0, 20, COR_SUAVE)


func _desenhar_item(i: int, r: Rect2) -> void:
	var fonte: Font = ThemeDB.fallback_font
	var it: Dictionary = _itens[i]
	var marcado: bool = _marcados.has(str(it["caminho"]))
	var centro_x: float = r.position.x + r.size.x * 0.5
	if marcado:
		var sel := StyleBoxFlat.new()
		sel.bg_color = Color(0.04, 0.52, 1.0, 0.28)
		sel.set_corner_radius_all(14)
		draw_style_box(sel, r.grow(-6.0))
	var topo: float = r.position.y + 12.0
	if bool(it["pasta"]):
		_pasta_icone(Vector2(centro_x - 70.0, topo), Vector2(140.0, 100.0))
	else:
		var cartao := Rect2(centro_x - 56.0, topo, 112.0, 100.0)
		draw_rect(cartao, Color(0.96, 0.96, 0.98))
		var ext: String = str(it["nome"]).get_extension().to_lower()
		var tex: Texture2D = null
		if IMAGENS.has(ext) and _miniaturas < MAX_MINIATURAS:
			tex = Sprites.textura(str(it["caminho"]))
			_miniaturas += 1
		if tex != null:
			var ts: Vector2 = tex.get_size()
			var e: float = minf((cartao.size.x - 8.0) / ts.x, (cartao.size.y - 8.0) / ts.y)
			draw_texture_rect(tex, Rect2(cartao.get_center() - ts * e * 0.5, ts * e), false)
		else:
			draw_string(fonte, Vector2(cartao.position.x, cartao.get_center().y + 10.0), ext.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, cartao.size.x, 28, Color(0.3, 0.3, 0.4))
	if marcado:
		draw_circle(Vector2(centro_x + 52.0, topo + 88.0), 14.0, COR_AZUL)
		draw_line(Vector2(centro_x + 45.0, topo + 88.0), Vector2(centro_x + 50.0, topo + 94.0), Color.WHITE, 4.0)
		draw_line(Vector2(centro_x + 50.0, topo + 94.0), Vector2(centro_x + 60.0, topo + 81.0), Color.WHITE, 4.0)
	draw_string(fonte, Vector2(r.position.x + 6.0, topo + 128.0), str(it["nome"]), HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 12.0, 20, COR_TEXTO)
	draw_string(fonte, Vector2(r.position.x + 6.0, topo + 150.0), str(it["info"]), HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 12.0, 16, COR_SUAVE)


# Pasta azul clara, como no app Arquivos.
func _pasta_icone(p: Vector2, t: Vector2) -> void:
	var fundo := StyleBoxFlat.new()
	fundo.bg_color = Color(0.40, 0.58, 0.73)
	fundo.set_corner_radius_all(10)
	draw_style_box(fundo, Rect2(p.x, p.y, t.x * 0.48, 22.0))
	draw_style_box(fundo, Rect2(p.x, p.y + 10.0, t.x, t.y - 10.0))
	var frente := StyleBoxFlat.new()
	frente.bg_color = Color(0.50, 0.76, 0.92)
	frente.set_corner_radius_all(10)
	draw_style_box(frente, Rect2(p.x, p.y + 24.0, t.x, t.y - 24.0))
