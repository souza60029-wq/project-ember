extends Control

# Criador de personagens (celular, paisagem):
#   topo: nome do personagem (centralizado)
#   meio: [Adicionar animação / Adicionar golpe] [retângulo com o sprite] [Lista de golpes / Blocos]
#   baixo: timeline de sprites (+ quadrado de "som no sprite") e os botões Salvar, Voltar, Impacto, Remover, Testar, Mais.
# Cada golpe tem a própria timeline. O som é marcado num sprite e toca quando ele aparece
# (pode haver vários sons no mesmo golpe). Etiqueta de nota nos sprites que têm som.
# Golpes fixos (LP, LK, HP, HK, BO): só sprites e sons. O comportamento do golpe (tempo, dano, alcance,
# movimento, magia, encadeamento...) é feito com BLOCOS (EditorBlocos.gd).
# PRIORIDADE: o motor testa os golpes de cima para baixo e usa o primeiro que combina.
# Entrada: Menu.modo_editor = "criar" (novo) ou "editar" (lista de personagens).
# Autoloads são acessados por get_node (não pelo nome), para o script compilar sem eles.

const Formato = preload("res://engine/formato/Formato.gd")
const Pacote = preload("res://engine/formato/Pacote.gd")
const Edicao = preload("res://engine/editor/Edicao.gd")
const Medidas = preload("res://engine/formato/Medidas.gd")
const Eventos = preload("res://engine/sons/Eventos.gd")
const Sprites = preload("res://engine/nucleo/Sprites.gd")
const Menu = preload("res://engine/menu/Menu.gd")
const Navegador = preload("res://engine/editor/NavegadorArquivos.gd")
const EditorBlocos = preload("res://engine/editor/EditorBlocos.gd")

const PASTA_USUARIO := "user://personagens/"
const COR_FUNDO := Color(0.05, 0.04, 0.12)
const COR_PAINEL := Color(0.08, 0.07, 0.18)
const COR_BORDA := Color(0.55, 0.40, 0.95)
const COR_TEXTO := Color(0.92, 0.9, 1.0)
const COR_SUAVE := Color(0.7, 0.65, 0.9)
const ALTURA_BOTAO: float = 48.0
const FONTE_BOTAO: int = 20
const EXT_IMAGEM := ["png", "webp", "jpg", "jpeg"]
const EXT_SOM := ["ogg", "wav", "mp3"]

# Posições (tela de 960x540)
const R_NOME := Rect2(290.0, 12.0, 380.0, 48.0)
const R_PREVIA := Rect2(206.0, 68.0, 548.0, 240.0)
const R_LINHA := Rect2(14.0, 336.0, 826.0, 118.0)
const R_SOM := Rect2(850.0, 340.0, 96.0, 110.0)
const THUMB := Vector2(86.0, 76.0)
const THUMB_SEL := Vector2(104.0, 90.0)
const VISIVEIS: int = 6


# Botão roxo com ícone desenhado (a fonte padrão não tem ícones).
class BotaoIcone extends Button:
	var tipo: String = "mais"

	func _init(t: String = "mais", texto_btn: String = "") -> void:
		tipo = t
		text = texto_btn
		custom_minimum_size = Vector2(0, 48)

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
		elif tipo == "som_g":
			# nota musical grande, no alto do quadrado
			var n := Vector2(size.x * 0.5, size.y * 0.34)
			draw_circle(n + Vector2(-8, 12), 8.0, cor)
			draw_line(n + Vector2(-1, 12), n + Vector2(-1, -16), cor, 4.0)
			draw_line(n + Vector2(-1, -16), n + Vector2(14, -10), cor, 4.0)


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
var _cartao: Control
var _linha: Control
var _btn_testar: Button
var _btn_impacto: Button
var _lbl_tempo: Label
var _lbl_slots := {}
var _lbl_eventos := {}
var _lbl_artes := {}
var _lbl_altura: Label
var _lista_golpes: VBoxContainer
var _lista_sons_golpe: VBoxContainer
var _msgs: Array[Label] = []
var _fd: FileDialog
var _fd_acao: Callable
var _fd_varios: bool = false
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


