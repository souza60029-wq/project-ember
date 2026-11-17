extends Control

# HUD do sistema (Configurações > Tela > HUD do sistema). Arrastável pela tela toda.
# Duas formas: "retangulo" (texto) e "quadrado" (com ícones e a moldura do aparelho).
# Atualiza a cada 1 s. Mostra: aparelho, GPU, FPS, CPU, GPU, RAM e bateria.
# CPU e GPU são estimativas do próprio motor (tempo de processamento do jogo por quadro,
# e tempo de render da GPU quando o renderizador informa); o Godot não lê o uso total do sistema.
# Ícones dos chips em engine/sistema/icones/ (snapdragon, exynos, mali, android, apple):
# troque pelos arquivos oficiais, com o mesmo nome, se quiser.

const Sprites = preload("res://engine/nucleo/Sprites.gd")

const ICONES := "res://engine/sistema/icones/"
const INTERVALO := 1.0
const ALTURA_RETANGULO: float = 40.0

# iPhones pelo identificador interno (ex.: iPhone14,2): nome comercial.
const IPHONES := {
	"iPhone8,1": "iPhone 6s", "iPhone8,2": "iPhone 6s Plus", "iPhone8,4": "iPhone SE (1a gen)",
	"iPhone9,1": "iPhone 7", "iPhone9,3": "iPhone 7", "iPhone9,2": "iPhone 7 Plus", "iPhone9,4": "iPhone 7 Plus",
	"iPhone10,1": "iPhone 8", "iPhone10,4": "iPhone 8", "iPhone10,2": "iPhone 8 Plus", "iPhone10,5": "iPhone 8 Plus",
	"iPhone10,3": "iPhone X", "iPhone10,6": "iPhone X",
	"iPhone11,2": "iPhone XS", "iPhone11,4": "iPhone XS Max", "iPhone11,6": "iPhone XS Max", "iPhone11,8": "iPhone XR",
	"iPhone12,1": "iPhone 11", "iPhone12,3": "iPhone 11 Pro", "iPhone12,5": "iPhone 11 Pro Max", "iPhone12,8": "iPhone SE (2a gen)",
	"iPhone13,1": "iPhone 12 mini", "iPhone13,2": "iPhone 12", "iPhone13,3": "iPhone 12 Pro", "iPhone13,4": "iPhone 12 Pro Max",
	"iPhone14,4": "iPhone 13 mini", "iPhone14,5": "iPhone 13", "iPhone14,2": "iPhone 13 Pro", "iPhone14,3": "iPhone 13 Pro Max",
	"iPhone14,6": "iPhone SE (3a gen)", "iPhone14,7": "iPhone 14", "iPhone14,8": "iPhone 14 Plus",
	"iPhone15,2": "iPhone 14 Pro", "iPhone15,3": "iPhone 14 Pro Max", "iPhone15,4": "iPhone 15", "iPhone15,5": "iPhone 15 Plus",
	"iPhone16,1": "iPhone 15 Pro", "iPhone16,2": "iPhone 15 Pro Max",
	"iPhone17,1": "iPhone 16 Pro", "iPhone17,2": "iPhone 16 Pro Max", "iPhone17,3": "iPhone 16", "iPhone17,4": "iPhone 16 Plus", "iPhone17,5": "iPhone 16e",
	"iPhone18,1": "iPhone 17 Pro", "iPhone18,2": "iPhone 17 Pro Max", "iPhone18,3": "iPhone 17", "iPhone18,4": "iPhone Air",
}
# Resolução da tela (maior lado, menor lado) -> [descrição, moldura]. Usada quando o identificador não é conhecido.
const RESOLUCOES := {
	Vector2i(1136, 640): ["iPhone SE / 5s", "home"],
	Vector2i(1334, 750): ["iPhone 6/7/8/SE", "home"],
	Vector2i(1920, 1080): ["iPhone Plus (6/7/8)", "home"],
	Vector2i(2436, 1125): ["iPhone X/XS/11 Pro", "notch"],
	Vector2i(2688, 1242): ["iPhone XS Max/11 Pro Max", "notch"],
	Vector2i(1792, 828): ["iPhone XR/11", "notch"],
	Vector2i(2340, 1080): ["iPhone 12/13 mini", "notch"],
	Vector2i(2532, 1170): ["iPhone 12/13/14", "notch"],
	Vector2i(2778, 1284): ["iPhone 12/13 Pro Max, 14 Plus", "notch"],
	Vector2i(2556, 1179): ["iPhone 14 Pro/15/16", "island"],
	Vector2i(2796, 1290): ["iPhone 14 Pro Max/15 Plus/16 Plus", "island"],
	Vector2i(2622, 1206): ["iPhone 16 Pro/17", "island"],
	Vector2i(2868, 1320): ["iPhone 16 Pro Max", "island"],
	Vector2i(2736, 1260): ["iPhone Air", "island"],
}
const TAM_QUADRADO := Vector2(210.0, 214.0)
const COR_FUNDO := Color(0.04, 0.05, 0.1, 0.84)
const COR_BORDA := Color(1.0, 0.55, 0.2, 0.9)
const COR_TEXTO := Color(0.94, 0.94, 1.0)
const COR_SUAVE := Color(0.7, 0.72, 0.85)

