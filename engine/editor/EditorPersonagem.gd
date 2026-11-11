extends Control

# Criador de personagens (layout do mockup): cabeçalho, barra de nome, painel Informações,
# área de visualização, timeline de sprites do golpe (ou da animação) em edição,
# Adicionar Golpe, Lista de Golpes (com prioridade) e Adicionar Som.
# Golpes fixos (LP, LK, HP, HK, BO): só sprites, sprite de impacto e som. Os frames são fixos;
# o motor reparte os sprites pelos frames a 60 FPS. Os criados por você são totalmente editáveis.
# PRIORIDADE: o motor testa os golpes de cima para baixo e usa o primeiro que combina
# (botão + carga + ar + custo). A ordem da lista é a prioridade.
# Entrada: Menu.modo_editor = "criar" (novo) ou "editar" (lista de personagens).
# Autoloads são acessados por get_node (não pelo nome), para o script compilar sem eles.

const Formato = preload("res://engine/formato/Formato.gd")
const Pacote = preload("res://engine/formato/Pacote.gd")
const Edicao = preload("res://engine/editor/Edicao.gd")
const Medidas = preload("res://engine/formato/Medidas.gd")
const Eventos = preload("res://engine/sons/Eventos.gd")
const Sprites = preload("res://engine/nucleo/Sprites.gd")
const Menu = preload("res://engine/menu/Menu.gd")

const PASTA_USUARIO := "user://personagens/"
const COR_FUNDO := Color(0.05, 0.04, 0.12)
const COR_PAINEL := Color(0.08, 0.07, 0.18)
const COR_BORDA := Color(0.55, 0.40, 0.95)
const COR_TEXTO := Color(0.92, 0.9, 1.0)
const COR_SUAVE := Color(0.7, 0.65, 0.9)
const ALTURA_BOTAO: float = 40.0
const EXT_IMAGEM := ["png", "webp", "jpg", "jpeg"]
const EXT_SOM := ["ogg", "wav", "mp3"]

# Posições (tela de 960x540)
const R_INFO := Rect2(14.0, 80.0, 262.0, 190.0)
const R_GOLPE := Rect2(14.0, 278.0, 262.0, 54.0)
const R_PREVIA := Rect2(290.0, 80.0, 656.0, 252.0)
const R_LINHA := Rect2(290.0, 392.0, 568.0, 104.0)
const THUMB := Vector2(88.0, 78.0)
const THUMB_SEL := Vector2(106.0, 94.0)

# c = caminho no golpe ("dano" ou "hitbox.x"), r = rótulo, p = passo, min/max, int = inteiro
const NUMERICOS := [
	{"c": "startup", "r": "Startup", "p": 1.0, "min": 0.0, "max": 99.0, "int": true},
	{"c": "active", "r": "Active", "p": 1.0, "min": 1.0, "max": 99.0, "int": true},
	{"c": "recovery", "r": "Recovery", "p": 1.0, "min": 0.0, "max": 199.0, "int": true},
	{"c": "forca", "r": "Forca (1-3)", "p": 1.0, "min": 1.0, "max": 3.0, "int": true},
	{"c": "dano", "r": "Dano", "p": 10.0, "min": 0.0, "max": 999.0, "int": true},
	{"c": "custo", "r": "Custo barra", "p": 10.0, "min": 0.0, "max": 300.0, "int": true},
	{"c": "energia_ganha", "r": "Barra ganha", "p": 10.0, "min": 0.0, "max": 300.0, "int": true},
	{"c": "carga_seg", "r": "Carga (seg)", "p": 0.1, "min": 0.0, "max": 3.0, "int": false},
]
const HITBOX := [
	{"c": "hitbox.x", "r": "Hitbox X (px)", "p": 5.0, "min": -300.0, "max": 300.0, "int": true},
	{"c": "hitbox.y", "r": "Hitbox Y (px)", "p": 5.0, "min": -300.0, "max": 0.0, "int": true},
	{"c": "hitbox.w", "r": "Largura (px)", "p": 5.0, "min": 1.0, "max": 300.0, "int": true},
	{"c": "hitbox.h", "r": "Altura (px)", "p": 5.0, "min": 1.0, "max": 300.0, "int": true},
]
const FLAGS := [["antichao", "Anti-chao"], ["blowoff", "Blow Off"], ["so_ar", "So no ar"]]


# Botão roxo com ícone desenhado à esquerda (a fonte padrão não tem ícones).
class BotaoIcone extends Button:
	var tipo: String = "mais"

	func _init(t: String = "mais", texto_btn: String = "") -> void:
		tipo = t
		text = texto_btn
		custom_minimum_size = Vector2(0, 40)

	func _draw() -> void:
		var cor := Color(1, 1, 1, 0.95)
		var c := Vector2(24.0 if text != "" else size.x * 0.5, size.y * 0.5)
		if tipo == "mais":
			draw_line(c + Vector2(-9, 0), c + Vector2(9, 0), cor, 3.0)
			draw_line(c + Vector2(0, -9), c + Vector2(0, 9), cor, 3.0)
		elif tipo == "lista":
			for k in range(3):
				var y: float = c.y - 8.0 + 8.0 * float(k)
				draw_rect(Rect2(c.x - 10.0, y - 1.5, 4.0, 3.0), cor)
				draw_line(Vector2(c.x - 3.0, y), Vector2(c.x + 10.0, y), cor, 3.0)
		elif tipo == "som":
			draw_circle(c + Vector2(-6, 8), 5.0, cor)
			draw_line(c + Vector2(-1, 8), c + Vector2(-1, -10), cor, 3.0)
			draw_line(c + Vector2(-1, -10), c + Vector2(9, -6), cor, 3.0)
			draw_line(c + Vector2(8, 4), c + Vector2(16, 4), cor, 2.0)
			draw_line(c + Vector2(12, 0), c + Vector2(12, 8), cor, 2.0)


var _p: Dictionary = {}
var _pasta_midia := ""
var _novo := false
var _veio_da_lista := false
var _sel := -1
var _alvo_slot := ""
var _q_sel := 0
var _t_off := 0
var _anim_t := 0
var _tocando := false
var _mostrar_caixas := false

var _tela_lista: MarginContainer
var _lista_personagens: VBoxContainer
var _tela_edicao: Control
var _campo_nome: LineEdit
var _area: Control
var _info: Control
var _cartao: Control
var _linha: Control
var _btn_testar: Button
var _btn_impacto: Button
var _lbl_tempo: Label
var _campo_golpe: LineEdit
var _btn_botao: Button
var _btn_carga: Button
var _sec_custom: VBoxContainer
var _lbl_base: Label
var _lbl_som: Label
var _preview: Control
var _valores := {}
var _specs := {}
var _checks := {}
var _lbl_slots := {}
var _lbl_eventos := {}
var _lbl_artes := {}
var _lbl_altura: Label
var _lista_golpes: VBoxContainer
var _lbl_slots_box: VBoxContainer
var _msgs: Array[Label] = []
var _fd: FileDialog
var _fd_acao: Callable
var _pops := {}


# ---------- Autoloads (acesso em tempo de execução) ----------

func _catalogo() -> Variant:
	return get_node("/root/Catalogo")

func _navegacao() -> Variant:
	return get_node("/root/Navegacao")

func _ir_menu() -> void:
	_navegacao().ir_para_menu()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var fundo := ColorRect.new()
	fundo.color = COR_FUNDO
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)
	_montar_lista()
	_montar_edicao()
	_montar_popups()
	if Menu.modo_editor == "criar":
		_novo_personagem()
	else:
		_mostrar_lista()


func _process(_d: float) -> void:
	if _tocando and _tela_edicao.visible:
		_anim_t += 1
		_area.queue_redraw()


# ---------- montagem da tela de edição ----------

func _nova_tela() -> MarginContainer:
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for lado in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		m.add_theme_constant_override(lado, 10)
	add_child(m)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_EXPAND_FILL
	m.add_child(v)
	return m


