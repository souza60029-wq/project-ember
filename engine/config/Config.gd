extends Node

# Configurações do aparelho, salvas em user://config.json.
# Não contém nada de personagem ou conteúdo do jogo.
# Controle é detectado de três jeitos: lista de controles, sinal de conexão e
# qualquer botão ou analógico apertado. Nome do controle e último botão ficam
# guardados para aparecer na tela de Controle.

signal modo_entrada_mudou(modo: String)
signal idioma_mudou
signal debug_mudou(ligado: bool)
signal mapa_mudou

const ARQUIVO := "user://config.json"
const MODOS := ["automatico", "touch", "controle"]
const IDIOMAS := ["pt", "en"]
const INTERVALO_CHECAGEM := 0.5
const LIMIAR_ANALOGICO := 0.5
const ROTACOES := ["automatica", "paisagem", "invertida"]
const HUD_MODOS := ["desligado", "retangulo", "quadrado"]
# Botões do controle que podem ser mapeados, e as funções de luta que podem receber.
const BOTOES_FISICOS := ["A", "B", "X", "Y", "LB", "RB", "LT", "RT"]
const FUNCOES := ["LP", "LK", "HP", "HK", "BO", "ESQ", ""]
const LIMIAR_GATILHO := 0.5

var modo_escolhido := "automatico"
var idioma := "pt"
var em_luta := false
# Modo debug: mostra hitboxes, hurtboxes e dados de combate. Padrão: desligado.
var debug_hitboxes := false
# Rotação da tela: automática (segue o aparelho), paisagem ou paisagem invertida.
var rotacao := "automatica"
# HUD do sistema: desligado, retângulo ou quadrado (arrastável). Posição salva.
var hud_modo := "desligado"
var hud_pos := Vector2(16.0, 70.0)
# Mapa de botões da luta: jogador (1 ou 2) -> {botão do controle: função}.
var mapas := {}
var _hud: Node = null
var controle_conectado := false
var controle_nome := ""
var ultimo_botao := ""
var _modo_anterior := ""
var _tempo_checagem := 0.0


func _ready() -> void:
	mapas = {1: mapa_padrao(), 2: mapa_padrao()}
	_carregar()
	_aplicar_rotacao()
	_hud = preload("res://engine/sistema/HudSistema.gd").new()
	add_child(_hud)
	Input.joy_connection_changed.connect(_on_joy_mudou)
	_checar_controles()
	_modo_anterior = modo_efetivo()


func _process(delta: float) -> void:
	_tempo_checagem += delta
	if _tempo_checagem >= INTERVALO_CHECAGEM:
		_tempo_checagem = 0.0
		_checar_controles()


# Qualquer botão ou analógico apertado também conta como controle conectado.
func _input(ev: InputEvent) -> void:
	var bt := ev as InputEventJoypadButton
	if bt != null and bt.pressed:
		ultimo_botao = "botão %d" % bt.button_index
		_marcar_controle(bt.device)
		return
	var mv := ev as InputEventJoypadMotion
	if mv != null and absf(mv.axis_value) > LIMIAR_ANALOGICO:
		_marcar_controle(mv.device)


# Modo que a luta usa de fato. "controle" só vale com controle conectado.
func modo_efetivo() -> String:
	if modo_escolhido != "touch" and controle_conectado:
		return "controle"
	return "touch"


func modo_seguinte() -> String:
	var i := MODOS.find(modo_escolhido)
	return MODOS[(i + 1) % MODOS.size()]


func definir_modo(modo: String) -> void:
	if not MODOS.has(modo):
		return
	modo_escolhido = modo
	_salvar()
	_checar_modo()


func definir_idioma(novo: String) -> void:
	if not IDIOMAS.has(novo) or novo == idioma:
		return
	idioma = novo
	_salvar()
	idioma_mudou.emit()


func definir_debug(ligado: bool) -> void:
	if ligado == debug_hitboxes:
		return
	debug_hitboxes = ligado
	_salvar()
	debug_mudou.emit(ligado)


func definir_rotacao(r: String) -> void:
	if not ROTACOES.has(r) or r == rotacao:
		return
	rotacao = r
	_salvar()
	_aplicar_rotacao()


func _aplicar_rotacao() -> void:
	match rotacao:
		"paisagem":
			DisplayServer.screen_set_orientation(DisplayServer.SCREEN_LANDSCAPE)
		"invertida":
			DisplayServer.screen_set_orientation(DisplayServer.SCREEN_REVERSE_LANDSCAPE)
		_:
			DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE)


func definir_hud(m: String) -> void:
	if not HUD_MODOS.has(m) or m == hud_modo:
		return
	hud_modo = m
	_salvar()
	if _hud != null:
		_hud.atualizar_modo()


func definir_hud_pos(p: Vector2) -> void:
	hud_pos = p
	_salvar()


# ---------- Mapa de botões do controle ----------

static func mapa_padrao() -> Dictionary:
	return {"A": "LK", "B": "HK", "X": "LP", "Y": "HP", "LB": "ESQ", "RB": "BO", "LT": "", "RT": ""}


func mapa(jogador: int) -> Dictionary:
	return mapas[jogador]


