extends Control

# Menu da engine. Tudo desenhado em código; arte é opcional.
# Abas lado a lado na linha de baixo. O submenu é uma lista vertical acima da aba
# selecionada, alinhada à borda esquerda dela. Não há terceiro nível.
# Fundo e música mudam por aba; submenus não mudam o fundo.
# Navegação: toque; controle (D-pad ou analógico esquerdo move, A confirma, B volta).
# Autoloads são acessados por get_node, para o script compilar sem eles.

const CENA_EDITOR := "res://engine/editor/EditorPersonagem.tscn"
const PASTA_MENU := "res://ui/menu/"
const VIEW_W := 960.0
const VIEW_H := 540.0
const MODOS := ["automatico", "touch", "controle"]
const IDIOMAS := ["pt", "en"]
const CFG_CATS := ["cfg_graficos", "cfg_luta", "cfg_controle", "cfg_idioma"]
const TEMPO_AVISO := 90
const LIMIAR_STICK := 0.6

# Medidas (fonte única para desenho e toque).
const MARGEM := 20.0
const TAB_W := 218.0
const TAB_GAP := 16.0
const TAB_Y := 458.0
const TAB_H := 52.0
const SUB_W := 210.0
const SUB_H := 44.0
const SUB_GAP := 14.0
const SUB_ACIMA_TAB := 12.0
const SOMBRA_H := 10.0
const ICONE_TAB := 32.0
const DICA_Y := 534.0

# Cor lisa de cada aba, usada quando a imagem de fundo não existe.
const CORES := [
	Color(0.22, 0.10, 0.30),
	Color(0.08, 0.16, 0.34),
	Color(0.10, 0.26, 0.16),
	Color(0.30, 0.16, 0.08)
]

# Textos de reserva para chaves que ainda não estão em Textos.gd.
const RESERVA := {
	"aba_treino": ["Treino", "Training"],
	"mp_coop": ["Coop", "Co-op"],
	"ctrl_nome": ["Controle", "Controller"],
	"ctrl_ultimo": ["Último botão", "Last button"]
}

# Estrutura do menu. Ordem: Local, Multiplayer, Treino, Personagem.
const ABAS := [
	{
		"chave": "aba_local", "icone": "icone_local", "abrev": "LO",
		"fundo": "fundo_local", "musica": "menu_local",
		"filhos": [
			{"chave": "sub_arcade", "icone": "icone_arcade", "acao": "em_breve"},
			{"chave": "sub_classico", "icone": "icone_classico", "acao": "em_breve"},
			{"chave": "sub_historia", "icone": "icone_historia", "acao": "em_breve"}
		]
	},
	{
		"chave": "aba_multiplayer", "icone": "icone_multiplayer", "abrev": "MP",
		"fundo": "fundo_multiplayer", "musica": "menu_multiplayer",
		"filhos": [
			{"chave": "mp_coop", "icone": "icone_coop", "acao": "em_breve"},
			{"chave": "mp_online", "icone": "icone_mp_online", "acao": "em_breve"}
		]
	},
	{
		"chave": "aba_treino", "icone": "icone_treino", "abrev": "TR",
		"fundo": "fundo_treino", "musica": "menu_treino",
		"acao": "treino"
	},
	{
		"chave": "aba_personagem", "icone": "icone_personagem", "abrev": "PJ",
		"fundo": "fundo_personagem", "musica": "menu_personagem",
		"filhos": [
			{"chave": "sub_criar", "icone": "icone_criar", "acao": "criar"},
			{"chave": "sub_editar", "icone": "icone_editar", "acao": "editar"}
		]
	}
]

var aba: int = 0
var sub: int = 0
var foco: int = 0 # 0 = linha de abas, 1 = submenu
var config_aberto: bool = false
var config_nivel: int = 0
var config_cat: int = 0
var cfg_foco: int = 0
var aviso: String = ""
var aviso_t: int = 0
var _cache: Dictionary = {}
var _eixo_estado: Dictionary = {}
var _musica_atual: String = ""

# Pedido para o editor ao abrir: "criar" ou "editar".
static var modo_editor: String = "editar"

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
	var s: String = str(_textos().t(chave))
	if (s == "" or s.contains(chave)) and RESERVA.has(chave):
		var par: Array = RESERVA[chave]
		return str(par[0]) if str(_config().idioma) == "pt" else str(par[1])
	return s

# ---------- Ciclo de vida ----------

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tocar_musica_da_aba()

func _process(_delta: float) -> void:
	if aviso_t > 0:
		aviso_t -= 1
		if aviso_t == 0:
			aviso = ""
	queue_redraw()

