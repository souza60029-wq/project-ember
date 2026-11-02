extends Control

# Editor de personagem: criar, editar, salvar e fazer backup (BEP1).
# Tela montada em código. Lógica de golpes em Edicao.gd, backup em Pacote.gd.
# Entrada: Menu.modo_editor = "criar" (novo) ou "editar" (lista de personagens).

const Formato = preload("res://engine/formato/Formato.gd")
const Pacote = preload("res://engine/formato/Pacote.gd")
const Edicao = preload("res://engine/editor/Edicao.gd")
const Caixa = preload("res://engine/nucleo/Caixa.gd")
const Menu = preload("res://engine/menu/Menu.gd")

const PASTA_USUARIO := "user://personagens/"
const COR_FUNDO := Color(0.06, 0.08, 0.16)
const COR_PREVIEW := Color(0.1, 0.13, 0.24)
const TAMANHO_PREVIEW := Vector2(300, 260)

# c = caminho no golpe ("dano" ou "hitbox.x"), r = rótulo, p = passo, min/max, int = inteiro
const NUMERICOS := [
	{"c": "startup", "r": "Startup", "p": 1.0, "min": 0.0, "max": 99.0, "int": true},
	{"c": "active", "r": "Active", "p": 1.0, "min": 1.0, "max": 99.0, "int": true},
	{"c": "recovery", "r": "Recovery", "p": 1.0, "min": 0.0, "max": 199.0, "int": true},
	{"c": "forca", "r": "Força (1-3)", "p": 1.0, "min": 1.0, "max": 3.0, "int": true},
	{"c": "dano", "r": "Dano", "p": 10.0, "min": 0.0, "max": 999.0, "int": true},
	{"c": "custo", "r": "Custo barra", "p": 10.0, "min": 0.0, "max": 300.0, "int": true},
	{"c": "energia_ganha", "r": "Barra ganha", "p": 10.0, "min": 0.0, "max": 300.0, "int": true},
	{"c": "carga_seg", "r": "Carga (seg)", "p": 0.1, "min": 0.0, "max": 3.0, "int": false},
]
const HITBOX := [
	{"c": "hitbox.x", "r": "Hitbox X", "p": 5.0, "min": -300.0, "max": 300.0, "int": true},
	{"c": "hitbox.y", "r": "Hitbox Y", "p": 5.0, "min": -300.0, "max": 0.0, "int": true},
	{"c": "hitbox.w", "r": "Hitbox largura", "p": 5.0, "min": 0.0, "max": 300.0, "int": true},
	{"c": "hitbox.h", "r": "Hitbox altura", "p": 5.0, "min": 0.0, "max": 300.0, "int": true},
]
const FLAGS := [["antichao", "Anti-chão"], ["blowoff", "Blow Off"], ["so_ar", "Só no ar"]]

var _p: Dictionary = {}
var _pasta_midia := ""
var _novo := false
var _veio_da_lista := false
var _sel := -1

var _tela_lista: MarginContainer
var _vb_lista: VBoxContainer
var _lista_personagens: VBoxContainer
var _tela_edicao: MarginContainer
var _vb_edicao: VBoxContainer
var _campo_nome: LineEdit
var _lista_golpes: VBoxContainer
var _painel: VBoxContainer
var _campo_golpe: LineEdit
var _btn_botao: Button
var _btn_carga: Button
var _preview: Control
var _valores := {}
var _specs := {}
var _checks := {}
var _msgs: Array[Label] = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var fundo := ColorRect.new()
	fundo.color = COR_FUNDO
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)
	_montar_lista()
	_montar_edicao()
	if Menu.modo_editor == "criar":
		_novo_personagem()
	else:
		_mostrar_lista()


# ---------- montagem da tela ----------

func _nova_tela() -> MarginContainer:
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for lado in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		m.add_theme_constant_override(lado, 12)
	add_child(m)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_EXPAND_FILL
	m.add_child(v)
	return m


