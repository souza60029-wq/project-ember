extends Node

# Configurações do aparelho, salvas em user://config.json.
# Não contém nada de personagem ou conteúdo do jogo.

signal modo_entrada_mudou(modo: String)
signal idioma_mudou

const ARQUIVO := "user://config.json"
const MODOS := ["automatico", "touch", "controle"]
const IDIOMAS := ["pt", "en"]

var modo_escolhido := "automatico"
var idioma := "pt"
var em_luta := false
var controle_conectado := false
var _modo_anterior := ""


func _ready() -> void:
	_carregar()
	controle_conectado = Input.get_connected_joypads().size() > 0
	Input.joy_connection_changed.connect(_on_joy_mudou)
	_modo_anterior = modo_efetivo()


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


func _on_joy_mudou(_dispositivo: int, _conectado: bool) -> void:
	controle_conectado = Input.get_connected_joypads().size() > 0
	_checar_modo()


func _checar_modo() -> void:
	var m := modo_efetivo()
	if m != _modo_anterior:
		_modo_anterior = m
		modo_entrada_mudou.emit(m)


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