# ---------- montagem ----------

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

	# Nome do personagem: centro superior, sem encostar no topo.
	_campo_nome = LineEdit.new()
	_campo_nome.placeholder_text = "Nome do personagem"
	_campo_nome.position = R_NOME.position
	_campo_nome.size = R_NOME.size
	_campo_nome.max_length = 40
	_campo_nome.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_campo_nome.add_theme_font_size_override("font_size", 24)
	_tela_edicao.add_child(_campo_nome)

	# Coluna da esquerda: animação, golpe e o cartão do que está sendo editado.
	_tela_edicao.add_child(_botao_em("Adicionar\nanimacao", "", Rect2(14.0, 68.0, 180.0, 64.0), _abrir_pop.bind("slots")))
	_tela_edicao.add_child(_botao_em("Adicionar\ngolpe", "mais", Rect2(14.0, 140.0, 180.0, 64.0), _abrir_mais))
	_cartao = Control.new()
	_cartao.position = Vector2(14.0, 212.0)
	_cartao.size = Vector2(180.0, 96.0)
	_cartao.draw.connect(_desenhar_cartao)
	_tela_edicao.add_child(_cartao)

	# Retângulo deitado com o sprite selecionado.
	_area = Control.new()
	_area.position = R_PREVIA.position
	_area.size = R_PREVIA.size
	_area.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_area.draw.connect(_desenhar_area)
	_tela_edicao.add_child(_area)

	# Coluna da direita: lista de golpes e blocos.
	_tela_edicao.add_child(_botao_em("Lista de\ngolpes", "lista", Rect2(766.0, 68.0, 180.0, 64.0), _abrir_lista))
	_tela_edicao.add_child(_botao_em("Blocos\ndo golpe", "", Rect2(766.0, 140.0, 180.0, 64.0), _abrir_blocos))
	_lbl_tempo = Label.new()
	_lbl_tempo.position = Vector2(766.0, 212.0)
	_lbl_tempo.size = Vector2(180.0, 96.0)
	_lbl_tempo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_tempo.add_theme_font_size_override("font_size", 13)
	_lbl_tempo.add_theme_color_override("font_color", COR_SUAVE)
	_tela_edicao.add_child(_lbl_tempo)

	# Mensagens
	var msg := Label.new()
	msg.position = Vector2(206.0, 310.0)
	msg.size = Vector2(548.0, 24.0)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.clip_text = true
	msg.add_theme_font_size_override("font_size", 14)
	msg.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))
	_tela_edicao.add_child(msg)
	_msgs.append(msg)

	# Timeline e quadrado do som.
	_linha = Control.new()
	_linha.position = R_LINHA.position
	_linha.size = R_LINHA.size
	_linha.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_linha.draw.connect(_desenhar_linha)
	_linha.gui_input.connect(_on_linha_input)
	_tela_edicao.add_child(_linha)
	_tela_edicao.add_child(_botao_em("\n\n\n+ som", "som_g", R_SOM, _som_do_golpe))

	# Botões de baixo.
	var nomes: Array = ["Salvar", "Voltar", "Impacto", "Remover", "Testar", "Mais"]
	var acoes: Array = [_on_salvar, _voltar_edicao, _alternar_impacto, _remover_quadro, _alternar_teste, _abrir_extras]
	for i in range(nomes.size()):
		var b: Button = _botao_em(str(nomes[i]), "", Rect2(10.0 + float(i) * 158.0, 464.0, 150.0, 56.0), acoes[i])
		_tela_edicao.add_child(b)
		if nomes[i] == "Impacto":
			_btn_impacto = b
		elif nomes[i] == "Testar":
			_btn_testar = b
	_tela_edicao.visible = false


