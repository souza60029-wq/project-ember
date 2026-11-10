extends Control

# Editor de personagem: criar, editar, salvar e fazer backup (BEP1).
# Tela montada em código, com contêineres e rolagem (nada fica cortado).
# Topo: quadro do sprite atual, nome, lista de comandos, "+" para golpes e salvar.
# Abas: Golpes | Sprites | Artes | Sons.
# Golpes fixos (LP, LK, HP, HK, BO): só quadros (sprites), sprite de impacto e som.
# Os frames do golpe são fixos; o motor reparte os sprites pelos frames a 60 FPS.
# Lógica de golpes em Edicao.gd, backup em Pacote.gd, medidas em Medidas.gd.
# Entrada: Menu.modo_editor = "criar" (novo) ou "editar" (lista de personagens).
# Autoloads são acessados por get_node (não pelo nome), para o script compilar sem eles.

const Formato = preload("res://engine/formato/Formato.gd")
const Pacote = preload("res://engine/formato/Pacote.gd")
const Edicao = preload("res://engine/editor/Edicao.gd")
const Medidas = preload("res://engine/formato/Medidas.gd")
const Eventos = preload("res://engine/sons/Eventos.gd")
const Sprites = preload("res://engine/nucleo/Sprites.gd")
const Caixa = preload("res://engine/nucleo/Caixa.gd")
const Menu = preload("res://engine/menu/Menu.gd")

const PASTA_USUARIO := "user://personagens/"
const COR_FUNDO := Color(0.06, 0.08, 0.16)
const COR_PREVIEW := Color(0.1, 0.13, 0.24)
const TAMANHO_QUADRO := Vector2(140, 140)
const TAMANHO_PREVIEW := Vector2(220, 170)
const ALTURA_BOTAO: float = 40.0
const EXT_IMAGEM := ["png", "webp", "jpg", "jpeg"]
const EXT_SOM := ["ogg", "wav", "mp3"]

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


# Botão com ícone desenhado (a fonte padrão não tem ícones).
class BotaoIcone extends Button:
	var tipo: String = "mais"

	func _init(t: String = "mais") -> void:
		tipo = t
		custom_minimum_size = Vector2(52, 40)

	func _draw() -> void:
		var c: Vector2 = size * 0.5
		var cor := Color(1, 1, 1, 0.95)
		if tipo == "mais":
			draw_line(c + Vector2(-10, 0), c + Vector2(10, 0), cor, 3.0)
			draw_line(c + Vector2(0, -10), c + Vector2(0, 10), cor, 3.0)
		else:
			for k in range(3):
				var y: float = c.y - 9.0 + 9.0 * float(k)
				draw_rect(Rect2(c.x - 11.0, y - 1.5, 4.0, 3.0), cor)
				draw_line(Vector2(c.x - 4.0, y), Vector2(c.x + 11.0, y), cor, 3.0)


var _p: Dictionary = {}
var _pasta_midia := ""
var _novo := false
var _veio_da_lista := false
var _sel := -1
var _anim_t := 0
var _tocando := false

var _tela_lista: MarginContainer
var _lista_personagens: VBoxContainer
var _tela_edicao: MarginContainer
var _vb_edicao: VBoxContainer
var _campo_nome: LineEdit
var _quadro: Control
var _abas: TabContainer
var _lista_golpes: VBoxContainer
var _campo_golpe: LineEdit
var _btn_botao: Button
var _btn_carga: Button
var _sec_custom: VBoxContainer
var _lbl_base: Label
var _lbl_quadros: Label
var _lbl_tempo: Label
var _lbl_som: Label
var _btn_testar: Button
var _preview: Control
var _valores := {}
var _specs := {}
var _checks := {}
var _lbl_impacto: Label
var _lbl_altura: Label
var _lbl_slots := {}
var _lbl_eventos := {}
var _lbl_artes := {}
var _msgs: Array[Label] = []
var _fd: FileDialog
var _fd_acao: Callable
var _pop_mais: PopupPanel
var _pop_lista: AcceptDialog
var _pop_lista_texto: Label


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
		_quadro.queue_redraw()


