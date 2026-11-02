extends Control

# Menu da engine. Tudo desenhado em código, sem arte obrigatória.
# Usa ui/fundo_menu.png se existir; senão, cor lisa.
# Layout: abas na linha de baixo, lado a lado. O submenu aparece encima da aba selecionada,
# e o sub-submenu aparece encima do item selecionado.
# Navegação: toque; controle (D-pad ou analógico esquerdo move, A confirma, B volta).
# Autoloads são acessados por get_node (não pelo nome), para o script compilar sem eles.

const CENA_EDITOR := "res://engine/editor/EditorPersonagem.tscn"
const FUNDO := "res://ui/fundo_menu.png"
const VIEW_W := 960.0
const VIEW_H := 540.0
const MODOS := ["automatico", "touch", "controle"]
const IDIOMAS := ["pt", "en"]
const CFG_CATS := ["cfg_graficos", "cfg_luta", "cfg_controle", "cfg_idioma"]
const TEMPO_AVISO := 90
const LIMIAR_STICK := 0.6

# Medidas do layout (fonte única para desenho e toque).
const MARGEM := 20.0
const LARGURA_ABA := 170.0
const PASSO_ABA := 186.0
const LARGURA_ITEM := 200.0
const ESPACO_ITEM := 16.0
const PASSO_ITEM := 216.0
const Y_ABAS := 462.0
const Y_SUB := 372.0
const Y_SUB2 := 290.0

# Pedido para o editor ao abrir: "criar" ou "editar".
static var modo_editor: String = "editar"

const ARVORE := [
	{"chave": "aba_multiplayer", "icone": "MP", "filhos": [
		{"chave": "mp_local", "filhos": [
			{"chave": "sub_arcade", "acao": "em_breve"},
			{"chave": "sub_historia", "acao": "em_breve"},
			{"chave": "sub_treino", "acao": "treino"},
		]},
		{"chave": "mp_online", "acao": "em_breve"},
	]},
	{"chave": "aba_personagem", "icone": "PJ", "filhos": [
		{"chave": "sub_criar", "acao": "criar"},
		{"chave": "sub_editar", "acao": "editar"},
	]},
]

var aba: int = 0
var sub: int = 0
var sub2: int = 0
var nivel: int = 0
var config_aberto: bool = false
var config_nivel: int = 0
var config_cat: int = 0
var cfg_foco: int = 0
var aviso: String = ""
var aviso_t: int = 0
var _fundo: Texture2D = null
var _eixo_estado: Dictionary = {}

# ---------- Autoloads (acesso em tempo de execução) ----------

func _audio() -> Variant:
	return get_node("/root/Audio")

func _config() -> Variant:
	return get_node("/root/Config")

func _textos() -> Variant:
	return get_node("/root/Textos")

func _navegacao() -> Variant:
	return get_node("/root/Navegacao")

func _t(chave: String) -> String:
	return str(_textos().t(chave))

# ---------- Ciclo de vida ----------

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(FUNDO):
		_fundo = load(FUNDO) as Texture2D
	_audio().tocar_musica("menu", true)

func _process(_delta: float) -> void:
	if aviso_t > 0:
		aviso_t -= 1
		if aviso_t == 0:
			aviso = ""
	queue_redraw()

# ---------- Desenho ----------

func _draw() -> void:
	if _fundo != null:
		draw_texture_rect(_fundo, Rect2(0.0, 0.0, VIEW_W, VIEW_H), false)
	else:
		draw_rect(Rect2(0.0, 0.0, VIEW_W, VIEW_H), Color(0.06, 0.08, 0.16))
	if config_aberto:
		draw_rect(Rect2(0.0, 0.0, VIEW_W, VIEW_H), Color(0.0, 0.0, 0.0, 0.6))
	for e in _layout():
		_desenhar_entrada(e)
	if aviso_t > 0:
		draw_string(ThemeDB.fallback_font, Vector2(0.0, 440.0), aviso, HORIZONTAL_ALIGNMENT_CENTER, VIEW_W, 14, Color(1.0, 0.85, 0.5))

func _texto_c(r: Rect2, s: String, tam: int = 14, cor: Color = Color.WHITE) -> void:
	draw_string(ThemeDB.fallback_font, Vector2(r.position.x, r.position.y + r.size.y * 0.5 + tam * 0.35), s, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, tam, cor)