func _estilizar(b: Button) -> void:
	for par in [["normal", Color(0.14, 0.11, 0.32)], ["hover", Color(0.2, 0.15, 0.42)], ["pressed", Color(0.3, 0.2, 0.6)], ["disabled", Color(0.1, 0.09, 0.2)]]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = par[1]
		sb.border_color = COR_BORDA
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(8)
		sb.content_margin_left = 12.0
		sb.content_margin_right = 12.0
		b.add_theme_stylebox_override(str(par[0]), sb)
	b.add_theme_color_override("font_color", COR_TEXTO)
	b.add_theme_font_size_override("font_size", FONTE_BOTAO)


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
	b.custom_minimum_size = Vector2(56, ALTURA_BOTAO)
	_estilizar(b)
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

# ---------- janelas (popups) ----------

func _novo_popup(nome: String, titulo: String, tam: Vector2i) -> VBoxContainer:
	var pop := PopupPanel.new()
	pop.set_meta("tam", tam)
	add_child(pop)
	var v := VBoxContainer.new()
	pop.add_child(v)
	v.add_child(_rotulo(titulo))
	var rol := ScrollContainer.new()
	rol.custom_minimum_size = Vector2(float(tam.x) - 24.0, float(tam.y) - 100.0)
	rol.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rol.scroll_deadzone = 12
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
	_fd.min_size = Vector2i(760, 420)
	_fd.theme = _tema_grande()
	_fd.file_selected.connect(_on_arquivo)
	_fd.files_selected.connect(_on_arquivos)
	add_child(_fd)

	# Adicionar golpe
	var mais: VBoxContainer = _novo_popup("mais", "Adicionar golpe", Vector2i(520, 520))
	for botao in Formato.BOTOES:
		var nome: String = str((Formato.BASE[botao] as Dictionary)["nome"])
		mais.add_child(_botao("%s - %s (fixo)" % [botao, nome], _adicionar_base.bind(str(botao))))
	mais.add_child(_botao("Esquiva (so sprites)", _ir_sprite_esquiva))
	mais.add_child(_botao("Golpe personalizado", _novo_golpe))

	# Lista de golpes (com prioridade)
	_lista_golpes = _novo_popup("lista", "Lista de Golpes", Vector2i(820, 500))

	# Animações (sprites por situação)
	var an: VBoxContainer = _novo_popup("slots", "Animacoes do personagem", Vector2i(720, 500))
	an.add_child(_rotulo("Escolha uma animacao para editar na timeline."))
	for slot in Formato.SLOTS:
		var linha := HBoxContainer.new()
		an.add_child(linha)
		var l := Label.new()
		l.custom_minimum_size = Vector2(340, 0)
		l.add_theme_font_size_override("font_size", 18)
		linha.add_child(l)
		_lbl_slots[slot] = l
		linha.add_child(_botao("Editar", _editar_slot.bind(str(slot))))
		linha.add_child(_botao("Limpar", _limpar_slot.bind(str(slot))))

	# Sons por evento
	var so: VBoxContainer = _novo_popup("sons", "Sons do personagem", Vector2i(720, 500))
	so.add_child(_rotulo("Sons por evento. Sons dos golpes: botao de nota musical, no sprite."))
	for ev in Eventos.TODOS:
		var linha2 := HBoxContainer.new()
		so.add_child(linha2)
		var l2 := Label.new()
		l2.custom_minimum_size = Vector2(340, 0)
		l2.add_theme_font_size_override("font_size", 18)
		linha2.add_child(l2)
		_lbl_eventos[ev] = l2
		linha2.add_child(_botao("Escolher", _escolher_som.bind(_novo_som_evento.bind(str(ev)))))
		linha2.add_child(_botao("Limpar", _limpar_som_evento.bind(str(ev))))

	# Artes, medidas e backup
	var ar: VBoxContainer = _novo_popup("artes", "Artes, medidas e backup", Vector2i(720, 500))
	ar.add_child(_rotulo("Arte da selecao (grande) e do card (retangulo vertical da grade)"))
	for par in [["arte_selecao", "arte/selecao."], ["arte_card", "arte/card."]]:
		var li := HBoxContainer.new()
		ar.add_child(li)
		var l3 := Label.new()
		l3.custom_minimum_size = Vector2(300, 0)
		l3.add_theme_font_size_override("font_size", 18)
		li.add_child(l3)
		_lbl_artes[str(par[0])] = l3
		li.add_child(_botao("Escolher", _escolher_imagem.bind(_nova_arte.bind(str(par[0]), str(par[1])))))
		li.add_child(_botao("Limpar", _limpar_arte.bind(str(par[0]))))
	ar.add_child(_rotulo("Altura do personagem em pixels (define o corpo e a escala dos golpes)"))
	var la := HBoxContainer.new()
	ar.add_child(la)
	la.add_child(_mini("-", _ajustar_altura.bind(-10)))
	_lbl_altura = Label.new()
	_lbl_altura.custom_minimum_size = Vector2(110, 0)
	_lbl_altura.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_altura.add_theme_font_size_override("font_size", 20)
	la.add_child(_lbl_altura)
	la.add_child(_mini("+", _ajustar_altura.bind(10)))
	la.add_child(_botao("Medir pelo sprite parado", _medir_altura))
	ar.add_child(_linha_botoes([_botao("Copiar backup", _copiar_backup), _botao("Colar backup", _colar_backup)]))

	# Mais
	var ex: VBoxContainer = _novo_popup("extras", "Mais", Vector2i(520, 520))
	ex.add_child(_botao("Mostrar / ocultar caixas", _alternar_caixas_e_fechar))
	ex.add_child(_botao("Sons deste golpe", _abrir_sons_golpe))
	ex.add_child(_botao("Animacoes", _abrir_animacoes))
	ex.add_child(_botao("Sons do personagem", _abrir_sons_pers))
	ex.add_child(_botao("Artes, medidas e backup", _abrir_artes))

	# Sons deste golpe (por sprite)
	_lista_sons_golpe = _novo_popup("sons_golpe", "Sons deste golpe", Vector2i(720, 460))




