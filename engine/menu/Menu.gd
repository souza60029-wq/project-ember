extends Control

# Menu da engine. Tudo desenhado em código; arte é opcional.
# Abas lado a lado na linha de baixo. O submenu é uma lista vertical acima da aba
# selecionada, alinhada à borda esquerda dela. Não há terceiro nível.
# Fundo e música mudam por aba; submenus não mudam o fundo.
# Navegação: toque; controle (D-pad ou analógico esquerdo move, A confirma, B volta).
# Autoloads são acessados por get_node, para o script compilar sem eles.

const Glifos = preload("res://engine/nucleo/Glifos.gd")
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

# Carrossel de menus (centro inferior) e disco de música (canto superior direito).
const ICON_Y := 420.0
const ICON_TAM := 64.0
const ICON_ESPACO := 175.0
const DISCO_C := Vector2(922.0, 36.0)
const DISCO_R := 18.0
const BOLHA_W := 320.0
const BOLHA_TEMPO_AUTO := 4.0
const BOLHA_TEMPO_TOQUE := 7.0

# Cor lisa de cada aba, usada quando a imagem de fundo não existe.
const CORES := [
	Color(0.08, 0.16, 0.34),
	Color(0.22, 0.10, 0.30),
	Color(0.30, 0.16, 0.08),
	Color(0.10, 0.26, 0.16),
	Color(0.26, 0.22, 0.08)
]

# Textos de reserva para chaves que ainda não estão em Textos.gd.
const RESERVA := {
	"aba_treino": ["Treino", "Training"],
	"mp_coop": ["Coop", "Co-op"],
	"ctrl_nome": ["Controle", "Controller"],
	"ctrl_ultimo": ["Último botão", "Last button"]
}

# Estrutura do menu (esquerda/direita troca de menu; cima/baixo troca de submenu).
# "icone" é o nome do ícone desenhado em código; se existir ui/menu/icone_<nome>.png, ela é usada no lugar.
const ABAS := [
	{
		"chave": "menu_online", "icone": "online",
		"fundo": "fundo_online", "musica": "menu_online",
		"acao": "em_breve"
	},
	{
		"chave": "menu_local", "icone": "local",
		"fundo": "fundo_local", "musica": "menu_local",
		"filhos": [
			{"chave": "sub_arcade", "icone": "icone_arcade", "acao": "arcade"},
			{"chave": "sub_versus", "icone": "icone_versus", "acao": "versus"},
			{"chave": "sub_treino", "icone": "icone_treino", "acao": "treino"}
		]
	},
	{
		"chave": "menu_historia", "icone": "historia",
		"fundo": "fundo_historia", "musica": "menu_historia",
		"acao": "historia"
	},
	{
		"chave": "menu_editar", "icone": "editar",
		"fundo": "fundo_editar", "musica": "menu_editar",
		"filhos": [
			{"chave": "sub_criar_personagem", "icone": "icone_criar", "acao": "criar"},
			{"chave": "sub_editar_personagem", "icone": "icone_editar", "acao": "editar"}
		]
	},
	{
		"chave": "menu_colecionaveis", "icone": "colecionaveis",
		"fundo": "fundo_colecionaveis", "musica": "menu_colecionaveis",
		"acao": "em_breve"
	}
]

var aba: int = 1
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
var _pos: float = 1.0
var _tempo: float = 0.0
var _bolha_t: float = 0.0
var _bolha_toque: bool = false
var _bolha_w: float = 0.0
var _nome_faixa: String = ""

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
	_pos = float(aba)
	_nome_faixa = str(_audio().nome_faixa)
	_audio().faixa_mudou.connect(_on_faixa)
	_tocar_musica_da_aba()

func _process(delta: float) -> void:
	_tempo += delta
	_pos = lerpf(_pos, float(aba), 1.0 - exp(-12.0 * delta))
	if absf(_pos - float(aba)) < 0.002:
		_pos = float(aba)
	if _bolha_t > 0.0:
		_bolha_t -= delta
		if _bolha_t <= 0.0:
			_bolha_toque = false
	var alvo: float = BOLHA_W if _bolha_t > 0.0 else 0.0
	_bolha_w = lerpf(_bolha_w, alvo, 1.0 - exp(-14.0 * delta))
	if aviso_t > 0:
		aviso_t -= 1
		if aviso_t == 0:
			aviso = ""
	queue_redraw()