# ---------- montagem da tela ----------

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
	_tela_edicao = _nova_tela()
	_vb_edicao = _tela_edicao.get_child(0) as VBoxContainer

	# Topo: quadro do sprite à esquerda; nome e botões ao lado.
	var topo := HBoxContainer.new()
	_vb_edicao.add_child(topo)
	_quadro = Control.new()
	_quadro.custom_minimum_size = TAMANHO_QUADRO
	_quadro.draw.connect(_desenhar_quadro)
	topo.add_child(_quadro)
	var dir := VBoxContainer.new()
	dir.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	topo.add_child(dir)

	var linha1 := HBoxContainer.new()
	dir.add_child(linha1)
	_campo_nome = LineEdit.new()
	_campo_nome.placeholder_text = "Nome do personagem"
	_campo_nome.custom_minimum_size = Vector2(0, ALTURA_BOTAO)
	_campo_nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	linha1.add_child(_campo_nome)

	var linha2 := HBoxContainer.new()
	dir.add_child(linha2)
	var b_lista := BotaoIcone.new("lista")
	b_lista.tooltip_text = "Lista de comandos"
	b_lista.pressed.connect(_abrir_lista_comandos)
	linha2.add_child(b_lista)
	var b_mais := BotaoIcone.new("mais")
	b_mais.tooltip_text = "Adicionar golpes"
	b_mais.pressed.connect(_abrir_mais)
	linha2.add_child(b_mais)
	linha2.add_child(_botao("Salvar", _on_salvar))

	var linha3 := HBoxContainer.new()
	dir.add_child(linha3)
	linha3.add_child(_botao("Copiar backup", _copiar_backup))
	linha3.add_child(_botao("Voltar", _voltar_edicao))
	_msgs.append(_label_msg(dir))

	_abas = TabContainer.new()
	_abas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_vb_edicao.add_child(_abas)
	_montar_aba_golpes()
	_montar_aba_sprites()
	_montar_aba_artes()
	_montar_aba_sons()
	_tela_edicao.visible = false


func _aba(nome: String) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.name = nome
	_abas.add_child(v)
	return v


func _rolagem(pai: Control) -> VBoxContainer:
	var r := ScrollContainer.new()
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.size_flags_vertical = Control.SIZE_EXPAND_FILL
	r.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pai.add_child(r)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(v)
	return v


func _montar_aba_golpes() -> void:
	var aba: VBoxContainer = _aba("Golpes")
	var corpo := HBoxContainer.new()
	corpo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	aba.add_child(corpo)

	var esq := VBoxContainer.new()
	esq.custom_minimum_size = Vector2(230, 0)
	corpo.add_child(esq)
	var rol := ScrollContainer.new()
	rol.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rol.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	esq.add_child(rol)
	_lista_golpes = VBoxContainer.new()
	_lista_golpes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rol.add_child(_lista_golpes)
	esq.add_child(_linha_botoes([_botao("Sobe", _mover.bind(-1)), _botao("Desce", _mover.bind(1))]))
	esq.add_child(_linha_botoes([_botao("Copiar", _copiar_golpe), _botao("Excluir", _excluir_golpe)]))

	var p: VBoxContainer = _rolagem(corpo)
	_montar_painel(p)