func _desenhar_entrada(e: Dictionary) -> void:
	var r: Rect2 = e["r"]
	var tipo: String = e["tipo"]
	var texto: String = str(e["label"])
	if tipo == "nada":
		_texto_c(r, texto, 14, Color(0.8, 0.8, 0.9))
		return
	var ativo: bool = e["ativo"]
	var foco: bool = e.get("foco", false)
	var cor_fundo: Color = Color(0.25, 0.38, 0.65, 0.95) if ativo else Color(0.1, 0.12, 0.22, 0.9)
	draw_rect(r, cor_fundo)
	var cor_borda: Color = Color(1.0, 0.85, 0.3) if foco else Color(0.7, 0.75, 0.9)
	draw_rect(r, cor_borda, false, 3.0 if foco else 1.0)
	if e.has("icone"):
		draw_string(ThemeDB.fallback_font, Vector2(r.position.x + 14.0, r.position.y + r.size.y * 0.5 + 6.0), str(e["icone"]), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, Color(1.0, 1.0, 1.0, 0.9))
	_texto_c(r, texto, 16 if tipo == "aba" else 14)

# ---------- Layout (fonte única para desenho e toque) ----------

func _entrada(r: Rect2, tipo: String, i: int, label: String, ativo: bool, item: Dictionary = {}) -> Dictionary:
	return {"r": r, "tipo": tipo, "i": i, "label": label, "ativo": ativo, "item": item}

func _layout() -> Array:
	var lista: Array = []
	if config_aberto:
		_layout_config(lista)
	else:
		_layout_principal(lista)
	return lista

# Abas: x inicial para centralizar a linha toda.
func _x_abas() -> float:
	var n: int = ARVORE.size()
	return (VIEW_W - (n * LARGURA_ABA + (n - 1) * ESPACO_ITEM)) * 0.5

# Centro horizontal de uma aba.
func _centro_aba(i: int) -> float:
	return _x_abas() + i * PASSO_ABA + LARGURA_ABA * 0.5

# X inicial de uma linha de qtd itens, centralizada em "centro" e presa às bordas da tela.
func _x_centrado_em(centro: float, qtd: int) -> float:
	var largura: float = qtd * LARGURA_ITEM + maxi(qtd - 1, 0) * ESPACO_ITEM
	return clampf(centro - largura * 0.5, MARGEM, VIEW_W - MARGEM - largura)

func _layout_principal(lista: Array) -> void:
	lista.append(_entrada(Rect2(20.0, 14.0, 170.0, 36.0), "config_abrir", 0, _t("cfg_titulo"), false))
	var n_abas: int = ARVORE.size()
	var x0: float = _x_abas()
	for i in range(n_abas):
		var aba_item: Dictionary = ARVORE[i]
		var e: Dictionary = _entrada(Rect2(x0 + i * PASSO_ABA, Y_ABAS, LARGURA_ABA, 56.0), "aba", i, _t(str(aba_item["chave"])), i == aba, aba_item)
		e["icone"] = str(aba_item["icone"])
		lista.append(e)

	# Submenu: encima da aba selecionada.
	var filhos: Array = _filhos_aba()
	var x1: float = _x_centrado_em(_centro_aba(aba), filhos.size())
	lista.append(_entrada(Rect2(30.0, Y_SUB, 56.0, 46.0), "seta_esq", 0, "<", false))
	lista.append(_entrada(Rect2(874.0, Y_SUB, 56.0, 46.0), "seta_dir", 0, ">", false))
	for j in range(filhos.size()):
		var it: Dictionary = filhos[j]
		lista.append(_entrada(Rect2(x1 + j * PASSO_ITEM, Y_SUB, LARGURA_ITEM, 46.0), "sub", j, _t(str(it["chave"])), j == sub, it))

	# Sub-submenu: encima do item selecionado.
	if nivel == 2:
		var filhos2: Array = _filhos_do_sub()
		var centro_sub: float = x1 + sub * PASSO_ITEM + LARGURA_ITEM * 0.5
		var x2: float = _x_centrado_em(centro_sub, filhos2.size())
		for k in range(filhos2.size()):
			var it2: Dictionary = filhos2[k]
			lista.append(_entrada(Rect2(x2 + k * PASSO_ITEM, Y_SUB2, LARGURA_ITEM, 44.0), "sub2", k, _t(str(it2["chave"])), k == sub2, it2))

	if nivel > 0:
		lista.append(_entrada(Rect2(20.0, 462.0, 150.0, 56.0), "voltar", 0, _t("voltar"), false))
	lista.append(_entrada(Rect2(0.0, 518.0, VIEW_W, 18.0), "nada", 0, _t("dica_menu"), false))

