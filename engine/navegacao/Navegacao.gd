extends CanvasLayer

# Troca de cena com fade preto. Também mostra o botão MENU durante a luta.

const CENA_MENU := "res://engine/menu/Menu.tscn"
const CENA_LUTA := "res://engine/luta/Luta.tscn"
const CENA_SELECAO := "res://engine/selecao/Selecao.tscn"
const FADE_INICIAL := 1.2
const FADE_SAIDA := 0.35
const FADE_ENTRADA := 0.35


class BotaoVoltar extends Control:
	signal pressionado

	func _ready() -> void:
		position = Vector2(10, 8)
		size = Vector2(110, 34)
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.1, 0.1, 0.14, 0.9))
		draw_string(ThemeDB.fallback_font, Vector2(0, 23), Textos.t("menu_luta"),
			HORIZONTAL_ALIGNMENT_CENTER, size.x, 16, Color.WHITE)

	func _gui_input(event: InputEvent) -> void:
		var disparou := false
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			disparou = mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
		elif event is InputEventScreenTouch:
			disparou = (event as InputEventScreenTouch).pressed
		if disparou:
			accept_event()
			pressionado.emit()


# Modo escolhido no menu e personagens escolhidos na seleção (ids do Catalogo).
var modo_luta: String = "treino"
var selecao: Dictionary = {"p1": "", "p2": ""}

var _cobertura: ColorRect
var _botao: BotaoVoltar
var _tween: Tween
var _ocupado := false


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS

	_cobertura = ColorRect.new()
	_cobertura.color = Color.BLACK
	_cobertura.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cobertura.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_cobertura)

	_botao = BotaoVoltar.new()
	_botao.visible = false
	_botao.pressionado.connect(ir_para_menu)
	add_child(_botao)

	# Começa preto e revela.
	_tween = create_tween()
	_tween.tween_interval(0.2)
	_tween.tween_property(_cobertura, "modulate:a", 0.0, FADE_INICIAL)
	_tween.tween_callback(_liberar)


func ir_para_luta() -> void:
	_ir(CENA_LUTA, true)


# Todo modo que leva a uma luta passa antes pela seleção de personagens.
func ir_para_selecao(modo: String) -> void:
	modo_luta = modo
	_ir(CENA_SELECAO, false)


func ir_para_menu() -> void:
	_ir(CENA_MENU, false)


func _ir(caminho: String, em_luta: bool) -> void:
	if _ocupado:
		return
	_ocupado = true
	_cobertura.mouse_filter = Control.MOUSE_FILTER_STOP
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_cobertura, "modulate:a", 1.0, FADE_SAIDA)
	_tween.tween_callback(_trocar.bind(caminho, em_luta))


func _trocar(caminho: String, em_luta: bool) -> void:
	Config.em_luta = em_luta
	_botao.visible = em_luta
	get_tree().change_scene_to_file(caminho)
	_tween = create_tween()
	_tween.tween_interval(0.05)
	_tween.tween_property(_cobertura, "modulate:a", 0.0, FADE_ENTRADA)
	_tween.tween_callback(_liberar)


func _liberar() -> void:
	_ocupado = false
	_cobertura.mouse_filter = Control.MOUSE_FILTER_IGNORE