var _painel: Control
var _tempo: float = 0.0
var _acum_proc: float = 0.0
var _acum_dt: float = 0.0
var _arrastando: bool = false
var _aparelho: String = ""
var _gpu_nome: String = ""
var _soc: String = "generico"
var _iphone: String = ""
var _fps: int = 0
var _cpu: float = 0.0
var _gpu: float = -1.0
var _ram_mb: float = 0.0
var _bateria: int = -1
var _carregando: bool = false


func _config() -> Variant:
	return get_node("/root/Config")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_painel = Control.new()
	_painel.mouse_filter = Control.MOUSE_FILTER_STOP
	_painel.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_painel.draw.connect(_desenhar)
	_painel.gui_input.connect(_on_gui)
	add_child(_painel)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	_config().hud_mudou.connect(atualizar_modo)
	_ler_aparelho()
	atualizar_modo()


func atualizar_modo() -> void:
	var modo: String = str(_config().hud_modo)
	visible = modo != "desligado"
	set_process(visible)
	if not visible:
		return
	_painel.size = TAM_QUADRADO if modo == "quadrado" else Vector2(430.0, ALTURA_RETANGULO)
	_painel.position = _limitar(_config().hud_pos)
	_coletar()
	_painel.queue_redraw()


func _process(delta: float) -> void:
	_acum_proc += Performance.get_monitor(Performance.TIME_PROCESS) + Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
	_acum_dt += delta
	_tempo += delta
	if _tempo >= INTERVALO:
		_tempo = 0.0
		_coletar()
		visible = str(_config().hud_modo) != "desligado"
		_painel.position = _limitar(_painel.position)
	_painel.queue_redraw()


# ---------- Coleta ----------

func _ler_aparelho() -> void:
	var os_nome: String = OS.get_name()
	var bruto: String = OS.get_model_name()
	_aparelho = bruto
	if _aparelho == "" or _aparelho == "GenericDevice":
		_aparelho = os_nome
	_gpu_nome = RenderingServer.get_video_adapter_name()
	var g: String = _gpu_nome.to_lower()
	if os_nome == "iOS":
		_soc = "apple"
		_iphone = _tipo_iphone(bruto)
		_aparelho = _nome_iphone(bruto)
	elif os_nome == "Android":
		if g.contains("adreno"):
			_soc = "snapdragon"
		elif g.contains("xclipse"):
			_soc = "exynos"
		elif g.contains("mali"):
			_soc = "mali"
		else:
			_soc = "android"
	else:
		_soc = "generico"


# Resolução da tela na forma (maior lado, menor lado).
func _resolucao() -> Vector2i:
	var t: Vector2i = DisplayServer.screen_get_size()
	return Vector2i(maxi(t.x, t.y), mini(t.x, t.y))


# Nome do iPhone: pelo identificador (iPhone10,4); se não for conhecido, pela resolução da tela.
func _nome_iphone(bruto: String) -> String:
	if IPHONES.has(bruto):
		return str(IPHONES[bruto])
	var res: Vector2i = _resolucao()
	if RESOLUCOES.has(res):
		return str((RESOLUCOES[res] as Array)[0])
	return bruto if bruto.begins_with("iPhone") else "iPhone"