func _montar_lista() -> void:
	_tela_lista = _nova_tela()
	_vb_lista = _tela_lista.get_child(0) as VBoxContainer
	_vb_lista.add_child(_titulo("Personagens"))
	var rolagem := ScrollContainer.new()
	rolagem.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_vb_lista.add_child(rolagem)
	_lista_personagens = VBoxContainer.new()
	_lista_personagens.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rolagem.add_child(_lista_personagens)
	_vb_lista.add_child(_linha_botoes([
		_botao("Novo personagem", _novo_personagem),
		_botao("Colar backup", _colar_backup),
		_botao("Voltar", Navegacao.ir_para_menu),
	]))
	_msgs.append(_label_msg(_vb_lista))
	_tela_lista.visible = false


func _montar_edicao() -> void:
	_tela_edicao = _nova_tela()
	_vb_edicao = _tela_edicao.get_child(0) as VBoxContainer

	var barra := HBoxContainer.new()
	_vb_edicao.add_child(barra)
	barra.add_child(_botao("Voltar", _voltar_edicao))
	_campo_nome = LineEdit.new()
	_campo_nome.placeholder_text = "Nome do personagem"
	_campo_nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	barra.add_child(_campo_nome)
	barra.add_child(_botao("Salvar", _on_salvar))
	barra.add_child(_botao("Copiar backup", _copiar_backup))
	_msgs.append(_label_msg(_vb_edicao))

	var corpo := HBoxContainer.new()
	corpo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_vb_edicao.add_child(corpo)

	var esq := VBoxContainer.new()
	esq.custom_minimum_size = Vector2(250, 0)
	corpo.add_child(esq)
	esq.add_child(_botao("+ Novo golpe", _novo_golpe))
	var rolagem := ScrollContainer.new()
	rolagem.size_flags_vertical = Control.SIZE_EXPAND_FILL
	esq.add_child(rolagem)
	_lista_golpes = VBoxContainer.new()
	_lista_golpes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rolagem.add_child(_lista_golpes)
	esq.add_child(_linha_botoes([
		_botao("Subir", _mover.bind(-1)),
		_botao("Descer", _mover.bind(1)),
	]))
	esq.add_child(_linha_botoes([
		_botao("Copiar", _copiar_golpe),
		_botao("Excluir", _excluir_golpe),
	]))

	var dir := ScrollContainer.new()
	dir.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dir.size_flags_vertical = Control.SIZE_EXPAND_FILL
	corpo.add_child(dir)
	_painel = VBoxContainer.new()
	_painel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dir.add_child(_painel)
	_montar_painel()

	_tela_edicao.visible = false


func _montar_painel() -> void:
	var linha := HBoxContainer.new()
	_painel.add_child(linha)
	_campo_golpe = LineEdit.new()
	_campo_golpe.placeholder_text = "Nome do golpe"
	_campo_golpe.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_campo_golpe.text_changed.connect(_on_nome_golpe)
	linha.add_child(_campo_golpe)
	_btn_botao = _botao("", _ciclo_botao)
	linha.add_child(_btn_botao)
	_btn_carga = _botao("", _ciclo_carga)
	linha.add_child(_btn_carga)

	var grade := GridContainer.new()
	grade.columns = 2
	_painel.add_child(grade)
	for spec in NUMERICOS:
		grade.add_child(_stepper(spec))

	var flags := HBoxContainer.new()
	_painel.add_child(flags)
	for f in FLAGS:
		var cb := CheckBox.new()
		cb.text = str(f[1])
		cb.toggled.connect(_on_flag.bind(str(f[0])))
		flags.add_child(cb)
		_checks[str(f[0])] = cb

	var hb := HBoxContainer.new()
	_painel.add_child(hb)
	var grade_hb := GridContainer.new()
	grade_hb.columns = 2
	hb.add_child(grade_hb)
	for spec in HITBOX:
		grade_hb.add_child(_stepper(spec))
	_preview = Control.new()
	_preview.custom_minimum_size = TAMANHO_PREVIEW
	_preview.draw.connect(_desenhar_preview.bind(_preview))
	hb.add_child(_preview)


