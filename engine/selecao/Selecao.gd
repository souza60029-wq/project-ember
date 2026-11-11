extends Control

# Seleção de personagens (estilo KOF): grade de cards em hexágonos, arte grande de cada lado.
# Todo modo que leva a uma luta passa por aqui. Jogador 1 escolhe, depois o jogador 2.
# Artes (opcionais), em cada pasta de personagem (campos "arte_card" e "arte_selecao" do JSON):
#   card: o quadrado/hexágono da grade   selecao: arte grande que aparece ao passar o cursor
# Artes gerais, opcionais, em res://ui/selecao/: fundo.png, moldura_card.png, cursor_p1.png, cursor_p2.png
# Música: musica/selecao.ogg. Sons: sons/interface/selecao_mover e selecao_confirma.
# Autoloads são acessados por get_node, para o script compilar sem eles.

const Glifos = preload("res://engine/nucleo/Glifos.gd")
const Sprites = preload("res://engine/nucleo/Sprites.gd")

const PASTA_UI := "res://ui/selecao/"
const VIEW_W := 960.0
const VIEW_H := 540.0
# Cards em retângulos na vertical, agrupados de 3 em 3 (os trios do KOF).
const CARD_W := 50.0
const CARD_H := 92.0
const CARD_FOLGA := 4.0
const GRUPO_FOLGA := 18.0
const COLUNAS := 6
const TOPO_GRADE := 104.0
const PASSO_LINHA := 104.0
const LIMIAR_STICK := 0.6
const COR_P1 := Color(0.3, 1.0, 0.4)
const COR_P2 := Color(0.3, 0.6, 1.0)

var _itens: Array = []
var _cursor: int = 0
var _fase: int = 0 # 0 = jogador 1 escolhendo, 1 = jogador 2
var _escolha1: int = -1
var _cols: int = 6
var _eixo_estado: Dictionary = {}
var _saindo: bool = false
var _rect_ok := Rect2(380.0, 478.0, 200.0, 42.0)
var _rect_voltar := Rect2(20.0, 478.0, 130.0, 42.0)


func _config() -> Variant:
	return get_node("/root/Config")

func _navegacao() -> Variant:
	return get_node("/root/Navegacao")

func _t(chave: String) -> String:
	return str(get_node("/root/Textos").t(chave))

func _som(nome: String, reserva: String) -> void:
	get_node("/root/Audio").tocar_interface_ou(nome, reserva)


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_itens = get_node("/root/Catalogo").lista()
	var n: int = _itens.size()
	_cols = COLUNAS
	# Música sorteada de musica/selecao/ (várias); se a pasta estiver vazia, usa musica/selecao.
	get_node("/root/Audio").tocar_aleatoria("selecao", "selecao")


func _process(_d: float) -> void:
	queue_redraw()


# ---------- Geometria ----------

func _escala() -> float:
	var linhas: int = int(ceil(float(maxi(_itens.size(), 1)) / float(_cols)))
	return clampf(3.0 / float(linhas), 0.55, 1.0)


func _tam_card() -> Vector2:
	return Vector2(CARD_W, CARD_H) * _escala()


func _centro(i: int) -> Vector2:
	var e: float = _escala()
	var lg: float = 3.0 * CARD_W * e + 2.0 * CARD_FOLGA * e
	var total: float = 2.0 * lg + GRUPO_FOLGA
	var x0: float = (VIEW_W - total) * 0.5
	var col: int = i % _cols
	var linha: int = i / _cols
	var grupo: int = col / 3
	var dentro: int = col % 3
	var x: float = x0 + float(grupo) * (lg + GRUPO_FOLGA) + float(dentro) * (CARD_W + CARD_FOLGA) * e + CARD_W * e * 0.5
	var y: float = TOPO_GRADE + float(linha) * PASSO_LINHA * e + CARD_H * e * 0.5
	return Vector2(x, y)


