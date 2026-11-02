extends Control

# Tela de título: espera START (ou A) no controle, ou um toque na tela.
# Logo em ui/logo.png; fundo em ui/fundo_titulo.png (opcional); música em musica/titulo.
# Autoloads são acessados por get_node (não pelo nome), para o script compilar sem eles.

const FUNDO := "res://ui/fundo_titulo.png"
const LOGO := "res://ui/logo.png"
const VIEW_W := 960.0
const VIEW_H := 540.0
const PISCAR_VELOCIDADE := 3.0

var _fundo: Texture2D = null
var _logo: Texture2D = null
var _tempo := 0.0
var _saindo := false


func _audio() -> Variant:
	return get_node("/root/Audio")


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


func _draw() -> void:
	if _fundo != null:
		draw_texture_rect(_fundo, Rect2(0.0, 0.0, VIEW_W, VIEW_H), false)
	else:
		draw_rect(Rect2(0.0, 0.0, VIEW_W, VIEW_H), Color.BLACK)
	if _logo != null:
		var tam := _logo.get_size()
		var escala := minf(1.0, minf(VIEW_W * 0.6 / tam.x, VIEW_H * 0.5 / tam.y))
		var w := tam * escala
		draw_texture_rect(_logo, Rect2((VIEW_W - w.x) * 0.5, 60.0, w.x, w.y), false)
	var brilho := 0.5 + 0.5 * sin(_tempo * PISCAR_VELOCIDADE)
	draw_string(ThemeDB.fallback_font, Vector2(0.0, 440.0), "TOQUE NA TELA OU APERTE START", HORIZONTAL_ALIGNMENT_CENTER, VIEW_W, 20, Color(1.0, 1.0, 1.0, 0.4 + 0.6 * brilho))


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
	_audio().tocar_interface("menu_confirma")
	_navegacao().ir_para_menu()