func _tema_grande() -> Theme:
	var t := Theme.new()
	t.default_font_size = 24
	for estado in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.2, 0.18, 0.4) if estado != "pressed" else Color(0.35, 0.25, 0.7)
		sb.border_color = COR_BORDA
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(8)
		sb.content_margin_left = 22.0
		sb.content_margin_right = 22.0
		sb.content_margin_top = 16.0
		sb.content_margin_bottom = 16.0
		t.set_stylebox(estado, "Button", sb)
	for tipo in ["Button", "LineEdit", "ItemList", "Tree", "OptionButton", "Label"]:
		t.set_font_size("font_size", tipo, 24)
	t.set_constant("v_separation", "ItemList", 16)
	t.set_constant("v_separation", "Tree", 16)
	return t


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
	_atualizar_abas()
	_atualizar_tempo()
	_garantir_visivel()
	_redesenhar()


func _redesenhar() -> void:
	_area.queue_redraw()
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

func _atualizar_abas() -> void:
	var sprites: Dictionary = _p["sprites"]
	for slot in Formato.SLOTS:
		var n: int = (sprites[slot] as Array).size()
		(_lbl_slots[slot] as Label).text = "%s: %s" % [str(Formato.ROTULOS_SLOT[slot]), ("%d sprite(s)" % n) if n > 0 else "vazio"]
	for k in _lbl_artes.keys():
		var rel: String = str(_p[k])
		(_lbl_artes[k] as Label).text = "%s: %s" % ["Arte selecao" if k == "arte_selecao" else "Arte card", rel.get_file() if rel != "" else "vazio"]
	_lbl_altura.text = "%d px" % int(_p["altura_px"])
	for ev in Eventos.TODOS:
		(_lbl_eventos[ev] as Label).text = "%s: %s" % [str(ev), "ok" if _achar_som_evento(str(ev)) != "" else "vazio"]


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
	_btn_impacto.disabled = not (_alvo_slot == "" and _sel >= 0)


