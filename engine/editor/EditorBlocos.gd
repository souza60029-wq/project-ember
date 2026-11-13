extends Control

# Editor de blocos do golpe (estilo Pocket Code). Substitui a tela de propriedades.
# Esquerda: paleta de blocos (toque para adicionar). Direita: o golpe.
#  - "Ajustes do golpe" (laranja): tempo, dano, alcance, barra e especiais. Em golpes fixos
#    (LP, LK, HP, HK, BO) ficam travados; só os blocos de comportamento podem ser usados.
#  - "Quando o golpe rodar": blocos de comportamento, que a engine executa sozinha:
#       Mover, Subir/pular, Parar, Lançar magia (projétil), Só começa depois de outro golpe,
#       Quando o golpe terminar (subir ou ir para outro golpe).
# Exemplos: golpe que acerta o chão e no final sobe = marcar "Acerta oponente caído" +
# bloco "Quando o golpe terminar: subir". Golpe que começa de outro = bloco "Só começa depois do golpe".
# Os blocos ficam no campo "blocos" do golpe (personagem.json).

signal fechado

const Formato = preload("res://engine/formato/Formato.gd")
const Medidas = preload("res://engine/formato/Medidas.gd")

const COR_FUNDO := Color(0.05, 0.04, 0.12)
const COR_AJUSTE := Color(0.78, 0.42, 0.1)
const COR_MOVER := Color(0.16, 0.38, 0.78)
const COR_MAGIA := Color(0.55, 0.28, 0.75)
const COR_COMBO := Color(0.14, 0.56, 0.32)
const COR_TEXTO := Color(0.96, 0.96, 1.0)
const ALT: float = 52.0

const CATEGORIAS := {
	"mover": COR_MOVER, "pular": COR_MOVER, "parar": COR_MOVER,
	"projetil": COR_MAGIA, "comecar_de": COR_COMBO, "ao_fim": COR_COMBO,
}
const PALETA := [
	["Movimento", COR_MOVER, ["mover", "pular", "parar"]],
	["Magia", COR_MAGIA, ["projetil"]],
	["Combo e encadeamento", COR_COMBO, ["comecar_de", "ao_fim"]],
]
const DESCRICOES := {
	"mover": "Move o personagem para frente (ou para tras, com valor negativo) por alguns frames.",
	"pular": "Joga o personagem para cima. Bom para golpes que sobem.",
	"parar": "Para o movimento do bloco Mover.",
	"projetil": "Lanca uma magia que anda e causa dano ao acertar o oponente.",
	"comecar_de": "Este golpe so sai durante outro golpe (combo/cancelamento).",
	"ao_fim": "O que acontece quando o golpe acaba: subir ou ir para outro golpe.",
}

var _g: Dictionary = {}
var _p: Dictionary = {}
var _pasta: String = ""
var _base: bool = false
var _lista: VBoxContainer
var _titulo: Label


func abrir(g: Dictionary, p: Dictionary, pasta: String) -> void:
	_g = g
	_p = p
	_pasta = pasta
	_base = bool(g["base"])
	_montar()
	_reconstruir()


# ---------- estilo ----------

func _caixa(cor: Color, borda: Color, raio: int = 12) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = cor
	sb.border_color = borda
	sb.set_border_width_all(2)
	sb.border_width_left = 10
	sb.set_corner_radius_all(raio)
	sb.content_margin_left = 18.0
	sb.content_margin_right = 12.0
	sb.content_margin_top = 10.0
	sb.content_margin_bottom = 10.0
	return sb