func _layout_config(lista: Array) -> void:
	lista.append(_entrada(Rect2(40.0, 40.0, 300.0, 44.0), "nada", 0, _t("cfg_titulo"), false))
	if config_nivel == 0:
		for i in range(CFG_CATS.size()):
			lista.append(_entrada(Rect2(40.0, 110.0 + i * 64.0, 300.0, 52.0), "cfg_cat", i, _t(CFG_CATS[i]), i == config_cat))
	else:
		var ops: Array = _opcoes_cfg(config_cat)
		if ops.is_empty():
			lista.append(_entrada(Rect2(380.0, 110.0, 340.0, 52.0), "nada", 0, _t("em_breve"), false))
		for j in range(ops.size()):
			var op: Dictionary = ops[j]
			lista.append(_entrada(Rect2(380.0, 110.0 + j * 64.0, 340.0, 52.0), "cfg_opt", j, _t(str(op["chave"])), bool(op["ativo"])))
		if config_cat == 2:
			var info: String = _t("modo_ativo") + ": " + _t("modo_" + str(_config().modo_efetivo()))
			lista.append(_entrada(Rect2(380.0, 420.0, 340.0, 30.0), "nada", 0, info, false))
	lista.append(_entrada(Rect2(40.0, 470.0, 160.0, 50.0), "cfg_voltar", 0, _t("voltar"), false))
	var f: Array = _focaveis_cfg(lista)
	if not f.is_empty():
		var marcado: Dictionary = f[posmod(cfg_foco, f.size())]
		marcado["foco"] = true

func _opcoes_cfg(cat: int) -> Array:
	var r: Array = []
	if cat == 2:
		for m in MODOS:
			r.append({"chave": "modo_" + str(m), "ativo": _config().modo_escolhido == str(m)})
	elif cat == 3:
		for c in IDIOMAS:
			r.append({"chave": "idioma_" + str(c), "ativo": _config().idioma == str(c)})
	return r

func _focaveis_cfg(lista: Array) -> Array:
	var f: Array = []
	for e in lista:
		var d: Dictionary = e
		if str(d["tipo"]).begins_with("cfg_"):
			f.append(d)
	return f

# ---------- Dados da árvore ----------

func _filhos_aba() -> Array:
	var item: Dictionary = ARVORE[aba]
	return item["filhos"]

func _filhos_do_sub() -> Array:
	var it: Dictionary = _filhos_aba()[sub]
	return it.get("filhos", [])

# ---------- Entrada ----------

func _unhandled_input(ev: InputEvent) -> void:
	var st := ev as InputEventScreenTouch
	if st != null and st.pressed:
		_tocar(st.position)
		get_viewport().set_input_as_handled()
		return
	var bt := ev as InputEventJoypadButton
	if bt != null and bt.pressed:
		_botao_controle(int(bt.button_index))
		get_viewport().set_input_as_handled()
		return
	var jm := ev as InputEventJoypadMotion
	if jm != null:
		_analogico(jm)
		get_viewport().set_input_as_handled()

# Analógico esquerdo: dispara uma vez ao passar do limiar, e rearma ao voltar ao centro.
func _analogico(ev: InputEventJoypadMotion) -> void:
	var eixo: int = ev.axis
	if eixo != JOY_AXIS_LEFT_X and eixo != JOY_AXIS_LEFT_Y:
		return
	var v: float = ev.axis_value
	var agora := 0
	if v > LIMIAR_STICK:
		agora = 1
	elif v < -LIMIAR_STICK:
		agora = -1
	var antes: int = int(_eixo_estado.get(eixo, 0))
	_eixo_estado[eixo] = agora
	if agora == 0 or agora == antes:
		return
	if eixo == JOY_AXIS_LEFT_X:
		_botao_controle(JOY_BUTTON_DPAD_RIGHT if agora > 0 else JOY_BUTTON_DPAD_LEFT)
	else:
		_botao_controle(JOY_BUTTON_DPAD_DOWN if agora > 0 else JOY_BUTTON_DPAD_UP)

func _tocar(p: Vector2) -> void:
	var e: Dictionary = _acertar(p)
	if e.is_empty():
		return
	_acionar(e)

func _acertar(p: Vector2) -> Dictionary:
	for e in _layout():
		var d: Dictionary = e
		var r: Rect2 = d["r"]
		if str(d["tipo"]) != "nada" and r.has_point(p):
			return d
	return {}