func _on_faixa(nome: String) -> void:
	_nome_faixa = nome
	if nome != "":
		_bolha_t = BOLHA_TEMPO_AUTO
		_bolha_toque = false

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
	else:
		_desenhar_faixa_escura()
		for e in _layout():
			_desenhar_entrada(e)
		_desenhar_carrossel()
		_desenhar_disco()
	if aviso_t > 0:
		draw_string(ThemeDB.fallback_font, Vector2(0.0, 250.0), aviso, HORIZONTAL_ALIGNMENT_CENTER, VIEW_W, 14, Color(1.0, 0.85, 0.5))

# Escurece a parte de baixo para os ícones e nomes aparecerem sobre qualquer arte.
func _desenhar_faixa_escura() -> void:
	var pontos := PackedVector2Array([Vector2(0.0, 330.0), Vector2(VIEW_W, 330.0), Vector2(VIEW_W, VIEW_H), Vector2(0.0, VIEW_H)])
	var cores := PackedColorArray([Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.75), Color(0, 0, 0, 0.75)])
	draw_polygon(pontos, cores)

# Ícone principal no centro (branco, maior). Os vizinhos ficam cinza e menores.
# A posição é animada: ao mudar de menu todos deslizam.
func _centro_icone(i: int) -> Vector2:
	return Vector2(VIEW_W * 0.5 + (float(i) - _pos) * ICON_ESPACO, ICON_Y)

func _desenhar_carrossel() -> void:
	var fonte: Font = ThemeDB.fallback_font
	for i in range(ABAS.size()):
		var item: Dictionary = ABAS[i]
		var ad: float = clampf(absf(float(i) - _pos), 0.0, 1.0)
		var c: Vector2 = _centro_icone(i)
		var tam: float = ICON_TAM * lerpf(1.2, 0.78, ad)
		var cor: Color = Color(1.0, 1.0, 1.0, 1.0).lerp(Color(0.55, 0.55, 0.62, 0.85), ad)
		_desenhar_icone(str(item["icone"]), c, tam, cor)
		draw_string(fonte, Vector2(c.x - 90.0, c.y + tam * 0.5 + 24.0), _t(str(item["chave"])), HORIZONTAL_ALIGNMENT_CENTER, 180.0, int(lerpf(19.0, 14.0, ad)), cor)

# Ícones feitos em código (linhas simples). Para usar sua arte, coloque ui/menu/icone_<nome>.png.
func _desenhar_icone(nome: String, c: Vector2, tam: float, cor: Color) -> void:
	var tex: Texture2D = _textura("icone_" + nome)
	if tex != null:
		draw_texture_rect(tex, Rect2(c - Vector2(tam, tam) * 0.5, Vector2(tam, tam)), false, cor)
		return
	var k: float = tam / 64.0
	var w: float = maxf(2.0, 3.0 * k)
	match nome:
		"online":
			draw_arc(c, 24.0 * k, 0.0, TAU, 32, cor, w)
			_elipse(c, 10.0 * k, 24.0 * k, cor, w)
			draw_line(c + Vector2(-24.0, 0.0) * k, c + Vector2(24.0, 0.0) * k, cor, w)
			draw_line(c + Vector2(-20.0, -12.0) * k, c + Vector2(20.0, -12.0) * k, cor, w)
			draw_line(c + Vector2(-20.0, 12.0) * k, c + Vector2(20.0, 12.0) * k, cor, w)
		"local":
			_espada(c, k, cor, w, Vector2(-22.0, 22.0), Vector2(22.0, -22.0))
			_espada(c, k, cor, w, Vector2(22.0, 22.0), Vector2(-22.0, -22.0))
		"historia":
			_poli(c, k, cor, w, [Vector2(-26, -16), Vector2(-2, -10), Vector2(-2, 20), Vector2(-26, 14)])
			_poli(c, k, cor, w, [Vector2(26, -16), Vector2(2, -10), Vector2(2, 20), Vector2(26, 14)])
			draw_line(c + Vector2(-20.0, -4.0) * k, c + Vector2(-8.0, -1.0) * k, cor, w * 0.7)
			draw_line(c + Vector2(20.0, -4.0) * k, c + Vector2(8.0, -1.0) * k, cor, w * 0.7)
		"editar":
			var d := Vector2(1.0, -1.0).normalized()
			var n := Vector2(1.0, 1.0).normalized() * 6.0 * k
			var p0: Vector2 = c + Vector2(-12.0, 12.0) * k
			var p1: Vector2 = c + Vector2(20.0, -20.0) * k
			var ponta: Vector2 = c + Vector2(-24.0, 24.0) * k
			var corpo := PackedVector2Array([p0 + n, p1 + n, p1 - n, p0 - n, p0 + n])
			draw_polyline(corpo, cor, w)
			draw_polyline(PackedVector2Array([p0 + n, ponta, p0 - n]), cor, w)
			draw_line(p0 + d * 4.0 * k + n, p0 + d * 4.0 * k - n, cor, w * 0.7)
		"colecionaveis":
			var pts := PackedVector2Array()
			for j in range(11):
				var raio: float = (26.0 if j % 2 == 0 else 11.0) * k
				var a: float = -PI * 0.5 + float(j) * PI / 5.0
				pts.append(c + Vector2(cos(a), sin(a)) * raio)
			draw_polyline(pts, cor, w)
		"config":
			draw_arc(c, 9.0 * k * 1.1, 0.0, TAU, 20, cor, w)
			for j in range(8):
				var a2: float = float(j) * TAU / 8.0
				draw_line(c + Vector2(cos(a2), sin(a2)) * 10.0 * k, c + Vector2(cos(a2), sin(a2)) * 14.0 * k, cor, w)
		_:
			draw_circle(c, 20.0 * k, cor)