# "home" (botão home), "notch" (entalhe) ou "island" (Dynamic Island).
# Pelo identificador do modelo (ex.: iPhone14,2); se não der, pela área segura da tela.
# "home" (botão home), "notch" (entalhe) ou "island" (Dynamic Island).
# Pelo identificador do modelo; se não for conhecido, pela resolução da tela; por último, pela área segura.
func _tipo_iphone(modelo: String) -> String:
	if modelo.begins_with("iPhone") and modelo.contains(","):
		var partes: PackedStringArray = modelo.trim_prefix("iPhone").split(",")
		var maior: int = int(partes[0])
		var menor: int = int(partes[1])
		if maior <= 9:
			return "home"
		if maior == 10:
			return "home" if menor in [1, 2, 4, 5] else "notch"
		if maior == 12 and menor == 8:
			return "home"
		if maior == 14 and menor == 6:
			return "home"
		if maior <= 14:
			return "notch"
		if maior == 15 and menor in [2, 3, 4, 5]:
			return "island"
		if maior == 17 and menor == 5:
			return "notch"
		return "island"
	var res: Vector2i = _resolucao()
	if RESOLUCOES.has(res):
		return str((RESOLUCOES[res] as Array)[1])
	var tela: Vector2i = DisplayServer.screen_get_size()
	var seg: Rect2i = DisplayServer.get_display_safe_area()
	var esc: float = maxf(1.0, DisplayServer.screen_get_scale())
	var inset: float = maxf(float(seg.position.x), float(tela.x - seg.end.x))
	inset = maxf(inset, float(seg.position.y)) / esc
	if inset < 8.0:
		return "home"
	return "notch" if inset <= 52.0 else "island"


func _coletar() -> void:
	_fps = Engine.get_frames_per_second()
	if _acum_dt > 0.0:
		_cpu = clampf(_acum_proc / _acum_dt * 100.0, 0.0, 100.0)
	_acum_proc = 0.0
	_acum_dt = 0.0
	var ms: float = RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid())
	var orcamento: float = 1000.0 / 60.0
	_gpu = clampf(ms / orcamento * 100.0, 0.0, 100.0) if ms > 0.0 else -1.0
	_ram_mb = float(OS.get_static_memory_usage()) / 1048576.0
	_ler_bateria()
	_ajustar_retangulo()


# O Godot 4 não tem API de bateria (OS.get_power_* era do Godot 3).
# Android: lê pelo BatteryManager, se o sistema permitir. iOS: sem plugin nativo não dá, fica "--".
func _ler_bateria() -> void:
	_bateria = -1
	_carregando = false
	if OS.get_name() != "Android" or not Engine.has_singleton("AndroidRuntime"):
		return
	var rt: Object = Engine.get_singleton("AndroidRuntime")
	var atividade: Variant = rt.call("getActivity")
	if atividade == null:
		return
	var gerente: Variant = atividade.call("getSystemService", "batterymanager")
	if gerente == null:
		return
	_bateria = int(gerente.call("getIntProperty", 4)) # BATTERY_PROPERTY_CAPACITY


func _txt_cpu() -> String:
	return "%d%%" % int(round(_cpu))

func _txt_gpu() -> String:
	return "%d%%" % int(round(_gpu)) if _gpu >= 0.0 else "--"

func _txt_ram() -> String:
	return "%d MB" % int(round(_ram_mb))

func _txt_bat() -> String:
	if _bateria < 0:
		return "--"
	return "%d%%%s" % [_bateria, "+" if _carregando else ""]


# ---------- Arrastar (toque ou mouse) ----------

func _limitar(p: Vector2) -> Vector2:
	var tela: Vector2 = get_viewport().get_visible_rect().size
	return Vector2(clampf(p.x, 0.0, maxf(0.0, tela.x - _painel.size.x)), clampf(p.y, 0.0, maxf(0.0, tela.y - _painel.size.y)))