# ---------- Desenho ----------

func _draw() -> void:
	var fundo: Texture2D = _textura(str(ABAS[aba]["fundo"]))
	if fundo != null:
		draw_texture_rect(fundo, Rect2(0.0, 0.0, VIEW_W, VIEW_H), false)
	else:
		draw_rect(Rect2(0.0, 0.0, VIEW_W, VIEW_H), CORES[aba])
	if config_aberto:
		draw_rect(Rect2(0.0, 0.0, VIEW_W, VIEW_H), Color(0.0, 0.0, 0.0, 0.6))
	for e in _layout():
		_desenhar_entrada(e)
	if aviso_t > 0:
		draw_string(ThemeDB.fallback_font, Vector2(0.0, 250.0), aviso, HORIZONTAL_ALIGNMENT_CENTER, VIEW_W, 14, Color(1.0, 0.85, 0.5))

func _texto_c(r: Rect2, s: String, tam: int = 14, cor: Color = Color.WHITE) -> void:
	draw_string(ThemeDB.fallback_font, Vector2(r.position.x, r.position.y + r.size.y * 0.5 + tam * 0.35), s, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, tam, cor)

# Sombra preta embaixo do item selecionado: escura na borda de baixo, sumindo para cima.
func _sombra(r: Rect2) -> void:
	var y: float = r.end.y
	var pontos := PackedVector2Array([
		Vector2(r.position.x, y), Vector2(r.end.x, y),
		Vector2(r.end.x, y + SOMBRA_H), Vector2(r.position.x, y + SOMBRA_H)
	])
	var cores := PackedColorArray([
		Color(0.0, 0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0, 0.0),
		Color(0.0, 0.0, 0.0, 0.85), Color(0.0, 0.0, 0.0, 0.85)
	])
	draw_polygon(pontos, cores)

func _desenhar_entrada(e: Dictionary) -> void:
	var r: Rect2 = e["r"]
	var tipo: String = e["tipo"]
	var texto: String = str(e["label"])
	if tipo == "nada":
		_texto_c(r, texto, 14, Color(0.9, 0.9, 0.95))
		return
	var ativo: bool = e["ativo"]
	var marcado: bool = e["foco"]
	if ativo:
		draw_rect(r, Color.BLACK)
		_sombra(r)
	else:
		draw_rect(r, Color(0.05, 0.05, 0.10, 0.55))
		draw_rect(r, Color(1.0, 1.0, 1.0, 0.25), false, 1.0)
	if marcado:
		draw_rect(r, Color(1.0, 1.0, 1.0, 0.9), false, 2.0)
	var tamanho: int = 16 if tipo == "aba" else 14
	var recuo: float = 0.0
	if tipo == "aba":
		var ic := Rect2(r.position.x + 10.0, r.position.y + (r.size.y - ICONE_TAB) * 0.5, ICONE_TAB, ICONE_TAB)
		var tex: Texture2D = _textura(str(e["icone"]))
		if tex != null:
			draw_texture_rect(tex, ic, false)
		elif str(e["abrev"]) != "":
			draw_string(ThemeDB.fallback_font, Vector2(ic.position.x, ic.position.y + 22.0), str(e["abrev"]), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, Color.WHITE)
		recuo = ICONE_TAB + 10.0
	elif tipo == "sub":
		var tex2: Texture2D = _textura(str(e["icone"]))
		if tex2 != null:
			draw_texture_rect(tex2, Rect2(r.position.x + 8.0, r.position.y + 7.0, 30.0, 30.0), false)
			recuo = 40.0
	var area := Rect2(r.position.x + recuo, r.position.y, r.size.x - recuo, r.size.y)
	_texto_c(area, texto, tamanho, Color.WHITE)

# Imagens opcionais em ui/menu/<nome>.png. Ausente = null (sem erro).
func _textura(nome: String) -> Texture2D:
	if nome == "":
		return null
	var caminho: String = PASTA_MENU + nome + ".png"
	if not _cache.has(caminho):
		var t: Texture2D = null
		if ResourceLoader.exists(caminho):
			t = load(caminho) as Texture2D
		_cache[caminho] = t
	return _cache[caminho]

# ---------- Layout (fonte única para desenho e toque) ----------

func _entrada(r: Rect2, tipo: String, i: int, label: String, ativo: bool, item: Dictionary = {}) -> Dictionary:
	return {"r": r, "tipo": tipo, "i": i, "label": label, "ativo": ativo, "foco": false, "item": item, "icone": "", "abrev": ""}