func _rect_card(i: int) -> Rect2:
	var t: Vector2 = _tam_card()
	return Rect2(_centro(i) - t * 0.5, t)


# ---------- Desenho ----------

func _draw() -> void:
	var fundo: Texture2D = _ui("fundo")
	if fundo != null:
		draw_texture_rect(fundo, Rect2(0.0, 0.0, VIEW_W, VIEW_H), false)
	else:
		draw_rect(Rect2(0.0, 0.0, VIEW_W, VIEW_H), Color(0.16, 0.07, 0.05))
		draw_rect(Rect2(0.0, 0.0, VIEW_W, 70.0), Color(0.0, 0.0, 0.0, 0.35))
	_cabecalho()
	if _itens.is_empty():
		_texto_c(Rect2(0.0, 220.0, VIEW_W, 40.0), _t("sel_vazio"), 18, Color(1.0, 0.85, 0.5))
	else:
		_arte_lado(true)
		_arte_lado(false)
		_placas_trios()
		for i in range(_itens.size()):
			_desenhar_card(i)
		_desenhar_cursores()
		_nomes()
	_rodape()


func _cabecalho() -> void:
	var a1: Color = Color.WHITE if _fase == 0 else Color(1, 1, 1, 0.5)
	var a2: Color = Color.WHITE if _fase == 1 else Color(1, 1, 1, 0.5)
	draw_string(ThemeDB.fallback_font, Vector2(200.0, 48.0), _t("sel_player1"), HORIZONTAL_ALIGNMENT_RIGHT, 200.0, 26, a1.lerp(COR_P1, 0.5))
	draw_string(ThemeDB.fallback_font, Vector2(400.0, 48.0), "VS.", HORIZONTAL_ALIGNMENT_CENTER, 160.0, 26, Color.WHITE)
	draw_string(ThemeDB.fallback_font, Vector2(560.0, 48.0), _t("sel_player2"), HORIZONTAL_ALIGNMENT_LEFT, 220.0, 26, a2.lerp(COR_P2, 0.5))


# Placa atrás de cada trio (grupo de 3 cards).
func _placas_trios() -> void:
	var n: int = _itens.size()
	var i: int = 0
	while i < n:
		var ultimo: int = mini(i + 2, n - 1)
		while ultimo > i and (ultimo / _cols) != (i / _cols):
			ultimo -= 1
		var a: Rect2 = _rect_card(i)
		var b: Rect2 = _rect_card(ultimo)
		var placa: Rect2 = a.merge(b).grow(5.0)
		draw_rect(placa, Color(0.0, 0.0, 0.0, 0.35))
		draw_rect(placa, Color(1.0, 0.7, 0.3, 0.45), false, 1.5)
		i += 3


func _desenhar_card(i: int) -> void:
	var item: Dictionary = _itens[i]
	var per: Dictionary = item["personagem"]
	var r: Rect2 = _rect_card(i)
	var tex: Texture2D = _arte(item, str(per.get("arte_card", "")))
	if tex != null:
		# Preenche o retângulo vertical cortando as sobras (centralizado).
		var ts: Vector2 = tex.get_size()
		var alvo: float = r.size.x / r.size.y
		var src := Rect2(Vector2.ZERO, ts)
		if ts.x / ts.y > alvo:
			src.size.x = ts.y * alvo
			src.position.x = (ts.x - src.size.x) * 0.5
		else:
			src.size.y = ts.x / alvo
			src.position.y = (ts.y - src.size.y) * 0.5
		draw_texture_rect_region(tex, r, src)
	else:
		draw_rect(r, Color(0.12, 0.08, 0.1, 0.95))
		var nome: String = str(per["nome"]).left(2).to_upper()
		draw_string(ThemeDB.fallback_font, Vector2(r.position.x, r.get_center().y + 8.0), nome, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 22, Color(1, 1, 1, 0.85))
	var mold: Texture2D = _ui("moldura_card")
	if mold != null:
		draw_texture_rect(mold, r, false)
	else:
		draw_rect(r, Color(1, 1, 1, 0.55), false, 2.0)


