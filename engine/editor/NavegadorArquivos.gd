extends Control

# Navegador de arquivos do app (usado no iOS), parecido com o app Arquivos:
# mostra pastas e arquivos da pasta do app no aparelho (user://), com botões grandes.
# No iOS o app só lê o que está na própria pasta: Arquivos > No meu iPhone > Ember > importar.
# No Android e no desktop o editor usa o explorador de arquivos do sistema.
# Escolher: toque numa pasta para abrir; toque nos arquivos para marcar (vários, se permitido);
# depois "Importar". Devolve os caminhos em "escolhido".

signal escolhido(caminhos: PackedStringArray)
signal cancelado

const Sprites = preload("res://engine/nucleo/Sprites.gd")

const RAIZ := "user://"
const COR_FUNDO := Color(0.04, 0.05, 0.1, 0.98)
const COR_DESTAQUE := Color(1.0, 0.55, 0.2)
const ALT_LINHA := 68.0
const MAX_MINIATURAS := 60
const IMAGENS := ["png", "webp", "jpg", "jpeg"]

var _titulo: String = ""
var _extensoes: Array = []
var _varios: bool = false
var _pasta: String = "user://importar/"
var _marcados: Array = []
var _lbl_caminho: Label
var _lista: VBoxContainer
var _btn_ok: Button
var _btn_cima: Button
var _miniaturas: int = 0


# extensoes: ["png", "jpg"] (minúsculas). inicio: pasta inicial (padrão user://importar/).
func abrir(titulo: String, extensoes: Array, varios: bool, inicio: String = "user://importar/") -> void:
	_titulo = titulo
	_extensoes = extensoes
	_varios = varios
	_pasta = inicio if DirAccess.dir_exists_absolute(inicio) else RAIZ
	_montar()
	_listar()


func _estilo(cor: Color, borda: Color = Color(1, 1, 1, 0.25)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = cor
	sb.border_color = borda
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 16.0
	sb.content_margin_right = 16.0
	return sb


func _botao(texto: String, tam: Vector2, acao: Callable) -> Button:
	var b := Button.new()
	b.text = texto
	b.custom_minimum_size = tam
	b.add_theme_font_size_override("font_size", 22)
	for par in [["normal", Color(0.14, 0.12, 0.3)], ["hover", Color(0.2, 0.16, 0.42)], ["pressed", Color(0.3, 0.2, 0.6)], ["disabled", Color(0.09, 0.08, 0.18)]]:
		b.add_theme_stylebox_override(str(par[0]), _estilo(par[1], Color(0.55, 0.4, 0.95)))
	b.pressed.connect(acao)
	return b


func _montar() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var fundo := ColorRect.new()
	fundo.color = COR_FUNDO
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fundo)
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	for lado in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		m.add_theme_constant_override(lado, 14)
	add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	m.add_child(v)

	var topo := HBoxContainer.new()
	v.add_child(topo)
	_btn_cima = _botao("< Voltar", Vector2(150, 56), _subir)
	topo.add_child(_btn_cima)
	var t := Label.new()
	t.text = _titulo
	t.add_theme_font_size_override("font_size", 26)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	topo.add_child(t)
	topo.add_child(_botao("Cancelar", Vector2(150, 56), _cancelar))

	_lbl_caminho = Label.new()
	_lbl_caminho.add_theme_font_size_override("font_size", 16)
	_lbl_caminho.add_theme_color_override("font_color", Color(0.7, 0.72, 0.9))
	_lbl_caminho.clip_text = true
	v.add_child(_lbl_caminho)

	var rol := ScrollContainer.new()
	rol.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rol.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rol.scroll_deadzone = 12
	v.add_child(rol)
	_lista = VBoxContainer.new()
	_lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lista.add_theme_constant_override("separation", 6)
	rol.add_child(_lista)

	_btn_ok = _botao("Importar", Vector2(0, 60), _confirmar)
	_btn_ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(_btn_ok)


func _nome_da_pasta(p: String) -> String:
	var limpo: String = p.trim_suffix("/")
	return limpo.get_file() if limpo != "user:" else "Ember"


func _listar() -> void:
	for c in _lista.get_children():
		_lista.remove_child(c)
		c.queue_free()
	_miniaturas = 0
	_lbl_caminho.text = "Ember / " + _pasta.trim_prefix(RAIZ).trim_suffix("/").replace("/", " / ")
	_btn_cima.disabled = _pasta == RAIZ
	var dir := DirAccess.open(_pasta)
	var pastas: Array = []
	var arquivos: Array = []
	if dir != null:
		for d in dir.get_directories():
			if not str(d).begins_with("."):
				pastas.append(str(d))
		for f in dir.get_files():
			var nome: String = str(f)
			if not nome.begins_with(".") and _extensoes.has(nome.get_extension().to_lower()):
				arquivos.append(nome)
	pastas.sort_custom(func(a, b): return str(a).naturalnocasecmp_to(str(b)) < 0)
	arquivos.sort_custom(func(a, b): return str(a).naturalnocasecmp_to(str(b)) < 0)
	for p in pastas:
		_lista.add_child(_linha(str(p), true))
	for a in arquivos:
		_lista.add_child(_linha(str(a), false))
	if pastas.is_empty() and arquivos.is_empty():
		var vazio := Label.new()
		vazio.text = "Pasta vazia.\nColoque arquivos nesta pasta pelo app Arquivos:\nNo meu iPhone > Ember > importar."
		vazio.add_theme_font_size_override("font_size", 20)
		vazio.add_theme_color_override("font_color", Color(1.0, 0.8, 0.5))
		vazio.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vazio.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_lista.add_child(vazio)
	_atualizar_ok()