func _on_gui(ev: InputEvent) -> void:
	var toque := ev as InputEventScreenTouch
	var mb := ev as InputEventMouseButton
	var arr := ev as InputEventScreenDrag
	var mm := ev as InputEventMouseMotion
	if toque != null or (mb != null and mb.button_index == MOUSE_BUTTON_LEFT):
		var pressionado: bool = toque.pressed if toque != null else mb.pressed
		_arrastando = pressionado
		if not pressionado:
			_config().definir_hud_pos(_painel.position)
		_painel.accept_event()
	elif _arrastando and (arr != null or mm != null):
		var rel: Vector2 = arr.relative if arr != null else mm.relative
		_painel.position = _limitar(_painel.position + rel)
		_painel.accept_event()


# ---------- Desenho ----------

func _caixa(raio: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = COR_FUNDO
	sb.border_color = COR_BORDA
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(raio)
	return sb


func _desenhar() -> void:
	var quadrado: bool = str(_config().hud_modo) == "quadrado"
	_painel.draw_style_box(_caixa(24 if quadrado else 20), Rect2(Vector2.ZERO, _painel.size))
	if quadrado:
		_desenhar_quadrado()
	else:
		_desenhar_retangulo()


func _texto(p: Vector2, s: String, tam: int, cor: Color, largura: float = -1.0) -> void:
	_painel.draw_string(ThemeDB.fallback_font, p, s, HORIZONTAL_ALIGNMENT_LEFT, largura, tam, cor)


# Modo retângulo: tudo na mesma linha (aparelho, GPU, FPS, CPU, GPU, RAM, bateria).
func _linha_retangulo() -> String:
	return "%s  |  %s  |  FPS %d  |  CPU %s  |  GPU %s  |  RAM %s  |  BAT %s" % [_aparelho, _gpu_nome, _fps, _txt_cpu(), _txt_gpu(), _txt_ram(), _txt_bat()]


func _tam_fonte_retangulo() -> int:
	var tela: float = get_viewport().get_visible_rect().size.x - 16.0
	for tam in [15, 13, 11, 9]:
		if _largura(_linha_retangulo(), int(tam)) + 36.0 <= tela:
			return int(tam)
	return 9


func _largura(t: String, tam: int) -> float:
	return ThemeDB.fallback_font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1.0, tam).x


# A largura do retângulo acompanha o texto (que cabe numa linha só).
func _ajustar_retangulo() -> void:
	if str(_config().hud_modo) != "retangulo":
		return
	_painel.size = Vector2(_largura(_linha_retangulo(), _tam_fonte_retangulo()) + 36.0, ALTURA_RETANGULO)
	_painel.position = _limitar(_painel.position)


func _desenhar_retangulo() -> void:
	var tam: int = _tam_fonte_retangulo()
	_texto(Vector2(18.0, ALTURA_RETANGULO * 0.5 + float(tam) * 0.36), _linha_retangulo(), tam, COR_TEXTO)


func _desenhar_quadrado() -> void:
	# Aparelho (moldura frontal) com o chip no centro.
	var alt: float = 96.0
	_telefone(Vector2(46.0, 16.0 + alt * 0.5), alt)
	_texto(Vector2(92.0, 30.0), _aparelho, 12, COR_TEXTO, 108.0)
	_texto(Vector2(92.0, 50.0), _gpu_nome, 10, COR_SUAVE, 108.0)
	var itens: Array = [["fps", "%d" % _fps], ["cpu", _txt_cpu()], ["gpu", _txt_gpu()], ["ram", _txt_ram()], ["bat", _txt_bat()]]
	for i in range(itens.size()):
		var col: int = i % 2
		var lin: int = i / 2
		var c := Vector2(24.0 + float(col) * 100.0, 140.0 + float(lin) * 24.0)
		_icone(str(itens[i][0]), c)
		_texto(Vector2(c.x + 14.0, c.y + 5.0), str(itens[i][1]), 13, COR_TEXTO, 80.0)