func _montar_painel(p: VBoxContainer) -> void:
	_lbl_base = Label.new()
	_lbl_base.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p.add_child(_lbl_base)

	# Parte editável só em golpes criados por você.
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
	_preview.custom_minimum_size = TAMANHO_PREVIEW
	_preview.draw.connect(_desenhar_preview.bind(_preview))
	hb.add_child(_preview)

	# Sprites do golpe (valem para fixos e criados).
	p.add_child(_rotulo("Sprites do golpe (viram frames a 60 FPS automaticamente)"))
	_lbl_quadros = Label.new()
	_lbl_quadros.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p.add_child(_lbl_quadros)
	p.add_child(_linha_botoes([
		_botao("Adicionar sprite", _escolher_imagem.bind(_novo_quadro_golpe)),
		_botao("Remover ultimo", _remover_quadro),
		_btn_testar_novo(),
	]))
	var li := HBoxContainer.new()
	p.add_child(li)
	var rot := Label.new()
	rot.text = "Sprite do impacto"
	rot.custom_minimum_size = Vector2(150, 0)
	li.add_child(rot)
	li.add_child(_mini("-", _ajustar_impacto.bind(-1)))
	_lbl_impacto = Label.new()
	_lbl_impacto.custom_minimum_size = Vector2(70, 0)
	_lbl_impacto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	li.add_child(_lbl_impacto)
	li.add_child(_mini("+", _ajustar_impacto.bind(1)))
	_lbl_tempo = Label.new()
	_lbl_tempo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p.add_child(_lbl_tempo)

	p.add_child(_rotulo("Som do golpe (fala, grunhido...)"))
	_lbl_som = Label.new()
	p.add_child(_lbl_som)
	p.add_child(_linha_botoes([
		_botao("Escolher som", _escolher_som.bind(_novo_som_golpe)),
		_botao("Limpar som", _limpar_som_golpe),
	]))


func _btn_testar_novo() -> Button:
	_btn_testar = _botao("Testar animacao", _alternar_teste)
	return _btn_testar


func _montar_aba_sprites() -> void:
	var aba: VBoxContainer = _aba("Sprites")
	aba.add_child(_rotulo("Sprites por situacao (cada situacao pode ter varios quadros)"))
	var v: VBoxContainer = _rolagem(aba)
	for slot in Formato.SLOTS:
		var linha := HBoxContainer.new()
		v.add_child(linha)
		var l := Label.new()
		l.custom_minimum_size = Vector2(300, 0)
		linha.add_child(l)
		_lbl_slots[slot] = l
		linha.add_child(_botao("Adicionar", _escolher_imagem.bind(_novo_quadro_slot.bind(str(slot)))))
		linha.add_child(_botao("Limpar", _limpar_slot.bind(str(slot))))


func _montar_aba_artes() -> void:
	var aba: VBoxContainer = _aba("Artes")
	var v: VBoxContainer = _rolagem(aba)
	v.add_child(_rotulo("Arte da tela de selecao (grande) e do card (quadro da grade)"))
	for par in [["arte_selecao", "Arte da selecao", "arte/selecao."], ["arte_card", "Arte do card", "arte/card."]]:
		var linha := HBoxContainer.new()
		v.add_child(linha)
		var l := Label.new()
		l.custom_minimum_size = Vector2(260, 0)
		linha.add_child(l)
		_lbl_artes[str(par[0])] = l
		linha.add_child(_botao("Escolher", _escolher_imagem.bind(_nova_arte.bind(str(par[0]), str(par[2])))))
		linha.add_child(_botao("Limpar", _limpar_arte.bind(str(par[0]))))
	v.add_child(_rotulo("Altura do personagem em pixels (define o tamanho do corpo e dos golpes)"))
	var li := HBoxContainer.new()
	v.add_child(li)
	li.add_child(_mini("-", _ajustar_altura.bind(-10)))
	_lbl_altura = Label.new()
	_lbl_altura.custom_minimum_size = Vector2(100, 0)
	_lbl_altura.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	li.add_child(_lbl_altura)
	li.add_child(_mini("+", _ajustar_altura.bind(10)))
	li.add_child(_botao("Medir pelo sprite parado", _medir_altura))