func _desenhar_cursores() -> void:
	if _escolha1 >= 0:
		_cursor_em(_escolha1, COR_P1, "cursor_p1", false)
	var cor: Color = COR_P1 if _fase == 0 else COR_P2
	_cursor_em(_cursor, cor, "cursor_p1" if _fase == 0 else "cursor_p2", true)


func _cursor_em(i: int, cor: Color, nome_ui: String, ativo: bool) -> void:
	var r: Rect2 = _rect_card(i)
	var tex: Texture2D = _ui(nome_ui)
	if tex != null:
		draw_texture_rect(tex, r.grow(6.0), false)
		return
	var pulso: float = 0.75 + 0.25 * sin(Time.get_ticks_msec() / 120.0) if ativo else 1.0
	draw_rect(r.grow(3.0), Color(cor.r, cor.g, cor.b, pulso), false, 4.0)


func _arte_lado(esquerda: bool) -> void:
	var idx: int = -1
	if esquerda:
		idx = _escolha1 if _escolha1 >= 0 else (_cursor if _fase == 0 else -1)
	else:
		idx = _cursor if _fase == 1 else -1
	var area := Rect2(10.0, 80.0, 250.0, 390.0) if esquerda else Rect2(700.0, 80.0, 250.0, 390.0)
	if idx < 0:
		return
	var item: Dictionary = _itens[idx]
	var per: Dictionary = item["personagem"]
	var tex: Texture2D = _arte(item, str(per.get("arte_selecao", "")))
	if tex == null:
		return
	var tam: Vector2 = tex.get_size()
	var esc: float = minf(area.size.x / tam.x, area.size.y / tam.y)
	var w: Vector2 = tam * esc
	var x: float = area.position.x if esquerda else area.end.x - w.x
	draw_texture_rect(tex, Rect2(x, area.end.y - w.y, w.x, w.y), false)


func _nomes() -> void:
	var n1: String = ""
	var n2: String = ""
	if _escolha1 >= 0:
		n1 = str((_itens[_escolha1]["personagem"] as Dictionary)["nome"])
	elif _fase == 0:
		n1 = str((_itens[_cursor]["personagem"] as Dictionary)["nome"])
	if _fase == 1:
		n2 = str((_itens[_cursor]["personagem"] as Dictionary)["nome"])
	_barra_nome(Rect2(20.0, 440.0, 240.0, 26.0), n1, COR_P1)
	_barra_nome(Rect2(700.0, 440.0, 240.0, 26.0), n2, COR_P2)


func _barra_nome(r: Rect2, nome: String, cor: Color) -> void:
	draw_rect(r, Color(0.0, 0.0, 0.0, 0.6))
	draw_rect(Rect2(r.position, Vector2(6.0, r.size.y)), cor)
	_texto_c(r, nome, 16)


# Dicas: toque mostra botões; controle mostra os ícones dos botões.
func _rodape() -> void:
	if str(_config().modo_efetivo()) == "controle":
		var ps: bool = bool(_config().controle_ps())
		Glifos.desenhar(self, "DPAD", Vector2(300.0, 500.0), 12.0, ps)
		draw_string(ThemeDB.fallback_font, Vector2(320.0, 505.0), _t("dica_mover"), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, Color.WHITE)
		Glifos.desenhar(self, "A", Vector2(450.0, 500.0), 12.0, ps)
		draw_string(ThemeDB.fallback_font, Vector2(470.0, 505.0), _t("dica_confirmar"), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, Color.WHITE)
		Glifos.desenhar(self, "B", Vector2(600.0, 500.0), 12.0, ps)
		draw_string(ThemeDB.fallback_font, Vector2(620.0, 505.0), _t("dica_voltar"), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, Color.WHITE)
		return
	_botao(_rect_voltar, _t("voltar"))
	_botao(_rect_ok, _t("dica_confirmar"))


