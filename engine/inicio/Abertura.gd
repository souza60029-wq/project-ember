extends Control

# Abertura: "feito com a Ember Engine". Duas imagens que juntas formam a tela:
#   ui/ember/fundo.png (fundo, ocupa a tela toda) e ui/ember/logo.png (logo, centralizada).
# Separadas para você reaproveitar em outras telas. Se faltarem, usa fundo preto e o texto EMBER ENGINE.
# Some sozinha e passa para o título. Toque ou START pula.

const CENA_TITULO := "res://engine/inicio/Titulo.tscn"
const LOGO := "res://ui/ember/logo.png"
const FUNDO := "res://ui/ember/fundo.png"
const VIEW_W := 960.0
const VIEW_H := 540.0
const TEMPO_ENTRADA := 0.8
const TEMPO_LOGO := 2.0
const TEMPO_SAIDA := 0.6

var _logo: Texture2D = null
var _fundo: Texture2D = null
var _tempo := 0.0
var _saindo := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(LOGO):
		_logo = load(LOGO) as Texture2D
	if ResourceLoader.exists(FUNDO):
		_fundo = load(FUNDO) as Texture2D


func _process(delta: float) -> void:
	_tempo += delta
	if _tempo >= TEMPO_ENTRADA + TEMPO_LOGO + TEMPO_SAIDA:
		_ir_titulo()
	queue_redraw()


func _alpha() -> float:
	var fim_logo := TEMPO_ENTRADA + TEMPO_LOGO
	if _tempo < TEMPO_ENTRADA:
		return _tempo / TEMPO_ENTRADA
	if _tempo < fim_logo:
		return 1.0
	return clampf(1.0 - (_tempo - fim_logo) / TEMPO_SAIDA, 0.0, 1.0)


func _draw() -> void:
	draw_rect(Rect2(0.0, 0.0, VIEW_W, VIEW_H), Color.BLACK)
	var a := _alpha()
	if _fundo != null:
		draw_texture_rect(_fundo, Rect2(0.0, 0.0, VIEW_W, VIEW_H), false, Color(1.0, 1.0, 1.0, a))
	if _logo != null:
		var tam := _logo.get_size()
		var escala := minf(VIEW_W * 0.7 / tam.x, VIEW_H * 0.8 / tam.y)
		var w := tam * escala
		draw_texture_rect(_logo, Rect2((VIEW_W - w.x) * 0.5, (VIEW_H - w.y) * 0.5, w.x, w.y), false, Color(1.0, 1.0, 1.0, a))
	else:
		draw_string(ThemeDB.fallback_font, Vector2(0.0, VIEW_H * 0.5), "EMBER ENGINE", HORIZONTAL_ALIGNMENT_CENTER, VIEW_W, 36, Color(1.0, 1.0, 1.0, a))


func _unhandled_input(ev: InputEvent) -> void:
	var st := ev as InputEventScreenTouch
	var bt := ev as InputEventJoypadButton
	if (st != null and st.pressed) or (bt != null and bt.pressed and bt.button_index == JOY_BUTTON_START):
		get_viewport().set_input_as_handled()
		_ir_titulo()


func _ir_titulo() -> void:
	if _saindo:
		return
	_saindo = true
	get_tree().change_scene_to_file(CENA_TITULO)