func _achar_som_evento(ev: String) -> String:
	for e in EXT_SOM:
		if FileAccess.file_exists(_pasta_midia + "sons/" + ev + "." + str(e)):
			return _pasta_midia + "sons/" + ev + "." + str(e)
	return ""

# ---------- ações dos botões ----------

func _abrir_mais() -> void:
	_abrir_pop("mais")


func _abrir_lista() -> void:
	_reconstruir_lista()
	_abrir_pop("lista")


func _abrir_extras() -> void:
	_abrir_pop("extras")


func _abrir_animacoes() -> void:
	_fechar_pop("extras")
	_abrir_pop("slots")


func _abrir_sons_pers() -> void:
	_fechar_pop("extras")
	_abrir_pop("sons")


func _abrir_artes() -> void:
	_fechar_pop("extras")
	_abrir_pop("artes")


func _alternar_caixas_e_fechar() -> void:
	_fechar_pop("extras")
	_alternar_caixas()


# Editor de blocos (tempo, dano, alcance, movimento, magia, encadeamento).
func _abrir_blocos() -> void:
	if _alvo_slot != "" or _sel < 0:
		_mensagem("Escolha um golpe (Lista de Golpes) para editar os blocos.")
		return
	var ed = EditorBlocos.new()
	ed.fechado.connect(_ao_fechar_blocos)
	add_child(ed)
	ed.abrir(_golpe(), _p, _pasta_midia)


func _ao_fechar_blocos() -> void:
	_refrescar()


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
	_abrir_blocos()


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

# ---------- timeline (sprites do golpe ou da animação em edição) ----------

func _frames_alvo() -> Array:
	if _alvo_slot != "":
		return (_p["sprites"] as Dictionary)[_alvo_slot]
	if _sel >= 0:
		return _golpe()["frames"]
	return []

func _alvo_editavel() -> bool:
	return _alvo_slot != "" or _sel >= 0

func _novos_quadros(caminhos: PackedStringArray) -> void:
	for c in caminhos:
		_novo_quadro(str(c))

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

# Tirar um sprite também tira os sons dele e reajusta os números dos outros sprites.
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
		var novos: Array = []
		for s in g["sons_quadros"]:
			var d: Dictionary = s
			if int(d["quadro"]) == _q_sel:
				continue
			if int(d["quadro"]) > _q_sel:
				d["quadro"] = int(d["quadro"]) - 1
			novos.append(d)
		g["sons_quadros"] = novos
	_q_sel = clampi(_q_sel, 0, maxi(0, frames.size() - 1))
	_refrescar()


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

# Som no sprite selecionado: toca quando esse sprite aparece. Pode ter vários sons no mesmo golpe.
func _som_do_golpe() -> void:
	if _alvo_slot != "" or _sel < 0:
		_mensagem("Escolha um golpe para colocar som. Sons de eventos: Mais > Sons do personagem.")
		return
	if _frames_alvo().is_empty():
		_mensagem("Adicione um sprite ao golpe primeiro.")
		return
	_escolher_som(_novo_som_quadro)


func _novo_som_quadro(origem: String) -> void:
	if _sel < 0:
		return
	var quadro: int = _q_sel
	var rel: String = _importar(origem, _nome_livre("golpes/%s_q%d" % [_slug_golpe(), quadro + 1], _ext(origem, EXT_SOM, "ogg")))
	if rel == "":
		return
	var sons: Array = _golpe()["sons_quadros"]
	if sons.size() >= Formato.MAX_SONS_QUADROS:
		_mensagem("Limite de sons do golpe.")
		return
	sons.append({"quadro": quadro, "arquivo": rel})
	_mensagem("Som no sprite #%d." % (quadro + 1))
	_refrescar()


func _abrir_sons_golpe() -> void:
	_fechar_pop("extras")
	if _alvo_slot != "" or _sel < 0:
		_mensagem("Escolha um golpe para ver os sons dele.")
		return
	_reconstruir_sons_golpe()
	_abrir_pop("sons_golpe")