func _botao(texto: String, acao: Callable, cor: Color = Color(0.2, 0.15, 0.42), minimo: Vector2 = Vector2(0, ALT)) -> Button:
	var b := Button.new()
	b.text = texto
	b.custom_minimum_size = minimo
	b.clip_text = true
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_color_override("font_color", COR_TEXTO)
	for par in [["normal", cor], ["hover", cor.lightened(0.12)], ["pressed", cor.lightened(0.25)], ["disabled", cor.darkened(0.5)]]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = par[1]
		sb.border_color = Color(1, 1, 1, 0.3)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(10)
		sb.content_margin_left = 12.0
		sb.content_margin_right = 12.0
		b.add_theme_stylebox_override(str(par[0]), sb)
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

	_titulo = Label.new()
	_titulo.position = Vector2(16.0, 12.0)
	_titulo.size = Vector2(760.0, 44.0)
	_titulo.add_theme_font_size_override("font_size", 26)
	_titulo.clip_text = true
	add_child(_titulo)
	_atualizar_titulo()
	var fechar: Button = _botao("Fechar", _fechar, Color(0.5, 0.16, 0.2), Vector2(140, 52))
	fechar.position = Vector2(806.0, 8.0)
	fechar.size = Vector2(140.0, 52.0)
	add_child(fechar)

	# Paleta
	var rp := ScrollContainer.new()
	rp.position = Vector2(10.0, 68.0)
	rp.size = Vector2(290.0, 462.0)
	rp.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rp.scroll_deadzone = 12
	add_child(rp)
	var vp := VBoxContainer.new()
	vp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vp.add_theme_constant_override("separation", 8)
	rp.add_child(vp)
	var dica := Label.new()
	dica.text = "Toque num bloco para adicionar ao golpe."
	dica.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dica.add_theme_font_size_override("font_size", 16)
	dica.add_theme_color_override("font_color", Color(0.75, 0.75, 0.95))
	vp.add_child(dica)
	for cat in PALETA:
		var l := Label.new()
		l.text = str(cat[0])
		l.add_theme_font_size_override("font_size", 20)
		l.add_theme_color_override("font_color", cat[1])
		vp.add_child(l)
		for tipo in cat[2]:
			vp.add_child(_botao(str(Formato.BLOCOS_ROTULOS[tipo]), _adicionar.bind(str(tipo)), cat[1], Vector2(0, 56)))

	# Script
	var rs := ScrollContainer.new()
	rs.position = Vector2(310.0, 68.0)
	rs.size = Vector2(640.0, 462.0)
	rs.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rs.scroll_deadzone = 12
	add_child(rs)
	_lista = VBoxContainer.new()
	_lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lista.add_theme_constant_override("separation", 10)
	rs.add_child(_lista)


func _atualizar_titulo() -> void:
	_titulo.text = "Blocos: %s (%s)" % [str(_g["nome"]), str(_g["botao"])]


func _fechar() -> void:
	fechado.emit()
	queue_free()


# ---------- construção do script ----------

func _reconstruir() -> void:
	for c in _lista.get_children():
		_lista.remove_child(c)
		c.queue_free()
	_cabecalho("Ajustes do golpe" + ("  (golpe fixo: travado)" if _base else ""), COR_AJUSTE)
	_bloco_identidade()
	_bloco_numeros("Tempo (frames a 60 FPS)", _g, [["startup", "Startup", 0, 99, 1], ["active", "Ativo", 1, 99, 1], ["recovery", "Recuperacao", 0, 199, 1]])
	_bloco_numeros("Dano", _g, [["dano", "Dano", 0, 999, 10], ["forca", "Forca (1-3)", 1, 3, 1]])
	_bloco_alcance()
	_bloco_numeros("Barra", _g, [["custo", "Custo de barra", 0, 300, 10], ["energia_ganha", "Barra ganha", 0, 300, 10], ["carga_seg", "Carga (seg)", 0, 3, 0.1]])
	_bloco_especiais()
	_cabecalho("Quando o golpe rodar", COR_MOVER)
	var blocos: Array = _g["blocos"]
	if blocos.is_empty():
		var v := Label.new()
		v.text = "Nenhum bloco ainda. Toque num bloco da esquerda."
		v.add_theme_font_size_override("font_size", 18)
		v.add_theme_color_override("font_color", Color(0.75, 0.75, 0.95))
		_lista.add_child(v)
	for i in range(blocos.size()):
		_bloco_comportamento(i)


func _cabecalho(texto: String, cor: Color) -> void:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", cor.lightened(0.3))
	_lista.add_child(l)