func _botao(r: Rect2, texto: String) -> void:
	draw_rect(r, Color(0.0, 0.0, 0.0, 0.6))
	draw_rect(r, Color(1, 1, 1, 0.7), false, 2.0)
	_texto_c(r, texto, 16)


func _texto_c(r: Rect2, s: String, tam: int = 14, cor: Color = Color.WHITE) -> void:
	draw_string(ThemeDB.fallback_font, Vector2(r.position.x, r.position.y + r.size.y * 0.5 + tam * 0.35), s, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, tam, cor)


func _ui(nome: String) -> Texture2D:
	return Sprites.textura(PASTA_UI + nome + ".png")


func _arte(item: Dictionary, rel: String) -> Texture2D:
	if rel == "":
		return null
	return Sprites.textura(str(item["pasta"]) + rel)


# ---------- Entrada ----------

func _unhandled_input(ev: InputEvent) -> void:
	var st := ev as InputEventScreenTouch
	if st != null and st.pressed:
		_tocar(st.position)
		get_viewport().set_input_as_handled()
		return
	var bt := ev as InputEventJoypadButton
	if bt != null and bt.pressed:
		_botao_controle(int(bt.button_index))
		get_viewport().set_input_as_handled()
		return
	var jm := ev as InputEventJoypadMotion
	if jm != null:
		_analogico(jm)
		get_viewport().set_input_as_handled()


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
		_botao_controle(JOY_BUTTON_DPAD_RIGHT if agora > 0 else JOY_BUTTON_DPAD_LEFT)
	else:
		_botao_controle(JOY_BUTTON_DPAD_DOWN if agora > 0 else JOY_BUTTON_DPAD_UP)


func _botao_controle(b: int) -> void:
	if b == JOY_BUTTON_B:
		_voltar()
		return
	if _itens.is_empty():
		return
	if b == JOY_BUTTON_DPAD_LEFT:
		_mover(-1)
	elif b == JOY_BUTTON_DPAD_RIGHT:
		_mover(1)
	elif b == JOY_BUTTON_DPAD_UP:
		_mover(-_cols)
	elif b == JOY_BUTTON_DPAD_DOWN:
		_mover(_cols)
	elif b == JOY_BUTTON_A:
		_confirmar()


func _mover(d: int) -> void:
	var n: int = _itens.size()
	var novo: int = _cursor + d
	if absi(d) == 1:
		novo = posmod(novo, n)
	elif novo < 0 or novo >= n:
		return
	_cursor = novo
	_som("selecao_mover", "menu_mover")


func _tocar(p: Vector2) -> void:
	if _rect_voltar.has_point(p):
		_voltar()
		return
	if _itens.is_empty():
		return
	if _rect_ok.has_point(p):
		_confirmar()
		return
	for i in range(_itens.size()):
		if _rect_card(i).has_point(p):
			if i == _cursor:
				_confirmar()
			else:
				_cursor = i
				_som("selecao_mover", "menu_mover")
			return


func _confirmar() -> void:
	if _saindo or _itens.is_empty():
		return
	_som("selecao_confirma", "menu_confirma")
	if _fase == 0:
		_escolha1 = _cursor
		_fase = 1
		return
	_saindo = true
	var nav: Variant = _navegacao()
	nav.selecao = {"p1": str(_itens[_escolha1]["id"]), "p2": str(_itens[_cursor]["id"])}
	nav.ir_para_luta()


func _voltar() -> void:
	if _saindo:
		return
	_som("menu_voltar", "menu_voltar")
	if _fase == 1:
		_fase = 0
		_cursor = maxi(_escolha1, 0)
		_escolha1 = -1
		return
	_saindo = true
	_navegacao().ir_para_menu()