func definir_funcao(jogador: int, botao: String, funcao: String) -> void:
	if not BOTOES_FISICOS.has(botao) or not FUNCOES.has(funcao):
		return
	(mapas[jogador] as Dictionary)[botao] = funcao
	_salvar()
	mapa_mudou.emit()


func restaurar_mapa(jogador: int) -> void:
	mapas[jogador] = mapa_padrao()
	_salvar()
	mapa_mudou.emit()


func botao_fisico_apertado(dev: int, botao: String) -> bool:
	match botao:
		"A":
			return Input.is_joy_button_pressed(dev, JOY_BUTTON_A)
		"B":
			return Input.is_joy_button_pressed(dev, JOY_BUTTON_B)
		"X":
			return Input.is_joy_button_pressed(dev, JOY_BUTTON_X)
		"Y":
			return Input.is_joy_button_pressed(dev, JOY_BUTTON_Y)
		"LB":
			return Input.is_joy_button_pressed(dev, JOY_BUTTON_LEFT_SHOULDER)
		"RB":
			return Input.is_joy_button_pressed(dev, JOY_BUTTON_RIGHT_SHOULDER)
		"LT":
			return Input.get_joy_axis(dev, JOY_AXIS_TRIGGER_LEFT) > LIMIAR_GATILHO
		"RT":
			return Input.get_joy_axis(dev, JOY_AXIS_TRIGGER_RIGHT) > LIMIAR_GATILHO
	return false


# Botões de luta apertados no controle "dev", pelo mapa do jogador.
func entrada_luta(dev: int, jogador: int) -> Dictionary:
	var r := {"LP": false, "LK": false, "HP": false, "HK": false, "BO": false, "ESQ": false}
	var m: Dictionary = mapas[jogador]
	for b in BOTOES_FISICOS:
		var f: String = str(m.get(b, ""))
		if f != "" and r.has(f) and botao_fisico_apertado(dev, str(b)):
			r[f] = true
	return r


# Controle de PlayStation? Muda os ícones (✕ ○ □ △) nas dicas de tela.
func controle_ps() -> bool:
	var n: String = controle_nome.to_lower()
	return n.contains("ps") or n.contains("playstation") or n.contains("dualshock") or n.contains("dualsense") or n.contains("sony")


# ---------- Detecção de controle ----------

func _on_joy_mudou(dispositivo: int, conectado: bool) -> void:
	if conectado:
		_marcar_controle(dispositivo)
		return
	var restantes: Array = Input.get_connected_joypads()
	restantes.erase(dispositivo)
	_usar_lista(restantes)


func _checar_controles() -> void:
	_usar_lista(Input.get_connected_joypads())


func _usar_lista(lista: Array) -> void:
	if lista.is_empty():
		controle_nome = ""
		_definir_conectado(false)
	else:
		_marcar_controle(int(lista[0]))


func _marcar_controle(dispositivo: int) -> void:
	var nome: String = Input.get_joy_name(dispositivo)
	controle_nome = nome if nome != "" else "Controle"
	_definir_conectado(true)


func _definir_conectado(ok: bool) -> void:
	if ok == controle_conectado:
		return
	controle_conectado = ok
	_checar_modo()


func _checar_modo() -> void:
	var m := modo_efetivo()
	if m != _modo_anterior:
		_modo_anterior = m
		modo_entrada_mudou.emit(m)


# ---------- Arquivo ----------

func _carregar() -> void:
	if not FileAccess.file_exists(ARQUIVO):
		return
	var dados = JSON.parse_string(FileAccess.get_file_as_string(ARQUIVO))
	if typeof(dados) != TYPE_DICTIONARY:
		return
	var m := str(dados.get("modo", "automatico"))
	var i := str(dados.get("idioma", "pt"))
	if MODOS.has(m):
		modo_escolhido = m
	if IDIOMAS.has(i):
		idioma = i
	debug_hitboxes = bool(dados.get("debug", false))
	var rot := str(dados.get("rotacao", "automatica"))
	if ROTACOES.has(rot):
		rotacao = rot
	var hm := str(dados.get("hud", "desligado"))
	if HUD_MODOS.has(hm):
		hud_modo = hm
	var hp = dados.get("hud_pos", [16.0, 70.0])
	if typeof(hp) == TYPE_ARRAY and hp.size() == 2:
		hud_pos = Vector2(float(hp[0]), float(hp[1]))
	var ms = dados.get("mapas", {})
	if typeof(ms) == TYPE_DICTIONARY:
		for j in [1, 2]:
			var mj = ms.get(str(j), {})
			if typeof(mj) == TYPE_DICTIONARY:
				for b in BOTOES_FISICOS:
					if mj.has(b) and FUNCOES.has(str(mj[b])):
						(mapas[j] as Dictionary)[b] = str(mj[b])


func _salvar() -> void:
	var f := FileAccess.open(ARQUIVO, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"modo": modo_escolhido, "idioma": idioma, "debug": debug_hitboxes, "rotacao": rotacao, "hud": hud_modo, "hud_pos": [hud_pos.x, hud_pos.y], "mapas": {"1": mapas[1], "2": mapas[2]}}))