func _montar_lista() -> void:
	_tela_lista = _nova_tela()
	var vb: VBoxContainer = _tela_lista.get_child(0) as VBoxContainer
	vb.add_child(_titulo("Personagens"))
	var rolagem := ScrollContainer.new()
	rolagem.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(rolagem)
	_lista_personagens = VBoxContainer.new()
	_lista_personagens.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rolagem.add_child(_lista_personagens)
	vb.add_child(_linha_botoes([
		_botao("Novo personagem", _novo_personagem),
		_botao("Colar backup", _colar_backup),
		_botao("Voltar", _ir_menu),
	]))
	_msgs.append(_label_msg(vb))
	_tela_lista.visible = false

func _montar_edicao() -> void:
	_tela_edicao = Control.new()
	_tela_edicao.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tela_edicao.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tela_edicao)

	# Cabeçalho e barra de nome.
	var cab := Control.new()
	cab.position = Vector2.ZERO
	cab.size = Vector2(960.0, 76.0)
	cab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cab.draw.connect(_desenhar_cabecalho.bind(cab))
	_tela_edicao.add_child(cab)
	_campo_nome = LineEdit.new()
	_campo_nome.placeholder_text = "Meu Personagem"
	_campo_nome.position = Vector2(560.0, 34.0)
	_campo_nome.size = Vector2(386.0, 38.0)
	_campo_nome.max_length = 40
	_tela_edicao.add_child(_campo_nome)

	# Painel Informações (as linhas abrem as janelas de Animações, Golpes, Sons e Artes).
	_info = Control.new()
	_info.position = R_INFO.position
	_info.size = R_INFO.size
	_info.draw.connect(_desenhar_info)
	_info.gui_input.connect(_on_info_input)
	_tela_edicao.add_child(_info)

	# Cartão do que está sendo editado (golpe ou animação) com a prioridade.
	_cartao = Control.new()
	_cartao.position = R_GOLPE.position
	_cartao.size = R_GOLPE.size
	_cartao.draw.connect(_desenhar_cartao)
	_tela_edicao.add_child(_cartao)

	_tela_edicao.add_child(_botao_em("Adicionar Golpe", "mais", Rect2(14.0, 340.0, 262.0, 44.0), _abrir_mais))
	_tela_edicao.add_child(_botao_em("Propriedades do golpe", "", Rect2(14.0, 390.0, 262.0, 40.0), _abrir_props))
	_tela_edicao.add_child(_botao_em("Salvar", "", Rect2(14.0, 440.0, 126.0, 40.0), _on_salvar))
	_tela_edicao.add_child(_botao_em("Voltar", "", Rect2(150.0, 440.0, 126.0, 40.0), _voltar_edicao))

	# Área de visualização.
	_area = Control.new()
	_area.position = R_PREVIA.position
	_area.size = R_PREVIA.size
	_area.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_area.draw.connect(_desenhar_area)
	_tela_edicao.add_child(_area)

	# Linha de botões entre a visualização e a timeline.
	_btn_testar = _botao_em("Testar", "", Rect2(290.0, 340.0, 100.0, 40.0), _alternar_teste)
	_tela_edicao.add_child(_btn_testar)
	_tela_edicao.add_child(_botao_em("Caixas", "", Rect2(396.0, 340.0, 90.0, 40.0), _alternar_caixas))
	_btn_impacto = _botao_em("Impacto", "", Rect2(492.0, 340.0, 96.0, 40.0), _alternar_impacto)
	_tela_edicao.add_child(_btn_impacto)
	_tela_edicao.add_child(_botao_em("Remover", "", Rect2(594.0, 340.0, 96.0, 40.0), _remover_quadro))
	_tela_edicao.add_child(_botao_em("Lista de Golpes", "lista", Rect2(756.0, 340.0, 190.0, 40.0), _abrir_lista))

	# Timeline de sprites.
	_linha = Control.new()
	_linha.position = R_LINHA.position
	_linha.size = R_LINHA.size
	_linha.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_linha.draw.connect(_desenhar_linha)
	_linha.gui_input.connect(_on_linha_input)
	_tela_edicao.add_child(_linha)
	_tela_edicao.add_child(_botao_em("", "som", Rect2(870.0, 414.0, 76.0, 56.0), _som_do_golpe))
	_lbl_tempo = Label.new()
	_lbl_tempo.position = Vector2(290.0, 498.0)
	_lbl_tempo.size = Vector2(656.0, 36.0)
	_lbl_tempo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_tempo.add_theme_font_size_override("font_size", 12)
	_lbl_tempo.add_theme_color_override("font_color", COR_SUAVE)
	_tela_edicao.add_child(_lbl_tempo)
	var msg := Label.new()
	msg.position = Vector2(14.0, 488.0)
	msg.size = Vector2(262.0, 48.0)
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.add_theme_font_size_override("font_size", 12)
	msg.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))
	_tela_edicao.add_child(msg)
	_msgs.append(msg)
	_tela_edicao.visible = false


func _estilizar(b: Button) -> void:
	for par in [["normal", Color(0.14, 0.11, 0.32)], ["hover", Color(0.2, 0.15, 0.42)], ["pressed", Color(0.3, 0.2, 0.6)], ["disabled", Color(0.1, 0.09, 0.2)]]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = par[1]
		sb.border_color = COR_BORDA
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(6)
		sb.content_margin_left = 10.0
		sb.content_margin_right = 10.0
		b.add_theme_stylebox_override(str(par[0]), sb)
	b.add_theme_color_override("font_color", COR_TEXTO)


func _botao_em(texto: String, icone: String, r: Rect2, acao: Callable) -> Button:
	var b: Button
	if icone != "":
		b = BotaoIcone.new(icone, texto)
	else:
		b = Button.new()
		b.text = texto
	b.position = r.position
	b.size = r.size
	b.clip_text = true
	_estilizar(b)
	b.pressed.connect(acao)
	return b




func _botao(texto: String, acao: Callable) -> Button:
	var b := Button.new()
	b.text = texto
	b.custom_minimum_size = Vector2(0, ALTURA_BOTAO)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.clip_text = true
	_estilizar(b)
	b.pressed.connect(acao)
	return b