func _stepper(spec: Dictionary) -> HBoxContainer:
	var caminho := str(spec["c"])
	var linha := HBoxContainer.new()
	linha.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var rot := Label.new()
	rot.text = str(spec["r"])
	rot.custom_minimum_size = Vector2(120, 0)
	linha.add_child(rot)
	var menos := Button.new()
	menos.text = "-"
	menos.custom_minimum_size = Vector2(48, 40)
	menos.pressed.connect(_ajustar.bind(caminho, -1))
	linha.add_child(menos)
	var val := Label.new()
	val.custom_minimum_size = Vector2(56, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	linha.add_child(val)
	var mais := Button.new()
	mais.text = "+"
	mais.custom_minimum_size = Vector2(48, 40)
	mais.pressed.connect(_ajustar.bind(caminho, 1))
	linha.add_child(mais)
	_valores[caminho] = val
	_specs[caminho] = spec
	return linha


func _botao(texto: String, acao: Callable) -> Button:
	var b := Button.new()
	b.text = texto
	b.custom_minimum_size = Vector2(0, 44)
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
	l.add_theme_font_size_override("font_size", 28)
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
	var itens: Array = Catalogo.lista()
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
	_abrir(Edicao.novo_personagem("Novo personagem", ""), "", true)


func _abrir(p: Dictionary, pasta: String, novo: bool) -> void:
	_p = p
	_pasta_midia = _com_barra(pasta)
	_novo = novo
	_sel = 0 if (_p["golpes"] as Array).size() > 0 else -1
	_campo_nome.text = str(_p["nome"])
	_tela_lista.visible = false
	_tela_edicao.visible = true
	_mensagem("")
	_refrescar()


func _voltar_edicao() -> void:
	if _veio_da_lista:
		_mostrar_lista()
	else:
		Navegacao.ir_para_menu()


func _com_barra(s: String) -> String:
	if s == "" or s.ends_with("/"):
		return s
	return s + "/"


func _refrescar() -> void:
	_atualizar_lista_golpes()
	_atualizar_campos()


func _atualizar_lista_golpes() -> void:
	_limpar(_lista_golpes)
	var golpes: Array = _p["golpes"]
	for i in golpes.size():
		var g: Dictionary = golpes[i]
		var texto := "%d. %s  [%s]" % [i + 1, str(g["nome"]), Formato.comando_texto(g)]
		var b := _botao(texto, _selecionar.bind(i))
		b.toggle_mode = true
		b.button_pressed = (i == _sel)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_lista_golpes.add_child(b)


func _atualizar_campos() -> void:
	_painel.visible = _sel >= 0
	if _sel >= 0:
		var g: Dictionary = _golpe()
		_campo_golpe.text = str(g["nome"])
		_btn_botao.text = "Botão: " + str(g["botao"])
		_btn_carga.text = _texto_carga(str(g["carga"]))
		for chave in _checks:
			(_checks[chave] as CheckBox).set_pressed_no_signal(bool(g[chave]))
		for c in _specs:
			_mostrar_valor(c)
	_preview.queue_redraw()


func _mostrar_valor(c: String) -> void:
	var label: Label = _valores[c]
	if _sel < 0:
		label.text = "-"
		return
	var spec: Dictionary = _specs[c]
	var v: Variant = _ler(_golpe(), c)
	label.text = str(int(v)) if spec["int"] else "%.1f" % float(v)


func _texto_carga(c: String) -> String:
	match c:
		"tras":
			return "Carga: para trás"
		"baixo":
			return "Carga: para baixo"
	return "Sem carga"


# ---------- golpes ----------

func _golpe() -> Dictionary:
	return (_p["golpes"] as Array)[_sel]


func _selecionar(i: int) -> void:
	_sel = i
	_refrescar()


func _novo_golpe() -> void:
	var pos: int = _sel + 1 if _sel >= 0 else (_p["golpes"] as Array).size()
	if Edicao.inserir_golpe(_p, pos):
		_sel = pos
		_refrescar()
	else:
		_mensagem("Limite de %d golpes." % Formato.MAX_GOLPES)


func _copiar_golpe() -> void:
	if _sel < 0:
		return
	if Edicao.copiar_golpe(_p, _sel):
		_sel += 1
		_refrescar()
	else:
		_mensagem("Não deu para copiar (limite de golpes).")


func _excluir_golpe() -> void:
	if _sel < 0:
		return
	Edicao.excluir_golpe(_p, _sel)
	_sel = mini(_sel, (_p["golpes"] as Array).size() - 1)
	_refrescar()


func _mover(direcao: int) -> void:
	if _sel < 0:
		return
	if Edicao.mover_golpe(_p, _sel, direcao):
		_sel += direcao
		_refrescar()


func _on_nome_golpe(t: String) -> void:
	if _sel < 0:
		return
	var g: Dictionary = _golpe()
	g["nome"] = t


func _ciclo_botao() -> void:
	if _sel < 0:
		return
	var g: Dictionary = _golpe()
	var i: int = Formato.BOTOES.find(str(g["botao"]))
	g["botao"] = Formato.BOTOES[(i + 1) % Formato.BOTOES.size()]
	_atualizar_campos()


func _ciclo_carga() -> void:
	if _sel < 0:
		return
	var g: Dictionary = _golpe()
	var i: int = Formato.CARGAS.find(str(g["carga"]))
	g["carga"] = Formato.CARGAS[(i + 1) % Formato.CARGAS.size()]
	_atualizar_campos()


func _on_flag(ligado: bool, chave: String) -> void:
	if _sel < 0:
		return
	var g: Dictionary = _golpe()
	g[chave] = ligado
	_preview.queue_redraw()


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
	if _sel < 0:
		return
	var spec: Dictionary = _specs[c]
	var g: Dictionary = _golpe()
	var v: float = float(_ler(g, c)) + sinal * float(spec["p"])
	v = clampf(v, float(spec["min"]), float(spec["max"]))
	_gravar(g, c, int(round(v)) if spec["int"] else snappedf(v, 0.1))
	_mostrar_valor(c)
	_preview.queue_redraw()


func _desenhar_preview(c: Control) -> void:
	c.draw_rect(Rect2(Vector2.ZERO, c.size), COR_PREVIEW)
	var pe := Vector2(c.size.x * 0.4, c.size.y * 0.85)
	c.draw_line(Vector2(0, pe.y), Vector2(c.size.x, pe.y), Color(0.5, 0.5, 0.6), 2.0)
	c.draw_rect(Rect2(pe.x - 25, pe.y - 120, 50, 120), Color(0.35, 0.45, 0.7))
	if _sel < 0:
		return
	var r: Rect2 = Caixa.rect_hitbox(_golpe()["hitbox"], pe, true)
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
		return "Dê um nome ao personagem."
	_p["nome"] = nome
	if _novo:
		var base: String = Formato.sanitizar_id(nome)
		_p["id"] = Pacote.id_livre(base if base != "" else "personagem")
	var norm: Dictionary = Formato.normalizar(_p)
	if not norm["ok"]:
		return "Não salvou: " + str(norm["erro"])
	_p = norm["personagem"]
	var pasta := PASTA_USUARIO + str(_p["id"]) + "/"
	DirAccess.make_dir_recursive_absolute(pasta)
	var f := FileAccess.open(pasta + "personagem.json", FileAccess.WRITE)
	if f == null:
		return "Não consegui gravar neste aparelho."
	f.store_string(JSON.stringify(_p, "\t"))
	f.close()
	if _novo or _pasta_midia == "":
		_pasta_midia = pasta
	_novo = false
	Catalogo.recarregar()
	return ""


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
	Catalogo.recarregar()
	_veio_da_lista = true
	_abrir(r["personagem"], str(r["pasta"]), false)
	_mensagem("Importado como '%s'." % str(r["id"]))