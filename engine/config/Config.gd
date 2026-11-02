extends Node

# Configurações do aparelho, salvas em user://config.json.
# Não contém nada de personagem ou conteúdo do jogo.
# Controle é detectado de três jeitos: lista de controles, sinal de conexão e
# qualquer botão ou analógico apertado. Nome do controle e último botão ficam
# guardados para aparecer na tela de Controle.

signal modo_entrada_mudou(modo: String)
signal idioma_mudou

const ARQUIVO := "user://config.json"
const MODOS := ["automatico", "touch", "controle"]
const IDIOMAS := ["pt", "en"]
const INTERVALO_CHECAGEM := 0.5
const LIMIAR_ANALOGICO := 0.5

var modo_escolhido := "automatico"
var idioma := "pt"
var em_luta := false
var controle_conectado := false
var controle_nome := ""
var ultimo_botao := ""
var _modo_anterior := ""
var _tempo_checagem := 0.0


func _ready() -> void:
	_carregar()
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


func _salvar() -> void:
	var f := FileAccess.open(ARQUIVO, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"modo": modo_escolhido, "idioma": idioma}))