func _montar_aba_sons() -> void:
	var aba: VBoxContainer = _aba("Sons")
	aba.add_child(_rotulo("Sons do personagem (por evento). O som de cada golpe fica na aba Golpes."))
	var v: VBoxContainer = _rolagem(aba)
	for ev in Eventos.TODOS:
		var linha := HBoxContainer.new()
		v.add_child(linha)
		var l := Label.new()
		l.custom_minimum_size = Vector2(300, 0)
		linha.add_child(l)
		_lbl_eventos[ev] = l
		linha.add_child(_botao("Escolher", _escolher_som.bind(_novo_som_evento.bind(str(ev)))))
		linha.add_child(_botao("Limpar", _limpar_som_evento.bind(str(ev))))


func _montar_popups() -> void:
	_fd = FileDialog.new()
	_fd.access = FileDialog.ACCESS_FILESYSTEM
	_fd.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_fd.file_selected.connect(_on_arquivo)
	add_child(_fd)

	_pop_mais = PopupPanel.new()
	add_child(_pop_mais)
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(340, 0)
	_pop_mais.add_child(v)
	v.add_child(_rotulo("Adicionar golpe"))
	for botao in Formato.BOTOES:
		var nome: String = str((Formato.BASE[botao] as Dictionary)["nome"])
		v.add_child(_botao("%s - %s (fixo)" % [botao, nome], _adicionar_base.bind(str(botao))))
	v.add_child(_botao("Esquiva (so sprites)", _ir_sprite_esquiva))
	v.add_child(_botao("Golpe personalizado", _novo_golpe))
	v.add_child(_botao("Fechar", _pop_mais.hide))

	_pop_lista = AcceptDialog.new()
	_pop_lista.title = "Lista de comandos"
	_pop_lista.ok_button_text = "Fechar"
	add_child(_pop_lista)
	var rol := ScrollContainer.new()
	rol.custom_minimum_size = Vector2(560, 320)
	_pop_lista.add_child(rol)
	_pop_lista_texto = Label.new()
	_pop_lista_texto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rol.add_child(_pop_lista_texto)


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