func _elipse(c: Vector2, rx: float, ry: float, cor: Color, w: float) -> void:
	var pts := PackedVector2Array()
	for j in range(25):
		var a: float = float(j) * TAU / 24.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_polyline(pts, cor, w)

func _poli(c: Vector2, k: float, cor: Color, w: float, pts: Array) -> void:
	var r := PackedVector2Array()
	for p in pts:
		r.append(c + (p as Vector2) * k)
	r.append(r[0])
	draw_polyline(r, cor, w)

# Lâmina de p0 (cabo) até p1 (ponta), com guarda perto do cabo.
func _espada(c: Vector2, k: float, cor: Color, w: float, p0: Vector2, p1: Vector2) -> void:
	draw_line(c + p0 * k, c + p1 * k, cor, w)
	var d: Vector2 = (p1 - p0).normalized()
	var n := Vector2(-d.y, d.x)
	var g: Vector2 = p0 + d * 9.0
	draw_line(c + (g - n * 8.0) * k, c + (g + n * 8.0) * k, cor, w)

# Disco de música no canto superior direito. Abre uma bolha com o nome da faixa; ao toque, com botão de mutar.
func _desenhar_disco() -> void:
	var fonte: Font = ThemeDB.fallback_font
	var audio: Variant = _audio()
	var muda: bool = bool(audio.musica_muda)
	var cor := Color(1.0, 1.0, 1.0, 0.9) if not muda else Color(1.0, 0.5, 0.5, 0.9)
	if _bolha_w > 4.0:
		var r: Rect2 = _rect_bolha()
		draw_rect(r, Color(0.0, 0.0, 0.0, 0.7))
		draw_rect(r, Color(1.0, 1.0, 1.0, 0.4), false, 1.5)
		if _bolha_w > BOLHA_W * 0.6:
			var largura: float = r.size.x - (60.0 if _bolha_toque else 20.0)
			var nome: String = _nome_faixa if _nome_faixa != "" else "-"
			draw_string(fonte, Vector2(r.position.x + 12.0, r.position.y + 25.0), nome, HORIZONTAL_ALIGNMENT_LEFT, largura, 15, Color.WHITE)
			if _bolha_toque:
				_desenhar_mutar(_rect_mutar(), muda)
	draw_circle(DISCO_C, DISCO_R, Color(0.05, 0.05, 0.1, 0.85))
	draw_arc(DISCO_C, DISCO_R, 0.0, TAU, 28, cor, 2.5)
	draw_arc(DISCO_C, DISCO_R * 0.45, 0.0, TAU, 20, cor, 2.0)
	var giro: float = _tempo * 3.0 if (not muda and str(audio.nome_faixa) != "") else 0.0
	draw_arc(DISCO_C, DISCO_R * 0.75, giro, giro + 1.2, 8, cor, 2.0)
	if muda:
		draw_line(DISCO_C + Vector2(-12.0, 12.0), DISCO_C + Vector2(12.0, -12.0), Color(1.0, 0.4, 0.4), 3.0)
	if _modo_controle():
		Glifos.desenhar(self, "SELECT", DISCO_C + Vector2(0.0, 40.0), 9.0, bool(_config().controle_ps()))

func _rect_bolha() -> Rect2:
	return Rect2(DISCO_C.x - DISCO_R - 8.0 - _bolha_w, DISCO_C.y - 18.0, _bolha_w, 36.0)

func _rect_mutar() -> Rect2:
	var r: Rect2 = _rect_bolha()
	return Rect2(r.end.x - 42.0, r.position.y + 3.0, 36.0, 30.0)