func _mini(t: String, acao: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(44, ALTURA_BOTAO)
	_estilizar(b)
	b.pressed.connect(acao)
	return b


func _stepper(spec: Dictionary) -> HBoxContainer:
	var caminho := str(spec["c"])
	var linha := HBoxContainer.new()
	linha.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var rot := Label.new()
	rot.text = str(spec["r"])
	rot.custom_minimum_size = Vector2(110, 0)
	linha.add_child(rot)
	linha.add_child(_mini("-", _ajustar.bind(caminho, -1)))
	var val := Label.new()
	val.custom_minimum_size = Vector2(50, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	linha.add_child(val)
	linha.add_child(_mini("+", _ajustar.bind(caminho, 1)))
	_valores[caminho] = val
	_specs[caminho] = spec
	return linha

func _linha_botoes(botoes: Array) -> HBoxContainer:
	var h := HBoxContainer.new()
	for b in botoes:
		h.add_child(b)
	return h

func _titulo(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 26)
	return l

func _rotulo(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", Color(0.8, 0.85, 1.0))
	return l

func _label_msg(pai: Node) -> Label:
	var l := Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pai.add_child(l)
	return l

func _mensagem(t: String) -> void:
	for l in _msgs:
		l.text = t

func _limpar(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()

# ---------- janelas (popups) ----------

func _novo_popup(nome: String, titulo: String, tam: Vector2i) -> VBoxContainer:
	var pop := PopupPanel.new()
	pop.set_meta("tam", tam)
	add_child(pop)
	var v := VBoxContainer.new()
	pop.add_child(v)
	v.add_child(_rotulo(titulo))
	var rol := ScrollContainer.new()
	rol.custom_minimum_size = Vector2(float(tam.x) - 24.0, float(tam.y) - 90.0)
	rol.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(rol)
	var conteudo := VBoxContainer.new()
	conteudo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rol.add_child(conteudo)
	v.add_child(_botao("Fechar", pop.hide))
	_pops[nome] = pop
	return conteudo


func _abrir_pop(nome: String) -> void:
	var pop: PopupPanel = _pops[nome]
	pop.popup_centered(pop.get_meta("tam"))


func _fechar_pop(nome: String) -> void:
	(_pops[nome] as PopupPanel).hide()


func _montar_popups() -> void:
	_fd = FileDialog.new()
	_fd.access = FileDialog.ACCESS_FILESYSTEM
	_fd.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_fd.file_selected.connect(_on_arquivo)
	add_child(_fd)

	# Adicionar golpe
	var mais: VBoxContainer = _novo_popup("mais", "Adicionar golpe", Vector2i(380, 420))
	for botao in Formato.BOTOES:
		var nome: String = str((Formato.BASE[botao] as Dictionary)["nome"])
		mais.add_child(_botao("%s - %s (fixo)" % [botao, nome], _adicionar_base.bind(str(botao))))
	mais.add_child(_botao("Esquiva (so sprites)", _ir_sprite_esquiva))
	mais.add_child(_botao("Golpe personalizado", _novo_golpe))

	# Lista de golpes (com prioridade)
	_lista_golpes = _novo_popup("lista", "Lista de Golpes", Vector2i(700, 440))

	# Animações (sprites por situação)
	var an: VBoxContainer = _novo_popup("slots", "Animacoes do personagem", Vector2i(620, 440))
	an.add_child(_rotulo("Escolha uma animacao para editar na timeline."))
	for slot in Formato.SLOTS:
		var linha := HBoxContainer.new()
		an.add_child(linha)
		var l := Label.new()
		l.custom_minimum_size = Vector2(330, 0)
		linha.add_child(l)
		_lbl_slots[slot] = l
		linha.add_child(_botao("Editar", _editar_slot.bind(str(slot))))
		linha.add_child(_botao("Limpar", _limpar_slot.bind(str(slot))))

	# Sons por evento
	var so: VBoxContainer = _novo_popup("sons", "Sons do personagem", Vector2i(620, 440))
	so.add_child(_rotulo("Sons por evento. O som de cada golpe fica no botao de nota musical."))
	for ev in Eventos.TODOS:
		var linha2 := HBoxContainer.new()
		so.add_child(linha2)
		var l2 := Label.new()
		l2.custom_minimum_size = Vector2(300, 0)
		linha2.add_child(l2)
		_lbl_eventos[ev] = l2
		linha2.add_child(_botao("Escolher", _escolher_som.bind(_novo_som_evento.bind(str(ev)))))
		linha2.add_child(_botao("Limpar", _limpar_som_evento.bind(str(ev))))

	# Artes, medidas e backup
	var ar: VBoxContainer = _novo_popup("artes", "Artes, medidas e backup", Vector2i(620, 440))
	ar.add_child(_rotulo("Arte da selecao (grande) e do card (quadro da grade de selecao)"))
	for par in [["arte_selecao", "arte/selecao."], ["arte_card", "arte/card."]]:
		var li := HBoxContainer.new()
		ar.add_child(li)
		var l3 := Label.new()
		l3.custom_minimum_size = Vector2(260, 0)
		li.add_child(l3)
		_lbl_artes[str(par[0])] = l3
		li.add_child(_botao("Escolher", _escolher_imagem.bind(_nova_arte.bind(str(par[0]), str(par[1])))))
		li.add_child(_botao("Limpar", _limpar_arte.bind(str(par[0]))))
	ar.add_child(_rotulo("Altura do personagem em pixels (define o corpo e a escala dos golpes)"))
	var la := HBoxContainer.new()
	ar.add_child(la)
	la.add_child(_mini("-", _ajustar_altura.bind(-10)))
	_lbl_altura = Label.new()
	_lbl_altura.custom_minimum_size = Vector2(100, 0)
	_lbl_altura.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	la.add_child(_lbl_altura)
	la.add_child(_mini("+", _ajustar_altura.bind(10)))
	la.add_child(_botao("Medir pelo sprite parado", _medir_altura))
	ar.add_child(_linha_botoes([_botao("Copiar backup", _copiar_backup), _botao("Colar backup", _colar_backup)]))

	# Propriedades do golpe
	var pr: VBoxContainer = _novo_popup("props", "Propriedades do golpe", Vector2i(700, 460))
	_montar_props(pr)


func _montar_props(p: VBoxContainer) -> void:
	_lbl_base = Label.new()
	_lbl_base.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p.add_child(_lbl_base)
	_sec_custom = VBoxContainer.new()
	p.add_child(_sec_custom)
	var linha := HBoxContainer.new()
	_sec_custom.add_child(linha)
	_campo_golpe = LineEdit.new()
	_campo_golpe.placeholder_text = "Nome do golpe"
	_campo_golpe.custom_minimum_size = Vector2(0, ALTURA_BOTAO)
	_campo_golpe.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_campo_golpe.text_changed.connect(_on_nome_golpe)
	linha.add_child(_campo_golpe)
	_btn_botao = _botao("", _ciclo_botao)
	linha.add_child(_btn_botao)
	_btn_carga = _botao("", _ciclo_carga)
	linha.add_child(_btn_carga)
	var grade := GridContainer.new()
	grade.columns = 2
	_sec_custom.add_child(grade)
	for spec in NUMERICOS:
		grade.add_child(_stepper(spec))
	var flags := HBoxContainer.new()
	_sec_custom.add_child(flags)
	for f in FLAGS:
		var cb := CheckBox.new()
		cb.text = str(f[1])
		cb.toggled.connect(_on_flag.bind(str(f[0])))
		flags.add_child(cb)
		_checks[str(f[0])] = cb
	var hb := HBoxContainer.new()
	_sec_custom.add_child(hb)
	var col := VBoxContainer.new()
	hb.add_child(col)
	for spec in HITBOX:
		col.add_child(_stepper(spec))
	col.add_child(_botao("Alcance automatico (pelo sprite)", _alcance_automatico))
	_preview = Control.new()
	_preview.custom_minimum_size = Vector2(220, 170)
	_preview.draw.connect(_desenhar_preview.bind(_preview))
	hb.add_child(_preview)
	p.add_child(_rotulo("Som do golpe (fala, grunhido...)"))
	_lbl_som = Label.new()
	p.add_child(_lbl_som)
	p.add_child(_linha_botoes([_botao("Escolher som", _som_do_golpe), _botao("Limpar som", _limpar_som_golpe)]))


# ---------- telas ----------

func _mostrar_lista() -> void:
	_tela_edicao.visible = false
	_tela_lista.visible = true
	_mensagem("")
	_limpar(_lista_personagens)
	var itens: Array = _catalogo().lista()
	if itens.is_empty():
		_mensagem("Nenhum personagem ainda.")
	for item in itens:
		var rotulo := "jogo" if str(item["origem"]) == "jogo" else "meu"
		_lista_personagens.add_child(_botao("%s  [%s]" % [str(item["nome"]), rotulo], _abrir_item.bind(item)))

func _abrir_item(item: Dictionary) -> void:
	_veio_da_lista = true
	_abrir((item["personagem"] as Dictionary).duplicate(true), str(item["pasta"]), false)

func _novo_personagem() -> void:
	_veio_da_lista = _tela_lista.visible
	_abrir(Edicao.novo_personagem("", ""), "", true)

func _abrir(p: Dictionary, pasta: String, novo: bool) -> void:
	var norm: Dictionary = Formato.normalizar(p)
	_p = norm["personagem"] if norm["ok"] else p
	_pasta_midia = _com_barra(pasta)
	_novo = novo
	_sel = 0 if (_p["golpes"] as Array).size() > 0 else -1
	_alvo_slot = ""
	_q_sel = 0
	_t_off = 0
	_tocando = false
	_anim_t = 0
	_campo_nome.text = "" if novo else str(_p["nome"])
	_tela_lista.visible = false
	_tela_edicao.visible = true
	_mensagem("")
	_refrescar()


func _voltar_edicao() -> void:
	if _veio_da_lista:
		_mostrar_lista()
	else:
		_ir_menu()

func _com_barra(s: String) -> String:
	if s == "" or s.ends_with("/"):
		return s
	return s + "/"

func _refrescar() -> void:
	_reconstruir_lista()
	_atualizar_campos()
	_atualizar_abas()
	_atualizar_tempo()
	_garantir_visivel()
	_redesenhar()


func _redesenhar() -> void:
	_area.queue_redraw()
	_info.queue_redraw()
	_cartao.queue_redraw()
	_linha.queue_redraw()


func _atualizar_lista_golpes() -> void:
	_reconstruir_lista()
	_redesenhar()


func _golpe() -> Dictionary:
	return (_p["golpes"] as Array)[_sel]

func _selecionar(i: int) -> void:
	_sel = i
	_alvo_slot = ""
	_q_sel = 0
	_t_off = 0
	_anim_t = 0
	_fechar_pop("lista")
	_refrescar()


func _editar_slot(slot: String) -> void:
	_alvo_slot = slot
	_q_sel = 0
	_t_off = 0
	_anim_t = 0
	_fechar_pop("slots")
	_refrescar()


# Golpe anterior da lista que já cobre este (mesmo botão, sem carga, sem "só no ar" e custo
# menor ou igual): como o motor usa o primeiro que combina, este nunca seria usado. -1 = livre.
func _coberto_por(i: int) -> int:
	var golpes: Array = _p["golpes"]
	var g: Dictionary = golpes[i]
	for j in range(i):
		var o: Dictionary = golpes[j]
		if str(o["botao"]) == str(g["botao"]) and str(o["carga"]) == "" and not bool(o["so_ar"]) and int(o["custo"]) <= int(g["custo"]):
			return j
	return -1


func _reconstruir_lista() -> void:
	_limpar(_lista_golpes)
	_lista_golpes.add_child(_rotulo("PRIORIDADE: o jogo testa de cima para baixo e usa o primeiro golpe que combina (botao + carga + ar + custo). Golpes mais especificos (com carga ou custo) devem ficar ACIMA do golpe simples do mesmo botao."))
	var golpes: Array = _p["golpes"]
	if golpes.is_empty():
		_lista_golpes.add_child(_rotulo("Nenhum golpe ainda. Use Adicionar Golpe."))
	for i in range(golpes.size()):
		var g: Dictionary = golpes[i]
		var linha := HBoxContainer.new()
		_lista_golpes.add_child(linha)
		var n := Label.new()
		n.text = "#%d" % (i + 1)
		n.custom_minimum_size = Vector2(34, 0)
		linha.add_child(n)
		var rot: String = "%s  %s%s" % [Formato.comando_texto(g), str(g["nome"]), "  [fixo]" if bool(g["base"]) else ""]
		var b: Button = _botao(rot, _acao_linha.bind(i, "editar"))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		linha.add_child(b)
		for par in [["Sobe", "sobe"], ["Desce", "desce"], ["Copia", "copia"], ["Exclui", "exclui"]]:
			var bb: Button = _botao(str(par[0]), _acao_linha.bind(i, str(par[1])))
			bb.size_flags_horizontal = Control.SIZE_SHRINK_END
			bb.custom_minimum_size = Vector2(64, ALTURA_BOTAO)
			linha.add_child(bb)
		var cob: int = _coberto_por(i)
		if cob >= 0:
			var av := Label.new()
			av.text = "    AVISO: nunca sera usado - o golpe #%d usa o mesmo botao e vem antes. Suba este golpe." % (cob + 1)
			av.add_theme_color_override("font_color", Color(1.0, 0.5, 0.4))
			av.add_theme_font_size_override("font_size", 12)
			_lista_golpes.add_child(av)


func _acao_linha(i: int, tipo: String) -> void:
	_sel = i
	_alvo_slot = ""
	match tipo:
		"editar":
			_selecionar(i)
		"sobe":
			_mover(-1)
		"desce":
			_mover(1)
		"copia":
			_copiar_golpe()
		"exclui":
			_excluir_golpe()


func _atualizar_campos() -> void:
	var tem: bool = _sel >= 0
	_lbl_base.visible = true
	_sec_custom.visible = false
	if not tem:
		_lbl_base.text = "Nenhum golpe. Use Adicionar Golpe."
		_lbl_som.text = ""
		return
	var g: Dictionary = _golpe()
	if bool(g["base"]):
		_lbl_base.text = "%s (%s) - golpe FIXO. Tempo: %d + %d + %d frames, dano %d. Estes numeros nao mudam (todos os personagens tem o mesmo golpe). Voce troca so os sprites (timeline) e o som." % [
			str(g["nome"]), str(g["botao"]), int(g["startup"]), int(g["active"]), int(g["recovery"]), int(g["dano"])]
	else:
		_lbl_base.text = "Golpe criado por voce: tudo pode ser editado."
		_sec_custom.visible = true
		_campo_golpe.text = str(g["nome"])
		_btn_botao.text = str(g["botao"])
		_btn_carga.text = _texto_carga(str(g["carga"]))
		for c in _valores.keys():
			_mostrar_valor(str(c))
		for chave in _checks.keys():
			(_checks[chave] as CheckBox).set_pressed_no_signal(bool(g[chave]))
	var som: String = str((g["sons"] as Dictionary)["uso"])
	_lbl_som.text = som.get_file() if som != "" else "(sem som proprio)"
	_preview.queue_redraw()


func _atualizar_abas() -> void:
	var sprites: Dictionary = _p["sprites"]
	for slot in Formato.SLOTS:
		var n: int = (sprites[slot] as Array).size()
		(_lbl_slots[slot] as Label).text = "%s: %s" % [str(Formato.ROTULOS_SLOT[slot]), ("%d sprite(s)" % n) if n > 0 else "vazio"]
	for k in _lbl_artes.keys():
		var rel: String = str(_p[k])
		(_lbl_artes[k] as Label).text = "%s: %s" % ["Arte da selecao" if k == "arte_selecao" else "Arte do card", rel.get_file() if rel != "" else "vazio"]
	_lbl_altura.text = "%d px" % int(_p["altura_px"])
	for ev in Eventos.TODOS:
		(_lbl_eventos[ev] as Label).text = "%s: %s" % [str(ev), "ok" if _achar_som_evento(str(ev)) != "" else "vazio"]
	_info.queue_redraw()


func _atualizar_tempo() -> void:
	if _alvo_slot != "":
		if Formato.SLOTS_EM_CICLO.has(_alvo_slot):
			_lbl_tempo.text = "Animacao em ciclo: cada sprite dura %d frames (60 FPS)." % Formato.FRAMES_POR_SPRITE_CICLO
		else:
			_lbl_tempo.text = "Os sprites sao distribuidos na duracao desta situacao."
	elif _sel >= 0:
		_lbl_tempo.text = _texto_tempo(_golpe())
	else:
		_lbl_tempo.text = ""
	var g_ok: bool = _alvo_slot == "" and _sel >= 0
	_btn_impacto.disabled = not g_ok


func _texto_carga(c: String) -> String:
	if c == "tras":
		return "Carga tras"
	if c == "baixo":
		return "Carga baixo"
	return "Sem carga"

func _achar_som_evento(ev: String) -> String:
	for e in EXT_SOM:
		if FileAccess.file_exists(_pasta_midia + "sons/" + ev + "." + str(e)):
			return _pasta_midia + "sons/" + ev + "." + str(e)
	return ""

# ---------- golpes ----------

func _abrir_mais() -> void:
	_abrir_pop("mais")


func _abrir_lista() -> void:
	_reconstruir_lista()
	_abrir_pop("lista")


func _abrir_props() -> void:
	if _sel < 0 or _alvo_slot != "":
		_mensagem("Selecione um golpe (Lista de Golpes) para ver as propriedades.")
		return
	_atualizar_campos()
	_abrir_pop("props")


func _adicionar_base(botao: String) -> void:
	_fechar_pop("mais")
	var ja: bool = Edicao.indice_base(_p, botao) >= 0
	var i: int = Edicao.adicionar_base(_p, botao)
	if i < 0:
		_mensagem("Limite de golpes atingido.")
		return
	_sel = i
	_alvo_slot = ""
	_q_sel = 0
	_t_off = 0
	_refrescar()
	_mensagem("Esse golpe ja existe." if ja else "")


func _ir_sprite_esquiva() -> void:
	_fechar_pop("mais")
	_editar_slot("esquiva")
	_mensagem("Esquiva: a distancia e igual para todos. Voce coloca so os sprites.")


func _novo_golpe() -> void:
	_fechar_pop("mais")
	if not Edicao.inserir_golpe(_p, (_p["golpes"] as Array).size()):
		_mensagem("Limite de golpes atingido.")
		return
	_sel = (_p["golpes"] as Array).size() - 1
	_alvo_slot = ""
	_q_sel = 0
	_t_off = 0
	_refrescar()
	_abrir_props()


func _mover(direcao: int) -> void:
	if _sel >= 0 and Edicao.mover_golpe(_p, _sel, direcao):
		_sel += direcao
		_refrescar()

func _copiar_golpe() -> void:
	if _sel >= 0 and Edicao.copiar_golpe(_p, _sel):
		_sel += 1
		_refrescar()

func _excluir_golpe() -> void:
	if _sel < 0:
		return
	Edicao.excluir_golpe(_p, _sel)
	_sel = mini(_sel, (_p["golpes"] as Array).size() - 1)
	_refrescar()

func _on_nome_golpe(t: String) -> void:
	if _sel < 0 or bool(_golpe()["base"]):
		return
	_golpe()["nome"] = t
	_atualizar_lista_golpes()

func _ciclo_botao() -> void:
	if _sel < 0 or bool(_golpe()["base"]):
		return
	var g: Dictionary = _golpe()
	var i: int = Formato.BOTOES.find(str(g["botao"]))
	g["botao"] = Formato.BOTOES[(i + 1) % Formato.BOTOES.size()]
	_refrescar()

func _ciclo_carga() -> void:
	if _sel < 0 or bool(_golpe()["base"]):
		return
	var g: Dictionary = _golpe()
	var i: int = Formato.CARGAS.find(str(g["carga"]))
	g["carga"] = Formato.CARGAS[(i + 1) % Formato.CARGAS.size()]
	_refrescar()

func _on_flag(ligado: bool, chave: String) -> void:
	if _sel < 0 or bool(_golpe()["base"]):
		return
	_golpe()[chave] = ligado
	_preview.queue_redraw()

func _mostrar_valor(c: String) -> void:
	if _sel < 0:
		return
	var spec: Dictionary = _specs[c]
	var v: float = float(_ler(_golpe(), c))
	(_valores[c] as Label).text = str(int(v)) if spec["int"] else "%.1f" % v


# c = caminho ("dano" ou "hitbox.x")

func _ler(g: Dictionary, c: String) -> Variant:
	var atual: Variant = g
	for parte in c.split("."):
		atual = atual[parte]
	return atual

func _gravar(g: Dictionary, c: String, valor: Variant) -> void:
	var partes := c.split(".")
	var atual: Dictionary = g
	for i in partes.size() - 1:
		atual = atual[partes[i]]
	atual[partes[partes.size() - 1]] = valor

func _ajustar(c: String, sinal: int) -> void:
	if _sel < 0 or bool(_golpe()["base"]):
		return
	var spec: Dictionary = _specs[c]
	var g: Dictionary = _golpe()
	var v: float = float(_ler(g, c)) + sinal * float(spec["p"])
	v = clampf(v, float(spec["min"]), float(spec["max"]))
	_gravar(g, c, int(round(v)) if spec["int"] else snappedf(v, 0.1))
	_mostrar_valor(c)
	_lbl_tempo.text = _texto_tempo(g)
	_preview.queue_redraw()

func _alcance_automatico() -> void:
	if _sel < 0 or bool(_golpe()["base"]):
		return
	var g: Dictionary = _golpe()
	var h: Dictionary = Medidas.hitbox_sugerida(g, int(_p["altura_px"]), _pasta_midia)
	if h.is_empty():
		_mensagem("Adicione um sprite ao golpe (e salve o personagem) para medir o alcance.")
		return
	g["hitbox"] = h
	_mensagem("Alcance medido pelo sprite: ajuste fino com os botoes se precisar.")
	_atualizar_campos()

# ---------- timeline (sprites do golpe ou da animação em edição) ----------

func _frames_alvo() -> Array:
	if _alvo_slot != "":
		return (_p["sprites"] as Dictionary)[_alvo_slot]
	if _sel >= 0:
		return _golpe()["frames"]
	return []


func _alvo_editavel() -> bool:
	return _alvo_slot != "" or _sel >= 0


func _novo_quadro(origem: String) -> void:
	if not _alvo_editavel():
		_mensagem("Adicione um golpe primeiro (botao Adicionar Golpe).")
		return
	if _frames_alvo().size() >= Formato.MAX_QUADROS:
		_mensagem("Limite de sprites.")
		return
	var prefixo: String = ("sprites/" + _alvo_slot) if _alvo_slot != "" else ("golpes/" + _slug_golpe())
	var rel: String = _importar(origem, _nome_livre(prefixo, _ext(origem, EXT_IMAGEM, "png")))
	if rel == "":
		return
	var frames: Array = _frames_alvo() # depois de importar: o salvar recria o dicionario
	frames.append(rel)
	_q_sel = frames.size() - 1
	if _alvo_slot == "parado" and frames.size() == 1 and int(_p["altura_px"]) == Formato.ALTURA_PADRAO:
		_medir_altura()
	_refrescar()


func _remover_quadro() -> void:
	var frames: Array = _frames_alvo()
	if frames.is_empty():
		return
	_q_sel = clampi(_q_sel, 0, frames.size() - 1)
	frames.remove_at(_q_sel)
	if _alvo_slot == "" and _sel >= 0:
		var g: Dictionary = _golpe()
		var imp: int = int(g["sprite_impacto"])
		if imp == _q_sel:
			g["sprite_impacto"] = -1
		elif imp > _q_sel:
			g["sprite_impacto"] = imp - 1
	_q_sel = clampi(_q_sel, 0, maxi(0, frames.size() - 1))
	_refrescar()


# Marca o sprite selecionado como o do impacto (alinha com os frames "active" do golpe).
func _alternar_impacto() -> void:
	if _alvo_slot != "" or _sel < 0:
		return
	var g: Dictionary = _golpe()
	if (g["frames"] as Array).is_empty():
		return
	g["sprite_impacto"] = -1 if int(g["sprite_impacto"]) == _q_sel else _q_sel
	_refrescar()


func _alternar_teste() -> void:
	_tocando = not _tocando
	_anim_t = 0
	_btn_testar.text = "Parar" if _tocando else "Testar"
	_area.queue_redraw()


func _alternar_caixas() -> void:
	_mostrar_caixas = not _mostrar_caixas
	_area.queue_redraw()


func _som_do_golpe() -> void:
	if _alvo_slot != "" or _sel < 0:
		_mensagem("Escolha um golpe para colocar o som dele. Sons de eventos: painel Informacoes > Sons.")
		return
	_escolher_som(_novo_som_golpe)


func _garantir_visivel() -> void:
	var n: int = _frames_alvo().size()
	var vis: int = 5
	_q_sel = clampi(_q_sel, 0, maxi(0, n - 1))
	if _q_sel < _t_off:
		_t_off = _q_sel
	elif _q_sel > _t_off + vis - 1:
		_t_off = _q_sel - vis + 1
	_t_off = clampi(_t_off, 0, maxi(0, n + 1 - vis))


# Retângulos das miniaturas visíveis: [{"r": Rect2, "i": int}] (i == quantidade de sprites = botão "+").
func _rects_linha() -> Array:
	var r: Array = []
	var n: int = _frames_alvo().size()
	var x: float = 44.0
	var i: int = _t_off
	while i <= n and x < R_LINHA.size.x - 44.0:
		var sel: bool = i == _q_sel and i < n
		var tam: Vector2 = THUMB_SEL if sel else THUMB
		if x + tam.x > R_LINHA.size.x - 40.0:
			break
		r.append({"r": Rect2(x, (R_LINHA.size.y - 20.0 - tam.y) * 0.5 + 4.0, tam.x, tam.y), "i": i})
		x += tam.x + 8.0
		i += 1
	return r


func _on_linha_input(ev: InputEvent) -> void:
	var mb := ev as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	var p: Vector2 = mb.position
	var n: int = _frames_alvo().size()
	if p.x < 40.0:
		_t_off = maxi(0, _t_off - 1)
	elif p.x > R_LINHA.size.x - 40.0:
		_t_off = mini(maxi(0, n + 1 - 5), _t_off + 1)
	else:
		for it in _rects_linha():
			var d: Dictionary = it
			if (d["r"] as Rect2).has_point(p):
				if int(d["i"]) >= n:
					if _alvo_editavel():
						_escolher_imagem(_novo_quadro)
					else:
						_mensagem("Adicione um golpe primeiro (botao Adicionar Golpe).")
				else:
					_q_sel = int(d["i"])
					_atualizar_tempo()
					_area.queue_redraw()
				break
	_linha.queue_redraw()


func _on_info_input(ev: InputEvent) -> void:
	var mb := ev as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	var linha: int = int((mb.position.y - 48.0) / 30.0)
	if mb.position.y < 48.0 or linha < 0 or linha > 3:
		return
	match linha:
		0:
			_abrir_pop("artes")
		1:
			_abrir_pop("slots")
		2:
			_abrir_lista()
		3:
			_abrir_pop("sons")


func _escolher_imagem(depois: Callable) -> void:
	_abrir_dialogo("Escolher imagem", PackedStringArray(["*.png, *.webp, *.jpg, *.jpeg ; Imagens"]), depois)

func _escolher_som(depois: Callable) -> void:
	_abrir_dialogo("Escolher som", PackedStringArray(["*.ogg, *.wav, *.mp3 ; Sons"]), depois)

func _abrir_dialogo(titulo: String, filtros: PackedStringArray, depois: Callable) -> void:
	_fd_acao = depois
	_fd.title = titulo
	_fd.filters = filtros
	_fd.popup_centered_ratio(0.9)

func _on_arquivo(caminho: String) -> void:
	if _fd_acao.is_valid():
		_fd_acao.call(caminho)


# Copia o arquivo escolhido para a pasta do personagem (salva o personagem antes, se preciso).
# Devolve o caminho relativo, ou "" se falhou.

func _importar(origem: String, rel: String) -> String:
	var e: String = _salvar()
	if e != "":
		_mensagem(e)
		return ""
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(origem)
	if bytes.is_empty():
		_mensagem("Nao consegui ler o arquivo.")
		return ""
	DirAccess.make_dir_recursive_absolute((_pasta_midia + rel).get_base_dir())
	var f := FileAccess.open(_pasta_midia + rel, FileAccess.WRITE)
	if f == null:
		_mensagem("Nao consegui gravar o arquivo.")
		return ""
	f.store_buffer(bytes)
	f.close()
	Sprites.limpar()
	return rel

func _nome_livre(prefixo: String, ext: String) -> String:
	var n: int = 1
	while FileAccess.file_exists(_pasta_midia + "%s_%d.%s" % [prefixo, n, ext]):
		n += 1
	return "%s_%d.%s" % [prefixo, n, ext]

func _ext(caminho: String, lista: Array, padrao: String) -> String:
	var e: String = caminho.get_extension().to_lower()
	return e if lista.has(e) else padrao

func _slug_golpe() -> String:
	var g: Dictionary = _golpe()
	return "%s_%s" % [str(g["botao"]).to_lower(), Formato.sanitizar_id(str(g["nome"]))]

func _novo_som_golpe(origem: String) -> void:
	if _sel < 0:
		return
	var ext: String = _ext(origem, EXT_SOM, "ogg")
	var rel: String = _importar(origem, "golpes/%s_som.%s" % [_slug_golpe(), ext])
	if rel == "":
		return
	(_golpe()["sons"] as Dictionary)["uso"] = rel
	_atualizar_campos()

func _limpar_som_golpe() -> void:
	if _sel >= 0:
		(_golpe()["sons"] as Dictionary)["uso"] = ""
		_atualizar_campos()

func _limpar_slot(slot: String) -> void:
	((_p["sprites"] as Dictionary)[slot] as Array).clear()
	_atualizar_abas()

func _nova_arte(origem: String, chave: String, prefixo: String) -> void:
	var rel: String = _importar(origem, prefixo + _ext(origem, EXT_IMAGEM, "png"))
	if rel == "":
		return
	_p[chave] = rel
	_atualizar_abas()

func _limpar_arte(chave: String) -> void:
	_p[chave] = ""
	_atualizar_abas()

func _novo_som_evento(origem: String, ev: String) -> void:
	var rel: String = _importar(origem, "sons/%s.%s" % [ev, _ext(origem, EXT_SOM, "ogg")])
	if rel != "":
		_atualizar_abas()

func _limpar_som_evento(ev: String) -> void:
	var f: String = _achar_som_evento(ev)
	if f != "" and f.begins_with("user://"):
		DirAccess.remove_absolute(f)
	_atualizar_abas()

func _ajustar_altura(d: int) -> void:
	_p["altura_px"] = clampi(int(_p["altura_px"]) + d, 40, 600)
	_atualizar_abas()

func _medir_altura() -> void:
	var lista: Array = (_p["sprites"] as Dictionary)["parado"]
	if lista.is_empty():
		_mensagem("Adicione um sprite em 'Parado' para medir a altura.")
		return
	var h: int = Medidas.altura_do_sprite(_pasta_midia + str(lista[0]))
	if h <= 0:
		_mensagem("Nao consegui medir o sprite.")
		return
	_p["altura_px"] = clampi(h, 40, 600)
	_atualizar_abas()

func _texto_tempo(g: Dictionary) -> String:
	var total: int = Formato.total_frames(g)
	var c: Array = Formato.cronograma(g)
	if c.is_empty():
		return "Duracao: %d frames (%.2f s a 60 FPS)." % [total, float(total) / 60.0]
	var partes: PackedStringArray = []
	for i in range(c.size()):
		var it: Dictionary = c[i]
		partes.append("#%d: frames %d-%d (%d)" % [i + 1, int(it["de"]), maxi(int(it["de"]), int(it["ate"]) - 1), int(it["ate"]) - int(it["de"])])
	return "Duracao: %d frames (%.2f s). %s" % [total, float(total) / 60.0, "  ".join(partes)]

# ---------- desenho ----------

func _desenhar_cabecalho(c: Control) -> void:
	var fonte: Font = ThemeDB.fallback_font
	var ic := Rect2(14.0, 12.0, 52.0, 52.0)
	c.draw_rect(ic, Color(0.45, 0.3, 0.85))
	c.draw_rect(ic, Color(0.75, 0.6, 1.0), false, 2.0)
	var p0 := Vector2(26.0, 52.0)
	var p1 := Vector2(54.0, 24.0)
	c.draw_line(p0, p1, Color.WHITE, 6.0)
	c.draw_colored_polygon(PackedVector2Array([p0 + Vector2(-5.0, 3.0), p0 + Vector2(1.0, -3.0), p0 + Vector2(3.0, 5.0)]), Color.WHITE)
	c.draw_string(fonte, Vector2(78.0, 38.0), "CRIADOR DE PERSONAGENS", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 24, Color.WHITE)
	c.draw_string(fonte, Vector2(78.0, 62.0), "Crie, edite e personalize seu lutador!", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, COR_SUAVE)
	c.draw_string(fonte, Vector2(560.0, 28.0), "Nome do Personagem:", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, COR_SUAVE)


func _painel(c: Control, r: Rect2) -> void:
	c.draw_rect(r, COR_PAINEL)
	c.draw_rect(r, COR_BORDA, false, 2.0)


func _tam_sprite() -> String:
	var tex: Texture2D = null
	var parado: Array = (_p["sprites"] as Dictionary)["parado"]
	if parado.size() > 0:
		tex = Sprites.textura(Sprites.caminho_quadro(_pasta_midia, parado, 0))
	if tex == null:
		for g in _p["golpes"]:
			var fr: Array = (g as Dictionary)["frames"]
			if fr.size() > 0:
				tex = Sprites.textura(Sprites.caminho_quadro(_pasta_midia, fr, 0))
				if tex != null:
					break
	if tex == null:
		return "-"
	return "%dx%d" % [int(tex.get_size().x), int(tex.get_size().y)]


func _desenhar_info() -> void:
	var fonte: Font = ThemeDB.fallback_font
	var r := Rect2(Vector2.ZERO, R_INFO.size)
	_painel(_info, r)
	_info.draw_rect(Rect2(2.0, 2.0, r.size.x - 4.0, 36.0), Color(0.16, 0.13, 0.4))
	_info.draw_circle(Vector2(26.0, 16.0), 5.0, COR_SUAVE)
	_info.draw_arc(Vector2(26.0, 32.0), 9.0, PI, TAU, 10, COR_SUAVE, 3.0)
	_info.draw_string(fonte, Vector2(44.0, 27.0), "Informacoes", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, Color(0.8, 0.7, 1.0))
	var anim: int = 0
	var spr: Dictionary = _p["sprites"]
	for slot in Formato.SLOTS:
		if (spr[slot] as Array).size() > 0:
			anim += 1
	var sons: int = 0
	for g in _p["golpes"]:
		if str(((g as Dictionary)["sons"] as Dictionary)["uso"]) != "":
			sons += 1
	for ev in Eventos.TODOS:
		if _achar_som_evento(str(ev)) != "":
			sons += 1
	var linhas: Array = [["Sprite:", _tam_sprite()], ["Animacoes:", "%d / %d" % [anim, Formato.SLOTS.size()]], ["Golpes:", str((_p["golpes"] as Array).size())], ["Sons:", str(sons)]]
	for i in range(linhas.size()):
		var y: float = 48.0 + float(i) * 30.0
		_info.draw_string(fonte, Vector2(18.0, y + 20.0), str(linhas[i][0]), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, COR_TEXTO)
		_info.draw_string(fonte, Vector2(130.0, y + 20.0), str(linhas[i][1]), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, Color(0.85, 0.85, 0.95))
		_info.draw_string(fonte, Vector2(r.size.x - 22.0, y + 20.0), ">", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, COR_SUAVE)
	_info.draw_line(Vector2(14.0, 172.0), Vector2(r.size.x - 14.0, 172.0), Color(1, 1, 1, 0.2), 1.0)
	_info.draw_string(fonte, Vector2(14.0, 186.0), "Toque numa linha para abrir.", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, COR_SUAVE)


func _desenhar_cartao() -> void:
	var fonte: Font = ThemeDB.fallback_font
	_painel(_cartao, Rect2(Vector2.ZERO, R_GOLPE.size))
	var l1: String = "-"
	var l2: String = ""
	var cor2: Color = COR_SUAVE
	if _alvo_slot != "":
		l1 = "Animacao: %s" % str(Formato.ROTULOS_SLOT[_alvo_slot])
		l2 = "%d sprite(s)" % _frames_alvo().size()
	elif _sel >= 0:
		var g: Dictionary = _golpe()
		l1 = "%s - %s%s" % [str(g["botao"]), str(g["nome"]), "  [fixo]" if bool(g["base"]) else ""]
		l2 = "Prioridade #%d de %d" % [_sel + 1, (_p["golpes"] as Array).size()]
		var cob: int = _coberto_por(_sel)
		if cob >= 0:
			l2 = "Nunca sai: coberto pelo #%d" % (cob + 1)
			cor2 = Color(1.0, 0.5, 0.4)
	else:
		l1 = "Nenhum golpe"
		l2 = "Adicione um golpe"
	_cartao.draw_string(fonte, Vector2(12.0, 22.0), l1, HORIZONTAL_ALIGNMENT_LEFT, R_GOLPE.size.x - 24.0, 15, COR_TEXTO)
	_cartao.draw_string(fonte, Vector2(12.0, 44.0), l2, HORIZONTAL_ALIGNMENT_LEFT, R_GOLPE.size.x - 24.0, 13, cor2)


func _textura_do(frames: Array, i: int) -> Texture2D:
	return Sprites.textura(Sprites.caminho_quadro(_pasta_midia, frames, i))


# Sprite mostrado na visualização: o selecionado na timeline (ou o da animação, se estiver testando).
func _textura_atual() -> Texture2D:
	var frames: Array = _frames_alvo()
	if frames.size() > 0:
		var i: int = _q_sel
		if _tocando:
			if _alvo_slot == "" and _sel >= 0:
				var g: Dictionary = _golpe()
				i = Formato.indice_no_tempo(g, _anim_t % maxi(1, Formato.total_frames(g) + 12))
			else:
				i = Formato.indice_ciclo(frames.size(), _anim_t)
		return _textura_do(frames, clampi(i, 0, frames.size() - 1))
	var parado: Array = (_p["sprites"] as Dictionary)["parado"]
	if parado.size() > 0:
		return _textura_do(parado, 0)
	return null


func _desenhar_area() -> void:
	var fonte: Font = ThemeDB.fallback_font
	var tam: Vector2 = R_PREVIA.size
	_area.draw_rect(Rect2(Vector2.ZERO, tam), Color(0.07, 0.07, 0.1))
	var q: float = 16.0
	for y in range(int(tam.y / q) + 1):
		for x in range(int(tam.x / q) + 1):
			if (x + y) % 2 == 0:
				_area.draw_rect(Rect2(float(x) * q, float(y) * q, q, q).intersection(Rect2(Vector2.ZERO, tam)), Color(0.11, 0.11, 0.15))
	_painel(_area, Rect2(Vector2.ZERO, tam))
	var pe := Vector2(tam.x * 0.5, tam.y - 14.0)
	var z: float = 1.0
	var tex: Texture2D = _textura_atual()
	if tex != null:
		var ts: Vector2 = tex.get_size()
		z = clampf((tam.y - 28.0) / maxf(ts.y, 1.0), 0.25, 6.0)
		_area.draw_texture_rect(tex, Rect2(pe.x - ts.x * z * 0.5, pe.y - ts.y * z, ts.x * z, ts.y * z), false)
	else:
		_area.draw_string(fonte, Vector2(0.0, tam.y * 0.5), "Sem sprite. Toque no + da timeline para adicionar.", HORIZONTAL_ALIGNMENT_CENTER, tam.x, 15, COR_SUAVE)
	if _mostrar_caixas and _alvo_slot == "" and _sel >= 0:
		var esc: float = maxf(0.1, float(_p["altura_px"]) / 120.0) * (z if tex != null else 1.0)
		_area.draw_rect(Rect2(pe.x - 25.0 * esc, pe.y - 120.0 * esc, 50.0 * esc, 120.0 * esc), Color(0.3, 0.6, 1.0), false, 2.0)
		var hb: Dictionary = _golpe()["hitbox"]
		var rh := Rect2(pe.x + float(hb["x"]) * esc, pe.y + float(hb["y"]) * esc, float(hb["w"]) * esc, float(hb["h"]) * esc)
		_area.draw_rect(rh, Color(1.0, 0.2, 0.2, 0.4))
		_area.draw_rect(rh, Color(1.0, 0.3, 0.3), false, 2.0)
	var n: int = _frames_alvo().size()
	if n > 0:
		_area.draw_string(fonte, Vector2(12.0, 22.0), "Sprite %d/%d" % [_q_sel + 1, n], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, COR_TEXTO)


func _desenhar_linha() -> void:
	var fonte: Font = ThemeDB.fallback_font
	var tam: Vector2 = R_LINHA.size
	_painel(_linha, Rect2(Vector2.ZERO, tam))
	var n: int = _frames_alvo().size()
	# setas
	_linha.draw_colored_polygon(PackedVector2Array([Vector2(26.0, tam.y * 0.5 - 12.0), Vector2(26.0, tam.y * 0.5 + 12.0), Vector2(12.0, tam.y * 0.5)]), COR_BORDA if _t_off > 0 else Color(0.3, 0.3, 0.4))
	_linha.draw_colored_polygon(PackedVector2Array([Vector2(tam.x - 26.0, tam.y * 0.5 - 12.0), Vector2(tam.x - 26.0, tam.y * 0.5 + 12.0), Vector2(tam.x - 12.0, tam.y * 0.5)]), COR_BORDA if _t_off + 5 < n + 1 else Color(0.3, 0.3, 0.4))
	var crono: Array = []
	var imp: int = -1
	if _alvo_slot == "" and _sel >= 0:
		crono = Formato.cronograma(_golpe())
		imp = int(_golpe()["sprite_impacto"])
	var frames: Array = _frames_alvo()
	for it in _rects_linha():
		var d: Dictionary = it
		var r: Rect2 = d["r"]
		var i: int = int(d["i"])
		if i >= n:
			_linha.draw_rect(r, Color(0.1, 0.09, 0.22))
			_linha.draw_rect(r, COR_BORDA, false, 2.0)
			var c: Vector2 = r.get_center()
			_linha.draw_line(c + Vector2(-14.0, 0.0), c + Vector2(14.0, 0.0), COR_TEXTO, 3.0)
			_linha.draw_line(c + Vector2(0.0, -14.0), c + Vector2(0.0, 14.0), COR_TEXTO, 3.0)
			continue
		_linha.draw_rect(r, Color(0.12, 0.11, 0.26))
		var tex: Texture2D = _textura_do(frames, i)
		if tex != null:
			var ts: Vector2 = tex.get_size()
			var e: float = minf((r.size.x - 8.0) / ts.x, (r.size.y - 8.0) / ts.y)
			var w: Vector2 = ts * e
			_linha.draw_texture_rect(tex, Rect2(r.position.x + (r.size.x - w.x) * 0.5, r.end.y - 4.0 - w.y, w.x, w.y), false)
		var sel: bool = i == _q_sel
		_linha.draw_rect(r, Color.WHITE if sel else COR_BORDA, false, 3.0 if sel else 1.5)
		var legenda: String = "#%d" % (i + 1)
		if i < crono.size():
			var item: Dictionary = crono[i]
			legenda += "  %df" % (int(item["ate"]) - int(item["de"]))
		_linha.draw_string(fonte, Vector2(r.position.x, r.end.y + 14.0), legenda, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 12, COR_SUAVE)
		if i == imp:
			_linha.draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 14.0), Color(0.9, 0.2, 0.2))
			_linha.draw_string(fonte, Vector2(r.position.x, r.position.y + 11.0), "IMPACTO", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 10, Color.WHITE)


func _desenhar_preview(c: Control) -> void:
	c.draw_rect(Rect2(Vector2.ZERO, c.size), Color(0.1, 0.13, 0.24))
	var esc: float = maxf(0.1, float(_p["altura_px"]) / 120.0)
	var visivel: float = 120.0 * esc
	var fator: float = minf(1.0, (c.size.y * 0.8) / maxf(visivel, 1.0))
	var pe := Vector2(c.size.x * 0.35, c.size.y * 0.9)
	c.draw_line(Vector2(0, pe.y), Vector2(c.size.x, pe.y), Color(0.5, 0.5, 0.6), 2.0)
	c.draw_rect(Rect2(pe.x - 25.0 * esc * fator, pe.y - visivel * fator, 50.0 * esc * fator, visivel * fator), Color(0.35, 0.45, 0.7, 0.7))
	if _sel < 0:
		return
	var hb: Dictionary = _golpe()["hitbox"]
	var r := Rect2(pe.x + float(hb["x"]) * esc * fator, pe.y + float(hb["y"]) * esc * fator, float(hb["w"]) * esc * fator, float(hb["h"]) * esc * fator)
	c.draw_rect(r, Color(1, 0.2, 0.2, 0.45))
	c.draw_rect(r, Color(1, 0.3, 0.3), false, 2.0)


# ---------- salvar, backup ----------

func _on_salvar() -> void:
	var e := _salvar()
	_mensagem("Salvo." if e == "" else e)


# Devolve "" se salvou, ou a mensagem de erro.

func _salvar() -> String:
	var nome := _campo_nome.text.strip_edges()
	if nome == "":
		return "De um nome ao personagem."
	_p["nome"] = nome
	if _novo:
		var base: String = Formato.sanitizar_id(nome)
		_p["id"] = Pacote.id_livre(base if base != "" else "personagem")
	var norm: Dictionary = Formato.normalizar(_p)
	if not norm["ok"]:
		return "Nao salvou: " + str(norm["erro"])
	_p = norm["personagem"]
	var pasta := PASTA_USUARIO + str(_p["id"]) + "/"
	DirAccess.make_dir_recursive_absolute(pasta)
	# Personagem do jogo (res://) ou de outra pasta: leva os arquivos junto para a copia do usuario.
	if _pasta_midia != "" and _pasta_midia != pasta:
		_copiar_midia(_pasta_midia, pasta)
	var f := FileAccess.open(pasta + "personagem.json", FileAccess.WRITE)
	if f == null:
		return "Nao consegui gravar neste aparelho."
	f.store_string(JSON.stringify(_p, "\t"))
	f.close()
	_pasta_midia = pasta
	_novo = false
	Sprites.limpar()
	_catalogo().recarregar()
	return ""

func _copiar_midia(de: String, para: String) -> void:
	var dir := DirAccess.open(de)
	if dir == null:
		return
	DirAccess.make_dir_recursive_absolute(para)
	for arq in dir.get_files():
		var nome: String = str(arq)
		if nome.get_extension().to_lower() == "json" or nome.ends_with(".import"):
			continue
		if FileAccess.file_exists(para + nome):
			continue
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(de + nome)
		if bytes.is_empty():
			continue
		var f := FileAccess.open(para + nome, FileAccess.WRITE)
		if f != null:
			f.store_buffer(bytes)
			f.close()
	for sub in dir.get_directories():
		_copiar_midia(de + str(sub) + "/", para + str(sub) + "/")

func _copiar_backup() -> void:
	var e := _salvar()
	if e != "":
		_mensagem(e)
		return
	var r: Dictionary = Pacote.exportar(_p, _pasta_midia)
	if not r["ok"]:
		_mensagem(str(r["erro"]))
		return
	DisplayServer.clipboard_set(str(r["texto"]))
	_mensagem(("Backup copiado. " + str(r["aviso"])).strip_edges())

func _colar_backup() -> void:
	var r: Dictionary = Pacote.importar(DisplayServer.clipboard_get())
	if not r["ok"]:
		_mensagem(str(r["erro"]))
		return
	_catalogo().recarregar()
	_veio_da_lista = true
	_abrir(r["personagem"], str(r["pasta"]), false)