func _reconstruir_sons_golpe() -> void:
	_limpar(_lista_sons_golpe)
	var sons: Array = _golpe()["sons_quadros"]
	if sons.is_empty():
		_lista_sons_golpe.add_child(_rotulo("Nenhum som neste golpe. Selecione um sprite na timeline e toque na nota musical."))
	for i in range(sons.size()):
		var d: Dictionary = sons[i]
		var linha := HBoxContainer.new()
		_lista_sons_golpe.add_child(linha)
		var l := Label.new()
		l.text = "Sprite #%d: %s" % [int(d["quadro"]) + 1, str(d["arquivo"]).get_file()]
		l.custom_minimum_size = Vector2(440, 0)
		l.clip_text = true
		l.add_theme_font_size_override("font_size", 18)
		linha.add_child(l)
		linha.add_child(_botao("Remover", _remover_som.bind(i)))


func _remover_som(i: int) -> void:
	var sons: Array = _golpe()["sons_quadros"]
	if i >= 0 and i < sons.size():
		sons.remove_at(i)
	_reconstruir_sons_golpe()
	_refrescar()


# Quantos sons o golpe tem no sprite "i".
func _sons_no_quadro(i: int) -> int:
	if _alvo_slot != "" or _sel < 0:
		return 0
	var n: int = 0
	for s in _golpe()["sons_quadros"]:
		if int((s as Dictionary)["quadro"]) == i:
			n += 1
	return n


func _garantir_visivel() -> void:
	var n: int = _frames_alvo().size()
	_q_sel = clampi(_q_sel, 0, maxi(0, n - 1))
	if _q_sel < _t_off:
		_t_off = _q_sel
	elif _q_sel > _t_off + VISIVEIS - 1:
		_t_off = _q_sel - VISIVEIS + 1
	_t_off = clampi(_t_off, 0, maxi(0, n + 1 - VISIVEIS))


# Retângulos das miniaturas visíveis: [{"r": Rect2, "i": int}] (i == quantidade de sprites = botão "+").
func _rects_linha() -> Array:
	var r: Array = []
	var n: int = _frames_alvo().size()
	var x: float = 48.0
	var i: int = _t_off
	while i <= n and i < _t_off + VISIVEIS + 1:
		var sel: bool = i == _q_sel and i < n
		var tam: Vector2 = THUMB_SEL if sel else THUMB
		if x + tam.x > R_LINHA.size.x - 44.0:
			break
		r.append({"r": Rect2(x, (R_LINHA.size.y - 20.0 - tam.y) * 0.5 + 4.0, tam.x, tam.y), "i": i})
		x += tam.x + 10.0
		i += 1
	return r


func _on_linha_input(ev: InputEvent) -> void:
	var mb := ev as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	var p: Vector2 = mb.position
	var n: int = _frames_alvo().size()
	if p.x < 44.0:
		_t_off = maxi(0, _t_off - 1)
	elif p.x > R_LINHA.size.x - 44.0:
		_t_off = mini(maxi(0, n + 1 - VISIVEIS), _t_off + 1)
	else:
		for it in _rects_linha():
			var d: Dictionary = it
			if (d["r"] as Rect2).has_point(p):
				if int(d["i"]) >= n:
					if _alvo_editavel():
						_escolher_imagens(_novos_quadros)
					else:
						_mensagem("Adicione um golpe primeiro (botao Adicionar golpe).")
				else:
					_q_sel = int(d["i"])
					_atualizar_tempo()
					_area.queue_redraw()
				break
	_linha.queue_redraw()


func _escolher_imagem(depois: Callable) -> void:
	_abrir_dialogo("Escolher imagem", PackedStringArray(["*.png, *.webp, *.jpg, *.jpeg ; Imagens"]), depois, false)


# Vários sprites de uma vez (a ordem segue o nome do arquivo).

func _escolher_imagens(depois: Callable) -> void:
	_abrir_dialogo("Escolher sprites", PackedStringArray(["*.png, *.webp, *.jpg, *.jpeg ; Imagens"]), depois, true)