func _desenhar_mutar(r: Rect2, muda: bool) -> void:
	draw_rect(r, Color(1.0, 1.0, 1.0, 0.12))
	draw_rect(r, Color(1.0, 1.0, 1.0, 0.6), false, 1.0)
	var c: Vector2 = r.get_center()
	draw_rect(Rect2(c.x - 9.0, c.y - 4.0, 5.0, 8.0), Color.WHITE)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-4.0, -4.0), c + Vector2(3.0, -9.0), c + Vector2(3.0, 9.0), c + Vector2(-4.0, 4.0)]), Color.WHITE)
	if muda:
		draw_line(c + Vector2(6.0, -6.0), c + Vector2(13.0, 6.0), Color(1.0, 0.4, 0.4), 2.0)
		draw_line(c + Vector2(13.0, -6.0), c + Vector2(6.0, 6.0), Color(1.0, 0.4, 0.4), 2.0)
	else:
		draw_arc(c + Vector2(3.0, 0.0), 8.0, -0.8, 0.8, 8, Color.WHITE, 2.0)

func _alternar_disco() -> void:
	if _bolha_t > 0.0 and _bolha_toque:
		var audio: Variant = _audio()
		audio.definir_mudo(not bool(audio.musica_muda))
		_bolha_t = BOLHA_TEMPO_TOQUE
	else:
		_bolha_toque = true
		_bolha_t = BOLHA_TEMPO_TOQUE

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

func _modo_controle() -> bool:
	return str(_config().modo_efetivo()) == "controle"

# Botão de configurações: pequeno, no canto. No modo controle mostra o ícone do START ao lado.
func _desenhar_botao_config(r: Rect2) -> void:
	draw_rect(r, Color(0.05, 0.05, 0.10, 0.55))
	draw_rect(r, Color(1.0, 1.0, 1.0, 0.25), false, 1.0)
	var tex: Texture2D = _textura("icone_config")
	if tex != null:
		draw_texture_rect(tex, r.grow(-4.0), false)
	else:
		var c: Vector2 = r.get_center()
		draw_arc(c, 9.0, 0.0, TAU, 20, Color(1, 1, 1, 0.9), 2.5)
		for i in range(8):
			var a: float = float(i) * TAU / 8.0
			draw_line(c + Vector2(cos(a), sin(a)) * 9.0, c + Vector2(cos(a), sin(a)) * 13.0, Color(1, 1, 1, 0.9), 3.0)
	if _modo_controle():
		Glifos.desenhar(self, "START", Vector2(r.end.x + 36.0, r.get_center().y), 11.0, bool(_config().controle_ps()))

# Dicas de botão do controle (só no modo controle). No toque, uma dica de texto.
func _desenhar_dicas() -> void:
	if not _modo_controle():
		_texto_c(Rect2(0.0, DICA_Y - 14.0, VIEW_W, 18.0), _t("dica_toque"), 13, Color(0.9, 0.9, 0.95, 0.8))
		return
	var ps: bool = bool(_config().controle_ps())
	var x: float = 250.0
	var y: float = DICA_Y - 8.0
	var itens: Array = [["LB", "dica_trocar"], ["DPAD", "dica_mover"], ["A", "dica_confirmar"], ["B", "dica_voltar"]]
	for it in itens:
		var par: Array = it
		Glifos.desenhar(self, str(par[0]), Vector2(x, y), 9.0, ps)
		if str(par[0]) == "LB":
			Glifos.desenhar(self, "RB", Vector2(x + 34.0, y), 9.0, ps)
			x += 34.0
		var rotulo: String = _t(str(par[1]))
		draw_string(ThemeDB.fallback_font, Vector2(x + 18.0, y + 5.0), rotulo, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, Color(0.9, 0.9, 0.95))
		x += 40.0 + rotulo.length() * 7.5