func _mini(t: String, acao: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(44, ALTURA_BOTAO)
	b.pressed.connect(acao)
	return b


func _botao(texto: String, acao: Callable) -> Button:
	var b := Button.new()
	b.text = texto
	b.custom_minimum_size = Vector2(0, ALTURA_BOTAO)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.clip_text = true
	b.pressed.connect(acao)
	return b


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
	_atualizar_lista_golpes()
	_atualizar_campos()
	_atualizar_abas()


func _atualizar_lista_golpes() -> void:
	_limpar(_lista_golpes)
	var golpes: Array = _p["golpes"]
	for i in range(golpes.size()):
		var g: Dictionary = golpes[i]
		var marca: String = "> " if i == _sel else ""
		var fixo: String = " [fixo]" if bool(g["base"]) else ""
		_lista_golpes.add_child(_botao("%s%s  %s%s" % [marca, str(g["botao"]), str(g["nome"]), fixo], _selecionar.bind(i)))


func _golpe() -> Dictionary:
	return (_p["golpes"] as Array)[_sel]


func _selecionar(i: int) -> void:
	_sel = i
	_anim_t = 0
	_refrescar()


func _atualizar_campos() -> void:
	var tem: bool = _sel >= 0
	_lbl_base.visible = false
	_sec_custom.visible = false
	if not tem:
		_lbl_base.visible = true
		_lbl_base.text = "Nenhum golpe. Use o botao + para adicionar."
		_lbl_quadros.text = ""
		_lbl_tempo.text = ""
		_lbl_impacto.text = "-"
		_lbl_som.text = ""
		_quadro.queue_redraw()
		return
	var g: Dictionary = _golpe()
	if bool(g["base"]):
		_lbl_base.visible = true
		_lbl_base.text = "%s (%s) - golpe fixo. Tempo: %d + %d + %d frames, dano %d. Aqui voce troca so os sprites e o som." % [
			str(g["nome"]), str(g["botao"]), int(g["startup"]), int(g["active"]), int(g["recovery"]), int(g["dano"])]
	else:
		_sec_custom.visible = true
		_campo_golpe.text = str(g["nome"])
		_btn_botao.text = str(g["botao"])
		_btn_carga.text = _texto_carga(str(g["carga"]))
		for c in _valores.keys():
			_mostrar_valor(str(c))
		for chave in _checks.keys():
			(_checks[chave] as CheckBox).set_pressed_no_signal(bool(g[chave]))
	var quadros: Array = g["frames"]
	_lbl_quadros.text = "%d sprite(s): %s" % [quadros.size(), ", ".join(PackedStringArray(quadros.map(func(q): return str(q).get_file())))] if quadros.size() > 0 else "Nenhum sprite ainda."
	var imp: int = int(g["sprite_impacto"])
	_lbl_impacto.text = "auto" if (imp < 0 or imp >= quadros.size()) else "#%d" % (imp + 1)
	_lbl_tempo.text = _texto_tempo(g)
	var som: String = str((g["sons"] as Dictionary)["uso"])
	_lbl_som.text = som.get_file() if som != "" else "(sem som proprio)"
	_preview.queue_redraw()
	_quadro.queue_redraw()


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
		var ok: bool = _achar_som_evento(str(ev)) != ""
		(_lbl_eventos[ev] as Label).text = "%s: %s" % [str(ev), "ok" if ok else "vazio"]
	_quadro.queue_redraw()


func _achar_som_evento(ev: String) -> String:
	for e in EXT_SOM:
		if FileAccess.file_exists(_pasta_midia + "sons/" + ev + "." + str(e)):
			return _pasta_midia + "sons/" + ev + "." + str(e)
	return ""


func _texto_carga(c: String) -> String:
	if c == "tras":
		return "Carga tras"
	if c == "baixo":
		return "Carga baixo"
	return "Sem carga"


# ---------- golpes ----------

func _abrir_mais() -> void:
	_pop_mais.popup_centered()


func _adicionar_base(botao: String) -> void:
	_pop_mais.hide()
	var ja: bool = Edicao.indice_base(_p, botao) >= 0
	var i: int = Edicao.adicionar_base(_p, botao)
	if i < 0:
		_mensagem("Limite de golpes atingido.")
		return
	_sel = i
	_abas.current_tab = 0
	_mensagem("Esse golpe ja existe." if ja else "")
	_refrescar()


func _ir_sprite_esquiva() -> void:
	_pop_mais.hide()
	_abas.current_tab = 1
	_mensagem("Esquiva: adicione os sprites na linha 'Esquiva'. A distancia da esquiva e igual para todos.")


func _novo_golpe() -> void:
	_pop_mais.hide()
	if not Edicao.inserir_golpe(_p, (_p["golpes"] as Array).size()):
		_mensagem("Limite de golpes atingido.")
		return
	_sel = (_p["golpes"] as Array).size() - 1
	_abas.current_tab = 0
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


func _mover(direcao: int) -> void:
	if _sel >= 0 and Edicao.mover_golpe(_p, _sel, direcao):
		_sel += direcao
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


func _ajustar_impacto(d: int) -> void:
	if _sel < 0:
		return
	var g: Dictionary = _golpe()
	var n: int = (g["frames"] as Array).size()
	g["sprite_impacto"] = clampi(int(g["sprite_impacto"]) + d, -1, n - 1)
	_atualizar_campos()


func _alternar_teste() -> void:
	_tocando = not _tocando
	_anim_t = 0
	_btn_testar.text = "Parar teste" if _tocando else "Testar animacao"
	_quadro.queue_redraw()


# ---------- arquivos (sprites, artes, sons) ----------

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


func _novo_quadro_golpe(origem: String) -> void:
	if _sel < 0:
		return
	var rel: String = _importar(origem, _nome_livre("golpes/" + _slug_golpe(), _ext(origem, EXT_IMAGEM, "png")))
	if rel == "":
		return
	var frames: Array = _golpe()["frames"]
	if frames.size() >= Formato.MAX_QUADROS:
		_mensagem("Limite de sprites do golpe.")
		return
	frames.append(rel)
	_refrescar()


func _remover_quadro() -> void:
	if _sel < 0:
		return
	var g: Dictionary = _golpe()
	var frames: Array = g["frames"]
	if frames.size() > 0:
		frames.pop_back()
	g["sprite_impacto"] = clampi(int(g["sprite_impacto"]), -1, frames.size() - 1)
	_refrescar()


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


func _novo_quadro_slot(origem: String, slot: String) -> void:
	var lista: Array = (_p["sprites"] as Dictionary)[slot]
	if lista.size() >= Formato.MAX_QUADROS:
		_mensagem("Limite de sprites.")
		return
	var rel: String = _importar(origem, _nome_livre("sprites/" + slot, _ext(origem, EXT_IMAGEM, "png")))
	if rel == "":
		return
	lista.append(rel)
	if slot == "parado" and lista.size() == 1 and int(_p["altura_px"]) == Formato.ALTURA_PADRAO:
		_medir_altura()
	_atualizar_abas()


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


# ---------- lista de comandos ----------

func _abrir_lista_comandos() -> void:
	var linhas: PackedStringArray = []
	var golpes: Array = _p["golpes"]
	if golpes.is_empty():
		linhas.append("Nenhum golpe ainda.")
	for g in golpes:
		var d: Dictionary = g
		linhas.append("%s - %s%s" % [Formato.comando_texto(d), str(d["nome"]), "  [fixo]" if bool(d["base"]) else ""])
		linhas.append("    dano %d | frames %d+%d+%d | forca %d | custo %d" % [
			int(d["dano"]), int(d["startup"]), int(d["active"]), int(d["recovery"]), int(d["forca"]), int(d["custo"])])
	linhas.append("")
	linhas.append("ESQ - Esquiva (fixa: distancia igual para todos)")
	linhas.append("Para tras no instante do golpe - Just defense (parry)")
	_pop_lista_texto.text = "\n".join(linhas)
	_pop_lista.popup_centered(Vector2i(600, 400))


# ---------- desenho ----------

# Quadro do sprite atual (vazio se o personagem ainda nao tem sprite).
func _desenhar_quadro() -> void:
	_quadro.draw_rect(Rect2(Vector2.ZERO, _quadro.size), COR_PREVIEW)
	_quadro.draw_rect(Rect2(Vector2.ZERO, _quadro.size), Color(1, 1, 1, 0.3), false, 2.0)
	var tex: Texture2D = _textura_atual()
	if tex == null:
		return
	var tam: Vector2 = tex.get_size()
	var esc: float = minf((_quadro.size.x - 8.0) / tam.x, (_quadro.size.y - 8.0) / tam.y)
	var w: Vector2 = tam * esc
	_quadro.draw_texture_rect(tex, Rect2((_quadro.size.x - w.x) * 0.5, _quadro.size.y - 4.0 - w.y, w.x, w.y), false)


func _textura_atual() -> Texture2D:
	if _sel >= 0 and _p["golpes"].size() > _sel:
		var g: Dictionary = _golpe()
		var frames: Array = g["frames"]
		if frames.size() > 0:
			var i: int = 0
			if _tocando:
				var total: int = maxi(1, Formato.total_frames(g) + 12)
				i = Formato.indice_no_tempo(g, _anim_t % total)
			return Sprites.textura(Sprites.caminho_quadro(_pasta_midia, frames, maxi(i, 0)))
	var parado: Array = (_p["sprites"] as Dictionary)["parado"]
	if parado.size() > 0:
		return Sprites.textura(Sprites.caminho_quadro(_pasta_midia, parado, Formato.indice_ciclo(parado.size(), _anim_t)))
	return null


func _desenhar_preview(c: Control) -> void:
	c.draw_rect(Rect2(Vector2.ZERO, c.size), COR_PREVIEW)
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