func _escolher_som(depois: Callable) -> void:
	_abrir_dialogo("Escolher som", PackedStringArray(["*.ogg, *.wav, *.mp3 ; Sons"]), depois, false)

# Usa o seletor de arquivos do sistema (iOS, Android, desktop) quando o Godot tem esse recurso
# (Godot 4.3 ou mais novo); no 4.2 cai no seletor do próprio Godot, também com seleção múltipla.

# Android e desktop: explorador de arquivos do sistema (botões grandes). iOS: navegador do app,
# que mostra as pastas do app (o iOS só deixa o app ler o que está na pasta dele).
func _abrir_dialogo(titulo: String, filtros: PackedStringArray, depois: Callable, varios: bool = false) -> void:
	_fd_acao = depois
	_fd_varios = varios
	if OS.get_name() == "iOS":
		var exts: Array = []
		var corpo: String = str(filtros[0]).split(";")[0]
		for e in corpo.split(","):
			var limpo: String = str(e).strip_edges().trim_prefix("*.").to_lower()
			if limpo != "":
				exts.append(limpo)
		var nav = Navegador.new()
		nav.escolhido.connect(_on_arquivos)
		add_child(nav)
		nav.abrir(titulo, exts, varios)
		return
	_fd.title = titulo
	_fd.filters = filtros
	_fd.file_mode = FileDialog.FILE_MODE_OPEN_FILES if varios else FileDialog.FILE_MODE_OPEN_FILE
	if "use_native_dialog" in _fd:
		_fd.set("use_native_dialog", false)
	_fd.popup_centered_ratio(0.95)


func _on_arquivo(caminho: String) -> void:
	if _fd_acao.is_valid() and not _fd_varios:
		_fd_acao.call(caminho)

func _on_arquivos(caminhos: PackedStringArray) -> void:
	if not _fd_acao.is_valid():
		return
	var lista: Array = Array(caminhos)
	lista.sort_custom(func(a, b): return str(a).naturalnocasecmp_to(str(b)) < 0)
	if _fd_varios:
		_fd_acao.call(PackedStringArray(lista))
	elif not lista.is_empty():
		_fd_acao.call(str(lista[0]))

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

func _limpar_slot(slot: String) -> void:
	((_p["sprites"] as Dictionary)[slot] as Array).clear()
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

func _painel(c: Control, r: Rect2) -> void:
	c.draw_rect(r, COR_PAINEL)
	c.draw_rect(r, COR_BORDA, false, 2.0)


func _desenhar_cartao() -> void:
	var fonte: Font = ThemeDB.fallback_font
	_painel(_cartao, Rect2(Vector2.ZERO, _cartao.size))
	var l1: String = "-"
	var l2: String = ""
	var cor2: Color = COR_SUAVE
	if _alvo_slot != "":
		l1 = str(Formato.ROTULOS_SLOT[_alvo_slot])
		l2 = "Animacao - %d sprite(s)" % _frames_alvo().size()
	elif _sel >= 0:
		var g: Dictionary = _golpe()
		l1 = "%s  %s" % [str(g["botao"]), str(g["nome"])]
		l2 = "Prioridade %d/%d%s" % [_sel + 1, (_p["golpes"] as Array).size(), "  [fixo]" if bool(g["base"]) else ""]
		var cob: int = _coberto_por(_sel)
		if cob >= 0:
			l2 = "Nunca sai: coberto pelo #%d" % (cob + 1)
			cor2 = Color(1.0, 0.5, 0.4)
	else:
		l1 = "Nenhum golpe"
		l2 = "Toque em Adicionar golpe"
	_cartao.draw_string(fonte, Vector2(10.0, 30.0), l1, HORIZONTAL_ALIGNMENT_LEFT, _cartao.size.x - 20.0, 18, COR_TEXTO)
	_cartao.draw_string(fonte, Vector2(10.0, 56.0), l2, HORIZONTAL_ALIGNMENT_LEFT, _cartao.size.x - 20.0, 14, cor2)
	_cartao.draw_string(fonte, Vector2(10.0, 80.0), "Editando", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, COR_SUAVE)


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
		_area.draw_string(fonte, Vector2(0.0, tam.y * 0.5), "Sem sprite. Toque no + da timeline.", HORIZONTAL_ALIGNMENT_CENTER, tam.x, 18, COR_SUAVE)
	if _mostrar_caixas and _alvo_slot == "" and _sel >= 0:
		var esc: float = maxf(0.1, float(_p["altura_px"]) / 120.0) * (z if tex != null else 1.0)
		_area.draw_rect(Rect2(pe.x - 25.0 * esc, pe.y - 120.0 * esc, 50.0 * esc, 120.0 * esc), Color(0.3, 0.6, 1.0), false, 2.0)
		var hb: Dictionary = _golpe()["hitbox"]
		var rh := Rect2(pe.x + float(hb["x"]) * esc, pe.y + float(hb["y"]) * esc, float(hb["w"]) * esc, float(hb["h"]) * esc)
		_area.draw_rect(rh, Color(1.0, 0.2, 0.2, 0.4))
		_area.draw_rect(rh, Color(1.0, 0.3, 0.3), false, 2.0)
	var n: int = _frames_alvo().size()
	if n > 0:
		_area.draw_string(fonte, Vector2(12.0, 24.0), "Sprite %d/%d" % [_q_sel + 1, n], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, COR_TEXTO)