# Moldura frontal do aparelho: iPhone com botão home, com notch ou com Dynamic Island;
# Android com câmera frontal em furo. No centro, o símbolo do chip (quadrado).
func _telefone(c: Vector2, alt: float) -> void:
	var larg: float = alt * 0.5
	var r := Rect2(c.x - larg * 0.5, c.y - alt * 0.5, larg, alt)
	var corpo := StyleBoxFlat.new()
	corpo.bg_color = Color(0.1, 0.11, 0.17)
	corpo.border_color = Color(0.85, 0.86, 0.95)
	corpo.set_border_width_all(3)
	corpo.set_corner_radius_all(int(larg * 0.22))
	_painel.draw_style_box(corpo, r)
	var tipo: String = _iphone if _soc == "apple" else "android"
	var topo: float = r.position.y
	match tipo:
		"home":
			_painel.draw_rect(Rect2(c.x - larg * 0.18, topo + 7.0, larg * 0.36, 3.0), COR_SUAVE)
			_painel.draw_arc(Vector2(c.x, r.end.y - 8.0), 4.5, 0.0, TAU, 16, COR_SUAVE, 1.5)
		"notch":
			_painel.draw_rect(Rect2(c.x - larg * 0.22, topo + 2.0, larg * 0.44, 7.0), Color(0.85, 0.86, 0.95))
		"island":
			var pilula := StyleBoxFlat.new()
			pilula.bg_color = Color(0.85, 0.86, 0.95)
			pilula.set_corner_radius_all(4)
			_painel.draw_style_box(pilula, Rect2(c.x - larg * 0.17, topo + 6.0, larg * 0.34, 7.0))
		_:
			_painel.draw_circle(Vector2(c.x, topo + 9.0), 3.0, Color(0.85, 0.86, 0.95))
	var tam: float = larg * 0.62
	var tex: Texture2D = Sprites.textura(ICONES + _soc + ".png")
	var centro := Vector2(c.x, c.y + 4.0)
	if tex != null:
		_painel.draw_texture_rect(tex, Rect2(centro - Vector2(tam, tam) * 0.5, Vector2(tam, tam)), false)
	else:
		_painel.draw_rect(Rect2(centro - Vector2(tam, tam) * 0.5, Vector2(tam, tam)), COR_SUAVE, false, 2.0)


# Ícones pequenos (feitos em código).
func _icone(nome: String, c: Vector2) -> void:
	var cor := Color(1.0, 0.65, 0.3)
	match nome:
		"fps":
			_painel.draw_arc(c + Vector2(0.0, 3.0), 7.0, PI, TAU, 12, cor, 2.0)
			_painel.draw_line(c + Vector2(0.0, 3.0), c + Vector2(4.0, -2.0), cor, 2.0)
		"cpu":
			_painel.draw_rect(Rect2(c - Vector2(5.0, 5.0), Vector2(10.0, 10.0)), cor, false, 2.0)
			for k in [-3.0, 3.0]:
				_painel.draw_line(c + Vector2(k, -8.0), c + Vector2(k, -5.0), cor, 1.5)
				_painel.draw_line(c + Vector2(k, 5.0), c + Vector2(k, 8.0), cor, 1.5)
		"gpu":
			_painel.draw_rect(Rect2(c - Vector2(8.0, 5.0), Vector2(16.0, 10.0)), cor, false, 2.0)
			_painel.draw_circle(c, 3.0, cor)
		"ram":
			_painel.draw_rect(Rect2(c - Vector2(8.0, 4.0), Vector2(16.0, 8.0)), cor, false, 2.0)
			for k in [-4.0, 0.0, 4.0]:
				_painel.draw_rect(Rect2(c + Vector2(k - 1.0, -2.0), Vector2(2.0, 4.0)), cor)
		"bat":
			_painel.draw_rect(Rect2(c - Vector2(8.0, 4.0), Vector2(14.0, 8.0)), cor, false, 2.0)
			_painel.draw_rect(Rect2(c + Vector2(6.0, -2.0), Vector2(2.0, 4.0)), cor)
			var nivel: float = clampf(float(maxi(_bateria, 0)) / 100.0, 0.0, 1.0)
			_painel.draw_rect(Rect2(c - Vector2(6.0, 2.0), Vector2(10.0 * nivel, 4.0)), cor)