func _desenhar_entrada(e: Dictionary) -> void:
	var r: Rect2 = e["r"]
	var tipo: String = e["tipo"]
	var texto: String = str(e["label"])
	if tipo == "config_abrir":
		_desenhar_botao_config(r)
		return
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
	lista.append(_entrada(Rect2(MARGEM, 14.0, 44.0, 40.0), "config_abrir", 0, _t("cfg_titulo"), false))
	# Submenu: lista vertical acima do ícone selecionado. Cima/baixo troca o item.
	var filhos: Array = _filhos_aba()
	var n: int = filhos.size()
	if n > 0:
		var x: float = VIEW_W * 0.5 - SUB_W * 0.5
		var topo: float = ICON_Y - 64.0 - float(n) * SUB_H - float(n - 1) * SUB_GAP
		for j in range(n):
			var it: Dictionary = filhos[j]
			var r := Rect2(x, topo + float(j) * (SUB_H + SUB_GAP), SUB_W, SUB_H)
			var e2: Dictionary = _entrada(r, "sub", j, _t(str(it["chave"])), j == sub, it)
			e2["icone"] = str(it.get("icone", ""))
			lista.append(e2)


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
	if cat == 1:
		r.append({"chave": "cfg_debug", "ativo": bool(_config().debug_hitboxes)})
	elif cat == 2:
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
	if not config_aberto:
		if _tocar_disco(p):
			return
		var e0: Dictionary = _acertar(p)
		if e0.is_empty():
			for i in range(ABAS.size()):
				var c: Vector2 = _centro_icone(i)
				if Rect2(c - Vector2(ICON_ESPACO * 0.5, 50.0), Vector2(ICON_ESPACO, 120.0)).has_point(p):
					if i == aba:
						_confirmar()
					else:
						_selecionar_aba(i)
					return
			return
	var e: Dictionary = _acertar(p)
	if not e.is_empty():
		_acionar(e)

func _tocar_disco(p: Vector2) -> bool:
	if _bolha_toque and _bolha_w > BOLHA_W * 0.6 and _rect_mutar().has_point(p):
		_alternar_disco()
		return true
	if p.distance_to(DISCO_C) <= DISCO_R + 8.0:
		if _bolha_t > 0.0 and _bolha_toque:
			_bolha_t = 0.0
			_bolha_toque = false
		else:
			_bolha_toque = true
			_bolha_t = BOLHA_TEMPO_TOQUE
		return true
	return false

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
		"sub":
			sub = i
			_executar(item)

func _botao(b: int) -> void:
	if b == JOY_BUTTON_START:
		if config_aberto:
			_voltar_config_tudo()
		else:
			_abrir_config()
		return
	if config_aberto:
		_botao_config(b)
		return
	if b == JOY_BUTTON_BACK:
		_alternar_disco()
		return
	if b == JOY_BUTTON_DPAD_LEFT or b == JOY_BUTTON_LEFT_SHOULDER:
		_selecionar_aba(aba - 1)
	elif b == JOY_BUTTON_DPAD_RIGHT or b == JOY_BUTTON_RIGHT_SHOULDER:
		_selecionar_aba(aba + 1)
	elif b == JOY_BUTTON_DPAD_UP:
		_mover_sub(-1)
	elif b == JOY_BUTTON_DPAD_DOWN:
		_mover_sub(1)
	elif b == JOY_BUTTON_A:
		_confirmar()

func _botao_config(b: int) -> void:
	if b == JOY_BUTTON_DPAD_UP:
		_mover_foco_cfg(-1)
	elif b == JOY_BUTTON_DPAD_DOWN:
		_mover_foco_cfg(1)
	elif b == JOY_BUTTON_A:
		_acionar_foco_cfg()
	elif b == JOY_BUTTON_B:
		_voltar_config()

func _mover_sub(d: int) -> void:
	var n: int = _filhos_aba().size()
	if n > 0:
		var novo: int = clampi(sub + d, 0, n - 1)
		if novo != sub:
			sub = novo
			_som("menu_mover")

func _selecionar_aba(i: int) -> void:
	i = clampi(i, 0, ABAS.size() - 1)
	if i != aba:
		aba = i
		sub = 0
		_som("menu_mover")
		_tocar_musica_da_aba()

func _confirmar() -> void:
	var item: Dictionary = ABAS[aba]
	if item.has("filhos"):
		var f: Array = _filhos_aba()
		if not f.is_empty():
			_executar(f[sub])
	else:
		_executar(item)

func _abrir_config() -> void:
	config_aberto = true
	config_nivel = 0
	cfg_foco = 0
	_som("menu_confirma")
	_tocar_musica("menu_configuracoes")

func _voltar_config_tudo() -> void:
	config_nivel = 0
	_voltar_config()


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
	if config_cat == 1 and j == 0:
		_config().definir_debug(not bool(_config().debug_hitboxes))
	elif config_cat == 2 and j < MODOS.size():
		_config().definir_modo(MODOS[j])
	elif config_cat == 3 and j < IDIOMAS.size():
		_config().definir_idioma(IDIOMAS[j])
	_som("menu_confirma")

# ---------- Ações ----------

func _executar(item: Dictionary) -> void:
	var acao: String = str(item.get("acao", ""))
	match acao:
		"treino", "arcade", "versus", "classico", "historia", "coop":
			# Todo modo que leva a uma luta passa antes pela seleção de personagens.
			_som("menu_confirma")
			_navegacao().ir_para_selecao(acao)
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