func _layout() -> Array:
	var lista: Array = []
	if config_aberto:
		_layout_config(lista)
	else:
		_layout_principal(lista)
	return lista

func _rect_aba(i: int) -> Rect2:
	return Rect2(MARGEM + i * (TAB_W + TAB_GAP), TAB_Y, TAB_W, TAB_H)

func _layout_principal(lista: Array) -> void:
	lista.append(_entrada(Rect2(MARGEM, 14.0, 170.0, 36.0), "config_abrir", 0, _t("cfg_titulo"), false))
	for i in range(ABAS.size()):
		var item: Dictionary = ABAS[i]
		var e: Dictionary = _entrada(_rect_aba(i), "aba", i, _t(str(item["chave"])), i == aba, item)
		e["icone"] = str(item.get("icone", ""))
		e["abrev"] = str(item.get("abrev", ""))
		lista.append(e)

	# Submenu: lista vertical acima da aba selecionada, na borda esquerda dela.
	var filhos: Array = _filhos_aba()
	var n: int = filhos.size()
	if n > 0:
		var x: float = _rect_aba(aba).position.x
		var topo: float = TAB_Y - SUB_ACIMA_TAB - n * SUB_H - (n - 1) * SUB_GAP
		for j in range(n):
			var it: Dictionary = filhos[j]
			var r := Rect2(x, topo + j * (SUB_H + SUB_GAP), SUB_W, SUB_H)
			var e2: Dictionary = _entrada(r, "sub", j, _t(str(it["chave"])), foco == 1 and j == sub, it)
			e2["icone"] = str(it.get("icone", ""))
			e2["foco"] = foco == 0 and j == sub
			lista.append(e2)

	lista.append(_entrada(Rect2(0.0, DICA_Y - 14.0, VIEW_W, 18.0), "nada", 0, _t("dica_menu"), false))

func _layout_config(lista: Array) -> void:
	lista.append(_entrada(Rect2(40.0, 40.0, 300.0, 44.0), "nada", 0, _t("cfg_titulo"), false))
	if config_nivel == 0:
		for i in range(CFG_CATS.size()):
			lista.append(_entrada(Rect2(40.0, 110.0 + i * 64.0, 300.0, 52.0), "cfg_cat", i, _t(str(CFG_CATS[i])), false))
	else:
		var ops: Array = _opcoes_cfg(config_cat)
		if ops.is_empty():
			lista.append(_entrada(Rect2(380.0, 110.0, 340.0, 52.0), "nada", 0, _t("em_breve"), false))
		for j in range(ops.size()):
			var op: Dictionary = ops[j]
			var rotulo: String = _t(str(op["chave"]))
			if bool(op["ativo"]):
				rotulo = "[x] " + rotulo
			lista.append(_entrada(Rect2(380.0, 110.0 + j * 64.0, 340.0, 52.0), "cfg_opt", j, rotulo, false))
		if config_cat == 2:
			_info_controle(lista)
	lista.append(_entrada(Rect2(40.0, 470.0, 160.0, 50.0), "cfg_voltar", 0, _t("voltar"), false))
	var f: Array = _focaveis_cfg(lista)
	if not f.is_empty():
		var marcado: Dictionary = f[posmod(cfg_foco, f.size())]
		marcado["ativo"] = true

func _info_controle(lista: Array) -> void:
	var cfg: Variant = _config()
	var conectado: bool = bool(cfg.controle_conectado)
	var nome: String = str(cfg.controle_nome) if conectado else "-"
	var ult: String = str(cfg.ultimo_botao)
	if ult == "":
		ult = "-"
	var modo: String = _t("modo_ativo") + ": " + _t("modo_" + str(cfg.modo_efetivo()))
	lista.append(_entrada(Rect2(380.0, 330.0, 340.0, 26.0), "nada", 0, modo, false))
	lista.append(_entrada(Rect2(380.0, 366.0, 340.0, 26.0), "nada", 0, _t("ctrl_nome") + ": " + nome, false))
	lista.append(_entrada(Rect2(380.0, 396.0, 340.0, 26.0), "nada", 0, _t("ctrl_ultimo") + ": " + ult, false))

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
	var item: Dictionary = ABAS[aba]
	return item.get("filhos", [])

# ---------- Entrada ----------