func _desenhar_linha() -> void:
	var fonte: Font = ThemeDB.fallback_font
	var tam: Vector2 = R_LINHA.size
	_painel(_linha, Rect2(Vector2.ZERO, tam))
	var n: int = _frames_alvo().size()
	var ym: float = (tam.y - 20.0) * 0.5 + 4.0
	_linha.draw_colored_polygon(PackedVector2Array([Vector2(32.0, ym - 16.0), Vector2(32.0, ym + 16.0), Vector2(12.0, ym)]), COR_BORDA if _t_off > 0 else Color(0.3, 0.3, 0.4))
	_linha.draw_colored_polygon(PackedVector2Array([Vector2(tam.x - 32.0, ym - 16.0), Vector2(tam.x - 32.0, ym + 16.0), Vector2(tam.x - 12.0, ym)]), COR_BORDA if _t_off + VISIVEIS < n + 1 else Color(0.3, 0.3, 0.4))
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
			_linha.draw_line(c + Vector2(-16.0, 0.0), c + Vector2(16.0, 0.0), COR_TEXTO, 4.0)
			_linha.draw_line(c + Vector2(0.0, -16.0), c + Vector2(0.0, 16.0), COR_TEXTO, 4.0)
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
		_linha.draw_string(fonte, Vector2(r.position.x, r.end.y + 16.0), legenda, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 14, COR_SUAVE)
		if i == imp:
			_linha.draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 16.0), Color(0.9, 0.2, 0.2))
			_linha.draw_string(fonte, Vector2(r.position.x, r.position.y + 13.0), "IMPACTO", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 11, Color.WHITE)
		# Etiqueta de som: nota musical no canto do sprite que tem som.
		var ns: int = _sons_no_quadro(i)
		if ns > 0:
			var cb := Vector2(r.end.x - 14.0, r.end.y - 14.0)
			_linha.draw_circle(cb, 12.0, Color(1.0, 0.55, 0.2))
			_linha.draw_circle(cb + Vector2(-3.0, 4.0), 3.2, Color.WHITE)
			_linha.draw_line(cb + Vector2(0.0, 4.0), cb + Vector2(0.0, -6.0), Color.WHITE, 2.0)
			_linha.draw_line(cb + Vector2(0.0, -6.0), cb + Vector2(5.0, -3.0), Color.WHITE, 2.0)
			if ns > 1:
				_linha.draw_string(fonte, cb + Vector2(-20.0, -10.0), "x%d" % ns, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, Color(1.0, 0.8, 0.5))


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