func _acionar(e: Dictionary) -> void:
	var tipo: String = e["tipo"]
	var i: int = e["i"]
	var item: Dictionary = e["item"]
	match tipo:
		"config_abrir":
			config_aberto = true
			config_nivel = 0
			cfg_foco = 0
		"cfg_cat":
			config_cat = i
			config_nivel = 1
			cfg_foco = 0
		"cfg_opt":
			_aplicar_cfg(i)
		"cfg_voltar", "voltar":
			_voltar()
		"aba":
			aba = i
			sub = 0
			sub2 = 0
			nivel = 1
			_som("menu_mover")
		"sub":
			sub = i
			sub2 = 0
			if item.has("filhos"):
				nivel = 2
				_som("menu_mover")
			else:
				nivel = 1
				_executar(item)
		"sub2":
			sub2 = i
			_executar(item)
		"seta_esq":
			_mover(-1)
		"seta_dir":
			_mover(1)

func _botao_controle(b: int) -> void:
	if config_aberto:
		if b == JOY_BUTTON_DPAD_UP:
			_mover_foco_cfg(-1)
		elif b == JOY_BUTTON_DPAD_DOWN:
			_mover_foco_cfg(1)
		elif b == JOY_BUTTON_A:
			_acionar_foco_cfg()
		elif b == JOY_BUTTON_B:
			_voltar()
		return
	if b == JOY_BUTTON_DPAD_LEFT:
		_mover(-1)
	elif b == JOY_BUTTON_DPAD_RIGHT:
		_mover(1)
	elif b == JOY_BUTTON_DPAD_UP:
		nivel = maxi(0, nivel - 1)
	elif b == JOY_BUTTON_DPAD_DOWN:
		_descer()
	elif b == JOY_BUTTON_A:
		_confirmar()
	elif b == JOY_BUTTON_B:
		_voltar()

func _mover(d: int) -> void:
	_som("menu_mover")
	if nivel == 0:
		aba = posmod(aba + d, ARVORE.size())
		sub = 0
		sub2 = 0
	elif nivel == 1:
		sub = posmod(sub + d, _filhos_aba().size())
		sub2 = 0
	else:
		sub2 = posmod(sub2 + d, _filhos_do_sub().size())

func _descer() -> void:
	if nivel == 0:
		nivel = 1
	elif nivel == 1 and not _filhos_do_sub().is_empty():
		nivel = 2
		sub2 = 0

func _confirmar() -> void:
	if nivel == 0:
		nivel = 1
	elif nivel == 1:
		var it: Dictionary = _filhos_aba()[sub]
		if it.has("filhos"):
			nivel = 2
			sub2 = 0
		else:
			_executar(it)
	else:
		var f: Array = _filhos_do_sub()
		_executar(f[sub2])

func _voltar() -> void:
	_som("menu_voltar")
	if config_aberto:
		if config_nivel == 1:
			config_nivel = 0
			cfg_foco = config_cat
		else:
			config_aberto = false
		return
	if nivel > 0:
		nivel -= 1

func _mover_foco_cfg(d: int) -> void:
	var f: Array = _focaveis_cfg(_layout())
	if f.is_empty():
		return
	cfg_foco = posmod(cfg_foco + d, f.size())

func _acionar_foco_cfg() -> void:
	var f: Array = _focaveis_cfg(_layout())
	if f.is_empty():
		return
	_acionar(f[posmod(cfg_foco, f.size())])

func _aplicar_cfg(j: int) -> void:
	if config_cat == 2 and j < MODOS.size():
		_config().definir_modo(MODOS[j])
	elif config_cat == 3 and j < IDIOMAS.size():
		_config().definir_idioma(IDIOMAS[j])
	_som("menu_confirma")

# ---------- Ações ----------

func _executar(item: Dictionary) -> void:
	var acao: String = str(item.get("acao", ""))
	match acao:
		"treino":
			_som("menu_confirma")
			_navegacao().ir_para_luta()
		"criar", "editar":
			if ResourceLoader.exists(CENA_EDITOR):
				_som("menu_confirma")
				modo_editor = acao
				get_tree().change_scene_to_file(CENA_EDITOR)
			else:
				_avisar()
		_:
			_avisar()

func _avisar() -> void:
	aviso = _t("em_breve")
	aviso_t = TEMPO_AVISO

func _som(nome: String) -> void:
	_audio().tocar_interface(nome)