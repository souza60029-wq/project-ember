extends Control

# Tela de título: espera START (ou A) no controle, ou um toque na tela.
# Texto: "TOQUE NA TELA" com toque; "APERTE START" quando o modo ativo é controle.
# Esta tela mostra também o AVISO de projeto de fã (textos aviso_titulo e aviso_corpo em Textos.gd).
# Logo em ui/logo.png; fundo em ui/fundo_titulo.png (opcional); música em musica/titulo.
# Autoloads são acessados por get_node (não pelo nome), para o script compilar sem eles.

const FUNDO := "res://ui/fundo_titulo.png"
const LOGO := "res://ui/logo.png"
const VIEW_W := 960.0
const VIEW_H := 540.0
const PISCAR_VELOCIDADE := 3.0
const Y_TEXTO := 462.0

var _fundo: Texture2D = null
var _logo: Texture2D = null
var _tempo := 0.0
var _saindo := false


func _audio() -> Variant:
	return get_node("/root/Audio")


func _config() -> Variant:
	return get_node("/root/Config")


func _textos() -> Variant:
	return get_node("/root/Textos")


func _navegacao() -> Variant:
	return get_node("/root/Navegacao")


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(FUNDO):
		_fundo = load(FUNDO) as Texture2D
	if ResourceLoader.exists(LOGO):
		_logo = load(LOGO) as Texture2D
	_audio().tocar_musica("titulo", true)


func _process(delta: float) -> void:
	_tempo += delta
	queue_redraw()


func _texto_entrada() -> String:
	var controle: bool = str(_config().modo_efetivo()) == "controle"
	return str(_textos().t("tela_start" if controle else "tela_toque"))


func _draw() -> void:
	if _fundo != null:
		draw_texture_rect(_fundo, Rect2(0.0, 0.0, VIEW_W, VIEW_H), false)
	else:
		draw_rect(Rect2(0.0, 0.0, VIEW_W, VIEW_H), Color.BLACK)
	# Painel do aviso por cima da arte.
	var painel := Rect2(80.0, 40.0, VIEW_W - 160.0, 372.0)
	draw_rect(painel, Color(0.0, 0.0, 0.0, 0.72))
	draw_rect(painel, Color(1.0, 1.0, 1.0, 0.35), false, 2.0)
	var fonte: Font = ThemeDB.fallback_font
	draw_string(fonte, Vector2(painel.position.x, painel.position.y + 34.0), str(_textos().t("aviso_titulo")), HORIZONTAL_ALIGNMENT_CENTER, painel.size.x, 24, Color(1.0, 0.85, 0.4))
	draw_multiline_string(fonte, Vector2(painel.position.x + 24.0, painel.position.y + 64.0), str(_textos().t("aviso_corpo")), HORIZONTAL_ALIGNMENT_LEFT, painel.size.x - 48.0, 14, -1, Color(0.95, 0.95, 0.95))
	var brilho := 0.5 + 0.5 * sin(_tempo * PISCAR_VELOCIDADE)
	draw_string(fonte, Vector2(0.0, Y_TEXTO), _texto_entrada(), HORIZONTAL_ALIGNMENT_CENTER, VIEW_W, 22, Color(1.0, 1.0, 1.0, 0.4 + 0.6 * brilho))


func _unhandled_input(ev: InputEvent) -> void:
	var st := ev as InputEventScreenTouch
	var bt := ev as InputEventJoypadButton
	var entrou := false
	if st != null and st.pressed:
		entrou = true
	if bt != null and bt.pressed and (bt.button_index == JOY_BUTTON_START or bt.button_index == JOY_BUTTON_A):
		entrou = true
	if entrou:
		get_viewport().set_input_as_handled()
		_entrar()


func _entrar() -> void:
	if _saindo:
		return
	_saindo = true
	_audio().tocar_interface_ou("start", "menu_confirma")
	_navegacao().ir_para_menu()