func _linha(nome: String, pasta: bool) -> Button:
	var caminho: String = _pasta + nome
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, ALT_LINHA)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.text = "                " + nome
	b.clip_text = true
	b.add_theme_font_size_override("font_size", 22)
	var marcado: bool = _marcados.has(caminho)
	var normal: Color = Color(0.2, 0.14, 0.08) if marcado else Color(0.09, 0.1, 0.18)
	b.add_theme_stylebox_override("normal", _estilo(normal, COR_DESTAQUE if marcado else Color(1, 1, 1, 0.15)))
	b.add_theme_stylebox_override("hover", _estilo(normal.lightened(0.1)))
	b.add_theme_stylebox_override("pressed", _estilo(normal.lightened(0.2)))
	var icone := Control.new()
	icone.set_anchors_preset(Control.PRESET_FULL_RECT)
	icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var miniatura: Texture2D = null
	if not pasta and IMAGENS.has(nome.get_extension().to_lower()) and _miniaturas < MAX_MINIATURAS:
		miniatura = Sprites.textura(caminho)
		_miniaturas += 1
	icone.draw.connect(_desenhar_icone.bind(icone, pasta, marcado, miniatura))
	b.add_child(icone)
	if pasta:
		b.pressed.connect(_entrar.bind(caminho + "/"))
	else:
		b.pressed.connect(_alternar.bind(caminho))
	return b


func _desenhar_icone(c: Control, pasta: bool, marcado: bool, miniatura: Texture2D) -> void:
	var cy: float = ALT_LINHA * 0.5
	if pasta:
		var cor := Color(1.0, 0.78, 0.25)
		c.draw_rect(Rect2(16.0, cy - 14.0, 18.0, 8.0), cor)
		c.draw_rect(Rect2(16.0, cy - 8.0, 40.0, 26.0), cor)
		return
	if miniatura != null:
		var ts: Vector2 = miniatura.get_size()
		var e: float = minf(48.0 / ts.x, 48.0 / ts.y)
		var w: Vector2 = ts * e
		c.draw_texture_rect(miniatura, Rect2(18.0 + (48.0 - w.x) * 0.5, cy - w.y * 0.5, w.x, w.y), false)
	else:
		c.draw_rect(Rect2(20.0, cy - 18.0, 32.0, 36.0), Color(0.75, 0.8, 1.0), false, 3.0)
		c.draw_line(Vector2(27.0, cy - 4.0), Vector2(45.0, cy - 4.0), Color(0.75, 0.8, 1.0), 3.0)
		c.draw_line(Vector2(27.0, cy + 6.0), Vector2(45.0, cy + 6.0), Color(0.75, 0.8, 1.0), 3.0)
	if marcado:
		c.draw_circle(Vector2(64.0, cy + 14.0), 13.0, COR_DESTAQUE)
		c.draw_line(Vector2(57.0, cy + 14.0), Vector2(62.0, cy + 20.0), Color.WHITE, 4.0)
		c.draw_line(Vector2(62.0, cy + 20.0), Vector2(72.0, cy + 7.0), Color.WHITE, 4.0)


func _entrar(p: String) -> void:
	_pasta = p
	_listar()


func _subir() -> void:
	if _pasta == RAIZ:
		return
	var sem: String = _pasta.trim_suffix("/")
	var base: String = sem.get_base_dir()
	_pasta = RAIZ if (base == "user:" or base == "user://" or base == "") else base + "/"
	_listar()


func _alternar(caminho: String) -> void:
	if not _varios:
		escolhido.emit(PackedStringArray([caminho]))
		queue_free()
		return
	if _marcados.has(caminho):
		_marcados.erase(caminho)
	else:
		_marcados.append(caminho)
	_listar()


func _atualizar_ok() -> void:
	_btn_ok.visible = _varios
	_btn_ok.disabled = _marcados.is_empty()
	_btn_ok.text = "Importar (%d)" % _marcados.size() if not _marcados.is_empty() else "Toque nos arquivos para marcar"


func _confirmar() -> void:
	if _marcados.is_empty():
		return
	escolhido.emit(PackedStringArray(_marcados))
	queue_free()


func _cancelar() -> void:
	cancelado.emit()
	queue_free()