func _unhandled_input(ev: InputEvent) -> void:
	var st := ev as InputEventScreenTouch
	if st != null and st.pressed:
		_tocar(st.position)
		get_viewport().set_input_as_handled()
		return
	var bt := ev as InputEventJoypadButton
	if bt != null and bt.pressed:
		_botao(int(bt.button_index))
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
	var agora: int = 0
	if v > LIMIAR_STICK:
		agora = 1
	elif v < -LIMIAR_STICK:
		agora = -1
	var antes: int = int(_eixo_estado.get(eixo, 0))
	_eixo_estado[eixo] = agora
	if agora == 0 or agora == antes:
		return
	if eixo == JOY_AXIS_LEFT_X:
		_botao(JOY_BUTTON_DPAD_RIGHT if agora > 0 else JOY_BUTTON_DPAD_LEFT)
	else:
		_botao(JOY_BUTTON_DPAD_DOWN if agora > 0 else JOY_BUTTON_DPAD_UP)

func _tocar(p: Vector2) -> void:
	var e: Dictionary = _acertar(p)
	if not e.is_empty():
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
			_abrir_config()
		"cfg_cat":
			config_cat = i
			config_nivel = 1
			cfg_foco = 0
			_som("menu_confirma")
		"cfg_opt":
			_aplicar_cfg(i)
		"cfg_voltar":
			_voltar_config()
		"aba":
			_selecionar_aba(i)
			var it: Dictionary = ABAS[i]
			if it.has("acao"):
				_executar(it)
		"sub":
			foco = 1
			sub = i
			_executar(item)

func _botao(b: int) -> void:
	if config_aberto:
		_botao_config(b)
		return
	if b == JOY_BUTTON_DPAD_LEFT:
		_mover(-1)
	elif b == JOY_BUTTON_DPAD_RIGHT:
		_mover(1)
	elif b == JOY_BUTTON_DPAD_UP:
		if foco == 1:
			foco = 0
			_som("menu_mover")
	elif b == JOY_BUTTON_DPAD_DOWN:
		if foco == 0 and not _filhos_aba().is_empty():
			foco = 1
			sub = 0
			_som("menu_mover")
	elif b == JOY_BUTTON_A:
		_confirmar()
	elif b == JOY_BUTTON_B:
		if foco == 1:
			foco = 0
			_som("menu_voltar")

func _botao_config(b: int) -> void:
	if b == JOY_BUTTON_DPAD_UP:
		_mover_foco_cfg(-1)
	elif b == JOY_BUTTON_DPAD_DOWN:
		_mover_foco_cfg(1)
	elif b == JOY_BUTTON_A:
		_acionar_foco_cfg()
	elif b == JOY_BUTTON_B:
		_voltar_config()

# Esquerda/direita: na linha de abas troca a aba; no submenu troca o item.
func _mover(d: int) -> void:
	if foco == 0:
		_selecionar_aba(posmod(aba + d, ABAS.size()))
	else:
		var n: int = _filhos_aba().size()
		if n > 0:
			sub = posmod(sub + d, n)
			_som("menu_mover")

func _selecionar_aba(i: int) -> void:
	if i != aba:
		aba = i
		sub = 0
		_som("menu_mover")
		_tocar_musica_da_aba()
	if _filhos_aba().is_empty():
		foco = 0

func _confirmar() -> void:
	if foco == 0:
		var item: Dictionary = ABAS[aba]
		if item.has("filhos"):
			foco = 1
			sub = 0
			_som("menu_confirma")
		else:
			_executar(item)
	else:
		var f: Array = _filhos_aba()
		if not f.is_empty():
			_executar(f[sub])

func _abrir_config() -> void:
	config_aberto = true
	config_nivel = 0
	cfg_foco = 0
	_som("menu_confirma")
	_tocar_musica("menu_configuracoes")

func _voltar_config() -> void:
	if config_nivel == 1:
		config_nivel = 0
		cfg_foco = config_cat
		_som("menu_voltar")
		return
	config_aberto = false
	_som("menu_voltar")
	_tocar_musica_da_aba()

func _mover_foco_cfg(d: int) -> void:
	var f: Array = _focaveis_cfg(_layout())
	if f.is_empty():
		return
	cfg_foco = posmod(cfg_foco + d, f.size())
	_som("menu_mover")

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
			_som("menu_confirma")
			_avisar()

func _avisar() -> void:
	aviso = _t("em_breve")
	aviso_t = TEMPO_AVISO

func _som(nome: String) -> void:
	_audio().tocar_interface(nome)

# ---------- Música ----------

func _tocar_musica_da_aba() -> void:
	_tocar_musica(str(ABAS[aba]["musica"]))

func _tocar_musica(nome: String) -> void:
	if nome == _musica_atual:
		return
	_musica_atual = nome
	_audio().tocar_musica(nome, true)