# Cartão de bloco: devolve o VBox onde entram as linhas.
func _cartao(titulo: String, cor: Color, descricao: String = "") -> VBoxContainer:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", _caixa(cor.darkened(0.45), cor))
	_lista.add_child(pc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	pc.add_child(v)
	var t := Label.new()
	t.text = titulo
	t.add_theme_font_size_override("font_size", 22)
	t.add_theme_color_override("font_color", COR_TEXTO)
	v.add_child(t)
	if descricao != "":
		var d := Label.new()
		d.text = descricao
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.add_theme_font_size_override("font_size", 14)
		d.add_theme_color_override("font_color", Color(0.8, 0.8, 0.95))
		v.add_child(d)
	return v


# Linha com - valor + .  d[chave] vai de mn a mx, de "passo" em "passo".
func _stepper(pai: Control, rotulo: String, d: Dictionary, chave: String, mn: float, mx: float, passo: float, travado: bool) -> void:
	var linha := HBoxContainer.new()
	linha.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pai.add_child(linha)
	var l := Label.new()
	l.text = rotulo
	l.custom_minimum_size = Vector2(190, 0)
	l.add_theme_font_size_override("font_size", 18)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	linha.add_child(l)
	var v := Label.new()
	v.custom_minimum_size = Vector2(86, 0)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	v.add_theme_font_size_override("font_size", 22)
	var decimal: bool = passo < 1.0
	v.text = ("%.1f" % float(d[chave])) if decimal else str(int(d[chave]))
	var menos: Button = _botao("-", _ajustar.bind(d, chave, -passo, mn, mx, v, decimal), Color(0.2, 0.15, 0.42), Vector2(64, ALT))
	var mais: Button = _botao("+", _ajustar.bind(d, chave, passo, mn, mx, v, decimal), Color(0.2, 0.15, 0.42), Vector2(64, ALT))
	menos.disabled = travado
	mais.disabled = travado
	linha.add_child(menos)
	linha.add_child(v)
	linha.add_child(mais)


func _ajustar(d: Dictionary, chave: String, delta: float, mn: float, mx: float, rotulo: Label, decimal: bool) -> void:
	var novo: float = clampf(float(d[chave]) + delta, mn, mx)
	if decimal:
		d[chave] = snappedf(novo, 0.1)
		rotulo.text = "%.1f" % float(d[chave])
	else:
		d[chave] = int(round(novo))
		rotulo.text = str(int(d[chave]))


# ---------- blocos de ajuste ----------

func _bloco_identidade() -> void:
	var v: VBoxContainer = _cartao("Golpe", COR_AJUSTE)
	var linha := HBoxContainer.new()
	v.add_child(linha)
	var nome := LineEdit.new()
	nome.text = str(_g["nome"])
	nome.editable = not _base
	nome.custom_minimum_size = Vector2(0, ALT)
	nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nome.add_theme_font_size_override("font_size", 20)
	nome.text_changed.connect(_renomear)
	linha.add_child(nome)
	var bb: Button = _botao(str(_g["botao"]), _ciclo_botao, Color(0.2, 0.15, 0.42), Vector2(80, ALT))
	bb.disabled = _base
	linha.add_child(bb)
	var bc: Button = _botao(_texto_carga(str(_g["carga"])), _ciclo_carga, Color(0.2, 0.15, 0.42), Vector2(150, ALT))
	bc.disabled = _base
	linha.add_child(bc)


func _texto_carga(c: String) -> String:
	if c == "tras":
		return "Carga tras"
	if c == "baixo":
		return "Carga baixo"
	return "Sem carga"


func _renomear(texto: String) -> void:
	var antigo: String = str(_g["nome"])
	_g["nome"] = texto
	for g in _p["golpes"]:
		for b in (g as Dictionary)["blocos"]:
			var d: Dictionary = b
			if d.has("golpe") and str(d["golpe"]) == antigo:
				d["golpe"] = texto
	_atualizar_titulo()


func _ciclo_botao() -> void:
	var i: int = Formato.BOTOES.find(str(_g["botao"]))
	_g["botao"] = Formato.BOTOES[(i + 1) % Formato.BOTOES.size()]
	_atualizar_titulo()
	_reconstruir()


func _ciclo_carga() -> void:
	var i: int = Formato.CARGAS.find(str(_g["carga"]))
	_g["carga"] = Formato.CARGAS[(i + 1) % Formato.CARGAS.size()]
	_reconstruir()


func _bloco_numeros(titulo: String, d: Dictionary, specs: Array) -> void:
	var v: VBoxContainer = _cartao(titulo, COR_AJUSTE)
	for s in specs:
		_stepper(v, str(s[1]), d, str(s[0]), float(s[2]), float(s[3]), float(s[4]), _base)


func _bloco_alcance() -> void:
	var v: VBoxContainer = _cartao("Alcance do golpe (hitbox, em pixels)", COR_AJUSTE, "Em pixels a partir dos pes do personagem. O motor ajusta pelo tamanho dele.")
	var hb: Dictionary = _g["hitbox"]
	_stepper(v, "Posicao X", hb, "x", -300, 300, 5, _base)
	_stepper(v, "Posicao Y", hb, "y", -300, 0, 5, _base)
	_stepper(v, "Largura", hb, "w", 1, 300, 5, _base)
	_stepper(v, "Altura", hb, "h", 1, 300, 5, _base)
	var auto: Button = _botao("Medir pelo sprite de impacto", _alcance_automatico, COR_AJUSTE)
	auto.disabled = _base
	v.add_child(auto)


func _alcance_automatico() -> void:
	var h: Dictionary = Medidas.hitbox_sugerida(_g, int(_p["altura_px"]), _pasta)
	if h.is_empty():
		return
	_g["hitbox"] = h
	_reconstruir()


func _bloco_especiais() -> void:
	var v: VBoxContainer = _cartao("Especiais", COR_AJUSTE)
	for par in [["antichao", "Acerta oponente caido"], ["blowoff", "Blow Off (joga o oponente longe)"], ["so_ar", "So pode ser usado no ar"]]:
		var cb := CheckBox.new()
		cb.text = str(par[1])
		cb.button_pressed = bool(_g[str(par[0])])
		cb.disabled = _base
		cb.custom_minimum_size = Vector2(0, ALT)
		cb.add_theme_font_size_override("font_size", 20)
		cb.toggled.connect(_on_flag.bind(str(par[0])))
		v.add_child(cb)


func _on_flag(ligado: bool, chave: String) -> void:
	_g[chave] = ligado


# ---------- blocos de comportamento ----------

func _adicionar(tipo: String) -> void:
	var blocos: Array = _g["blocos"]
	if blocos.size() >= Formato.BLOCOS_MAX:
		return
	if (tipo == "comecar_de" or tipo == "ao_fim"):
		for b in blocos:
			if str((b as Dictionary)["tipo"]) == tipo:
				return
	var b2: Dictionary = Formato.bloco_padrao(tipo)
	var nomes: Array = _nomes_golpes()
	if (tipo == "comecar_de" or tipo == "ao_fim") and not nomes.is_empty():
		b2["golpe"] = str(nomes[0])
	blocos.append(b2)
	_reconstruir()


func _nomes_golpes() -> Array:
	var r: Array = []
	for g in _p["golpes"]:
		var n: String = str((g as Dictionary)["nome"])
		if not is_same(g, _g) and not r.has(n):
			r.append(n)
	return r


func _bloco_comportamento(i: int) -> void:
	var blocos: Array = _g["blocos"]
	var b: Dictionary = blocos[i]
	var tipo: String = str(b["tipo"])
	var v: VBoxContainer = _cartao(str(Formato.BLOCOS_ROTULOS[tipo]), CATEGORIAS[tipo], str(DESCRICOES[tipo]))
	for s in Formato.BLOCOS_SPEC[tipo]:
		var chave: String = str(s[0])
		if tipo == "ao_fim" and str(b["acao"]) != "subir":
			continue
		_stepper(v, str(Formato.BLOCOS_PARAM_ROTULOS.get(chave, chave)), b, chave, float(s[2]), float(s[3]), float(s[4]), false)
	if tipo == "comecar_de":
		v.add_child(_botao("Golpe: " + _nome_ref(b), _ciclo_golpe.bind(b), CATEGORIAS[tipo]))
		v.add_child(_botao("Quando: " + ("depois de acertar" if str(b["quando"]) == "acertar" else "a qualquer momento"), _ciclo_quando.bind(b), CATEGORIAS[tipo]))
	if tipo == "ao_fim":
		v.add_child(_botao("Acao: " + ("subir" if str(b["acao"]) == "subir" else "ir para outro golpe"), _ciclo_acao.bind(b), CATEGORIAS[tipo]))
		if str(b["acao"]) != "subir":
			v.add_child(_botao("Golpe: " + _nome_ref(b), _ciclo_golpe.bind(b), CATEGORIAS[tipo]))
	var ctl := HBoxContainer.new()
	v.add_child(ctl)
	var sobe: Button = _botao("Subir", _mover_bloco.bind(i, -1), Color(0.2, 0.15, 0.42), Vector2(0, ALT))
	sobe.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sobe.disabled = i == 0
	ctl.add_child(sobe)
	var desce: Button = _botao("Descer", _mover_bloco.bind(i, 1), Color(0.2, 0.15, 0.42), Vector2(0, ALT))
	desce.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desce.disabled = i == blocos.size() - 1
	ctl.add_child(desce)
	var apaga: Button = _botao("Apagar", _apagar.bind(i), Color(0.5, 0.16, 0.2), Vector2(0, ALT))
	apaga.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ctl.add_child(apaga)


func _nome_ref(b: Dictionary) -> String:
	var n: String = str(b["golpe"])
	return n if n != "" else "(escolha)"


func _ciclo_golpe(b: Dictionary) -> void:
	var nomes: Array = _nomes_golpes()
	if nomes.is_empty():
		return
	var i: int = nomes.find(str(b["golpe"]))
	b["golpe"] = str(nomes[(i + 1) % nomes.size()])
	_reconstruir()


func _ciclo_quando(b: Dictionary) -> void:
	b["quando"] = "sempre" if str(b["quando"]) == "acertar" else "acertar"
	_reconstruir()


func _ciclo_acao(b: Dictionary) -> void:
	b["acao"] = "subir" if str(b["acao"]) == "ir_para" else "ir_para"
	_reconstruir()


func _mover_bloco(i: int, d: int) -> void:
	var blocos: Array = _g["blocos"]
	var j: int = i + d
	if j < 0 or j >= blocos.size():
		return
	var t: Variant = blocos[i]
	blocos[i] = blocos[j]
	blocos[j] = t
	_reconstruir()


func _apagar(i: int) -> void:
	(_g["blocos"] as Array).remove_at(i)
	_reconstruir()
