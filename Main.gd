extends Node2D

const Personagem = preload("res://Personagem.gd")
const Caixa = preload("res://Caixa.gd")

const DT: float = 1.0 / 60.0

# Controles na tela (viewport 960x540)
const DPAD_CENTRO: Vector2 = Vector2(120, 430)
const DPAD_RAIO: float = 80.0
const RAIO_BOTAO: float = 36.0
const BOTOES = {
	"HP": Vector2(720, 330),
	"CD": Vector2(840, 330),
	"LP": Vector2(660, 410),
	"HK": Vector2(780, 410),
	"LK": Vector2(720, 490),
	"ROLL": Vector2(860, 470),
}
const BOTAO_EDITOR: Rect2 = Rect2(400, 8, 160, 34)

# Editor de golpes
const LINHAS_ESQ = ["botao", "carga", "carga_seg", "forca", "startup", "active", "recovery", "dano"]
const LINHAS_DIR = ["custo", "energia_ganha", "antichao", "blowoff", "so_ar", "hit_x", "hit_y", "hit_w", "hit_h"]
const ROTULOS = {
	"botao": "Botao", "carga": "Carga", "carga_seg": "Tempo carga (s)", "forca": "Forca (0-3)",
	"startup": "Startup", "active": "Active", "recovery": "Recovery", "dano": "Dano",
	"custo": "Custo barra", "energia_ganha": "Barra ganha", "antichao": "Anti-chao",
	"blowoff": "Blow Off", "so_ar": "So no ar",
	"hit_x": "Hitbox X", "hit_y": "Hitbox Y", "hit_w": "Hitbox W", "hit_h": "Hitbox H",
}
const CICLOS = {"botao": ["LP", "LK", "HP", "HK", "CD"], "carga": ["nenhuma", "tras", "baixo"]}
const BOOLEANOS = ["antichao", "blowoff", "so_ar"]
const INTEIROS = ["forca", "startup", "active", "recovery"]
const NUMEROS = {
	"carga_seg": [0.1, 0.1, 2.0],
	"forca": [1, 0, 3],
	"startup": [1, 1, 60],
	"active": [1, 1, 60],
	"recovery": [1, 1, 80],
	"dano": [0.5, 0.0, 100.0],
	"custo": [10, 0, 300],
	"energia_ganha": [5, 0, 100],
	"hit_x": [5, -200, 200],
	"hit_y": [5, -200, 50],
	"hit_w": [5, 5, 200],
	"hit_h": [5, 5, 200],
}

var p1: Personagem
var p2: Personagem
var modo_editor: bool = false
var editor_idx: int = 0
var mensagem: String = ""
var ko_timer: float = 0.0
var toques: Dictionary = {}
var anteriores: Dictionary = {0: {}, 1: {}}

func _ready() -> void:
	p1 = Personagem.new("Ash Crimson", Vector2(250, 480), true)
	p2 = Personagem.new("Dummy", Vector2(710, 480), false)

# ---------- Loop de luta (fixo em 60 frames por segundo) ----------

func _physics_process(_delta: float) -> void:
	if modo_editor:
		queue_redraw()
		return
	if ko_timer > 0.0:
		ko_timer -= DT
		if ko_timer <= 0.0:
			_reiniciar_round()
		queue_redraw()
		return

	var e1: Dictionary = _entrada(0, true)
	var e2: Dictionary = _entrada(1, false)

	p1.virado_direita = p1.pos.x <= p2.pos.x
	p2.virado_direita = p2.pos.x < p1.pos.x

	p1.atualizar(e1.dir, e1.apertados)
	p2.atualizar(e2.dir, e2.apertados)

	_separar_lutadores()
	_checar_hit(p1, p2)
	_checar_hit(p2, p1)

	if p1.vida.valor <= 0.0 or p2.vida.valor <= 0.0:
		ko_timer = 2.0
	queue_redraw()

func _reiniciar_round() -> void:
	p1.resetar(Vector2(250, 480), true)
	p2.resetar(Vector2(710, 480), false)
	ko_timer = 0.0

func _separar_lutadores() -> void:
	var d: float = p2.pos.x - p1.pos.x
	var minimo: float = 44.0
	if abs(d) < minimo:
		var empurrao: float = (minimo - abs(d)) / 2.0
		var sinal: float = 1.0 if d >= 0.0 else -1.0
		p1.pos.x -= sinal * empurrao
		p2.pos.x += sinal * empurrao
	p1.pos.x = clamp(p1.pos.x, 30.0, 930.0)
	p2.pos.x = clamp(p2.pos.x, 30.0, 930.0)

func _checar_hit(atk: Personagem, dfn: Personagem) -> void:
	if atk.hitboxes.is_empty():
		return
	var g: Dictionary = atk.golpe_atual
	for hit in atk.hitboxes:
		for hurt in dfn.hurtboxes:
			if Caixa.colidem(hit, atk.pos, atk.virado_direita, hurt, dfn.pos, dfn.virado_direita):
				if dfn.pode_ser_atingido_por(g):
					dfn.receber_golpe(g)
					atk.marcar_acerto(g)
				return

# ---------- Entrada: toque + gamepad, com borda de aperto ----------

func _entrada(joy: int, usa_toque: bool) -> Dictionary:
	var dir := Vector2.ZERO
	if usa_toque:
		dir = _dir_toque()
	if dir == Vector2.ZERO:
		var analogico := Vector2(Input.get_joy_axis(joy, JOY_AXIS_LEFT_X), Input.get_joy_axis(joy, JOY_AXIS_LEFT_Y))
		if analogico.length() > 0.25:
			dir = analogico

	var seg := {
		"LP": Input.is_joy_button_pressed(joy, JOY_BUTTON_X),
		"LK": Input.is_joy_button_pressed(joy, JOY_BUTTON_A),
		"HP": Input.is_joy_button_pressed(joy, JOY_BUTTON_Y),
		"HK": Input.is_joy_button_pressed(joy, JOY_BUTTON_B),
		"CD": Input.is_joy_button_pressed(joy, JOY_BUTTON_RIGHT_SHOULDER),
		"ROLL": Input.is_joy_button_pressed(joy, JOY_BUTTON_LEFT_SHOULDER),
	}
	if usa_toque:
		for b in BOTOES.keys():
			seg[b] = seg[b] or _toque_em(b)

	var ant: Dictionary = anteriores[joy]
	var ap := {}
	for k in seg.keys():
		ap[k] = seg[k] and not ant.get(k, false)
	anteriores[joy] = seg

	# Atalhos: LP+LK = esquiva, HP+HK = Guard Cancel / Blow Off
	if seg.LP and seg.LK and (ap.LP or ap.LK):
		ap["ROLL"] = true
	if seg.HP and seg.HK and (ap.HP or ap.HK):
		ap["CD"] = true

	return {"dir": dir, "apertados": ap}

func _dir_toque() -> Vector2:
	for ponto in toques.values():
		if ponto.x < 330.0:
			var d: Vector2 = ponto - DPAD_CENTRO
			if d.length() > 12.0:
				return (d / DPAD_RAIO).limit_length(1.0)
	return Vector2.ZERO

func _toque_em(nome_botao: String) -> bool:
	var c: Vector2 = BOTOES[nome_botao]
	for ponto in toques.values():
		if ponto.distance_to(c) <= RAIO_BOTAO + 6.0:
			return true
	return false

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t: InputEventScreenTouch = event
		if t.pressed:
			toques[t.index] = t.position
			_ao_tocar(t.position)
		else:
			toques.erase(t.index)
	elif event is InputEventScreenDrag:
		var d: InputEventScreenDrag = event
		toques[d.index] = d.position

func _ao_tocar(ponto: Vector2) -> void:
	if BOTAO_EDITOR.has_point(ponto):
		modo_editor = not modo_editor
		return
	if modo_editor:
		_clique_editor(ponto)

# ---------- Editor de golpes (toque) ----------

func _em(ponto: Vector2, x: float, y: float, w: float, h: float) -> bool:
	return Rect2(x, y, w, h).has_point(ponto)

func _clique_editor(ponto: Vector2) -> void:
	var g: Dictionary = p1.golpes[editor_idx]
	# Cabecalho
	if _em(ponto, 40, 52, 90, 36):
		_trocar_idx(-1)
		return
	if _em(ponto, 140, 52, 90, 36):
		_trocar_idx(1)
		return
	if _em(ponto, 240, 52, 90, 36):
		_novo_golpe()
		return
	if _em(ponto, 340, 52, 90, 36):
		_copiar_golpe()
		return
	if _em(ponto, 440, 52, 90, 36):
		_apagar_golpe()
		return
	if _em(ponto, 540, 52, 90, 36):
		_mover_golpe(-1)
		return
	if _em(ponto, 640, 52, 90, 36):
		_mover_golpe(1)
		return
	# Nome
	if _em(ponto, 40, 96, 880, 28):
		_colar_nome(g)
		return
	# Rodape
	if _em(ponto, 40, 458, 280, 40):
		_exportar()
		return
	if _em(ponto, 340, 458, 280, 40):
		_importar()
		return
	if _em(ponto, 640, 458, 280, 40):
		modo_editor = false
		return
	# Campos
	for i in LINHAS_ESQ.size():
		_clicar_campo(g, LINHAS_ESQ[i], 40.0, 136.0 + i * 34.0, ponto)
	for i in LINHAS_DIR.size():
		_clicar_campo(g, LINHAS_DIR[i], 500.0, 136.0 + i * 34.0, ponto)

func _clicar_campo(g: Dictionary, chave: String, cx: float, y: float, ponto: Vector2) -> void:
	var linha := Rect2(cx, y, 410, 30)
	if CICLOS.has(chave):
		if linha.has_point(ponto):
			_ciclar(g, chave)
	elif BOOLEANOS.has(chave):
		if linha.has_point(ponto):
			_gravar_campo(g, chave, not _ler_campo(g, chave))
	elif NUMEROS.has(chave):
		if Rect2(cx + 320.0, y + 2.0, 42, 26).has_point(ponto):
			_ajustar(g, chave, -1)
		elif Rect2(cx + 370.0, y + 2.0, 42, 26).has_point(ponto):
			_ajustar(g, chave, 1)

func _ler_campo(g: Dictionary, chave: String):
	if chave.begins_with("hit_"):
		return g.hitbox[chave.substr(4)]
	return g[chave]

func _gravar_campo(g: Dictionary, chave: String, valor) -> void:
	if chave.begins_with("hit_"):
		g.hitbox[chave.substr(4)] = valor
	else:
		g[chave] = valor

func _ciclar(g: Dictionary, chave: String) -> void:
	var lista: Array = CICLOS[chave]
	var i := lista.find(g[chave])
	_gravar_campo(g, chave, lista[(i + 1) % lista.size()])

func _ajustar(g: Dictionary, chave: String, sinal: int) -> void:
	var regra: Array = NUMEROS[chave]
	var valor = clamp(float(_ler_campo(g, chave)) + float(regra[0]) * sinal, float(regra[1]), float(regra[2]))
	if INTEIROS.has(chave):
		valor = int(round(valor))
	else:
		valor = snappedf(valor, 0.01)
	_gravar_campo(g, chave, valor)

func _trocar_idx(d: int) -> void:
	editor_idx = clampi(editor_idx + d, 0, p1.golpes.size() - 1)

func _novo_golpe() -> void:
	var g := Personagem.golpe_padrao()
	g["nome"] = "Golpe " + str(p1.golpes.size() + 1)
	p1.golpes.append(g)
	editor_idx = p1.golpes.size() - 1

func _copiar_golpe() -> void:
	var c: Dictionary = p1.golpes[editor_idx].duplicate(true)
	c["nome"] = str(c["nome"]) + " (copia)"
	p1.golpes.insert(editor_idx + 1, c)
	editor_idx += 1

func _apagar_golpe() -> void:
	if p1.golpes.size() <= 1:
		mensagem = "Precisa existir pelo menos 1 golpe"
		return
	p1.golpes.remove_at(editor_idx)
	editor_idx = clampi(editor_idx, 0, p1.golpes.size() - 1)

func _mover_golpe(d: int) -> void:
	var j := editor_idx + d
	if j < 0 or j >= p1.golpes.size():
		return
	var tmp = p1.golpes[editor_idx]
	p1.golpes[editor_idx] = p1.golpes[j]
	p1.golpes[j] = tmp
	editor_idx = j

func _colar_nome(g: Dictionary) -> void:
	var t := DisplayServer.clipboard_get().strip_edges()
	if t != "":
		g["nome"] = t
	else:
		mensagem = "Area de transferencia vazia"

func _exportar() -> void:
	var txt := JSON.stringify({"nome": p1.nome, "golpes": p1.golpes}, "  ")
	DisplayServer.clipboard_set(txt)
	mensagem = "Personagem copiado (%d golpes). Cole em algum lugar para guardar." % p1.golpes.size()

func _importar() -> void:
	var dados = JSON.parse_string(DisplayServer.clipboard_get())
	var lista = null
	if typeof(dados) == TYPE_DICTIONARY and dados.has("golpes"):
		lista = dados["golpes"]
		if dados.has("nome"):
			p1.nome = str(dados["nome"])
	elif typeof(dados) == TYPE_ARRAY:
		lista = dados
	if typeof(lista) != TYPE_ARRAY or lista.is_empty():
		mensagem = "Nada valido na area de transferencia"
		return
	var novos: Array = []
	for g in lista:
		if typeof(g) == TYPE_DICTIONARY:
			novos.append(Personagem.normalizar_golpe(g))
	if novos.is_empty():
		mensagem = "Nenhum golpe valido encontrado"
		return
	p1.golpes = novos
	editor_idx = 0
	mensagem = "Personagem importado: %d golpes" % novos.size()

# ---------- Desenho ----------

func _draw() -> void:
	draw_rect(Rect2(-300, -300, 1600, 1200), Color(0.1, 0.1, 0.13))
	draw_rect(Rect2(-300, 480, 1600, 300), Color(0.2, 0.2, 0.23))
	if p1 == null or p2 == null:
		return

	_desenhar_hud()
	_desenhar_lutador(p1, Color(0.95, 0.5, 0.1))
	_desenhar_lutador(p2, Color(0.1, 0.5, 0.95))

	if modo_editor:
		_desenhar_editor()
	else:
		_desenhar_controles()

	draw_rect(BOTAO_EDITOR, Color(0.6, 0.2, 0.2))
	_texto_centro(BOTAO_EDITOR.get_center(), "EDITOR", 16)

	if ko_timer > 0.0:
		_texto(Vector2(380, 280), "K.O.", 56)

func _desenhar_hud() -> void:
	_texto(Vector2(40, 22), p1.nome, 16)
	_texto(Vector2(640, 22), p2.nome, 16)
	_barra(Rect2(40, 28, 360, 20), p1.vida.proporcao(), Color(0.2, 0.85, 0.2), false, 1)
	_barra(Rect2(560, 28, 360, 20), p2.vida.proporcao(), Color(0.2, 0.85, 0.2), true, 1)
	_barra(Rect2(40, 52, 280, 12), p1.energia.proporcao(), Color(0.2, 0.5, 1.0), false, 3)
	_barra(Rect2(640, 52, 280, 12), p2.energia.proporcao(), Color(0.2, 0.5, 1.0), true, 3)
	_texto(Vector2(40, 84), p1.nome_estado(), 14)
	_texto(Vector2(640, 84), p2.nome_estado(), 14)

func _barra(r: Rect2, prop: float, cor: Color, direita: bool, segmentos: int) -> void:
	draw_rect(r, Color(0.25, 0.1, 0.1))
	var w: float = r.size.x * clampf(prop, 0.0, 1.0)
	var x: float = r.position.x
	if direita:
		x = r.position.x + r.size.x - w
	draw_rect(Rect2(x, r.position.y, w, r.size.y), cor)
	for i in range(1, segmentos):
		var sx: float = r.position.x + r.size.x * i / segmentos
		draw_line(Vector2(sx, r.position.y), Vector2(sx, r.position.y + r.size.y), Color.BLACK, 2.0)

func _desenhar_lutador(l: Personagem, cor: Color) -> void:
	var c: Color = cor
	if l.invulneravel:
		c.a = 0.45
	draw_rect(Rect2(l.pos.x - 25, l.pos.y - 100, 50, 100), c)
	for h in l.hurtboxes:
		draw_rect(h.obter_rect(l.pos.x, l.pos.y, l.virado_direita), Color(0, 1, 0, 0.35), false, 2.0)
	for h in l.hitboxes:
		draw_rect(h.obter_rect(l.pos.x, l.pos.y, l.virado_direita), Color(1, 0, 0, 0.5))
	var frente: float = 1.0 if l.virado_direita else -1.0
	draw_circle(l.pos + Vector2(frente * 18.0, -88.0), 4.0, Color.WHITE)

func _desenhar_controles() -> void:
	draw_circle(DPAD_CENTRO, DPAD_RAIO, Color(1, 1, 1, 0.12))
	var alvo: Vector2 = _dir_toque()
	draw_circle(DPAD_CENTRO + alvo * DPAD_RAIO * 0.6, 26.0, Color(1, 1, 1, 0.35))
	for nome_botao in BOTOES.keys():
		var c: Vector2 = BOTOES[nome_botao]
		var ativo: bool = _toque_em(nome_botao)
		draw_circle(c, RAIO_BOTAO, Color(1, 1, 1, 0.45 if ativo else 0.18))
		var rotulo: String = "ROL" if nome_botao == "ROLL" else nome_botao
		_texto_centro(c, rotulo, 14)

func _desenhar_editor() -> void:
	draw_rect(Rect2(20, 20, 920, 500), Color(0.05, 0.05, 0.08, 0.97))
	_texto(Vector2(40, 42), "EDITOR DE GOLPES: " + p1.nome, 16)

	_botao_ui(Rect2(40, 52, 90, 36), "< ANT")
	_botao_ui(Rect2(140, 52, 90, 36), "PROX >")
	_botao_ui(Rect2(240, 52, 90, 36), "NOVO")
	_botao_ui(Rect2(340, 52, 90, 36), "COPIA")
	_botao_ui(Rect2(440, 52, 90, 36), "APAGA", Color(0.6, 0.15, 0.15))
	_botao_ui(Rect2(540, 52, 90, 36), "SOBE")
	_botao_ui(Rect2(640, 52, 90, 36), "DESCE")

	var g: Dictionary = p1.golpes[editor_idx]
	_texto(Vector2(750, 76), "%d/%d" % [editor_idx + 1, p1.golpes.size()], 16)

	draw_rect(Rect2(40, 96, 880, 28), Color(0.15, 0.15, 0.2))
	_texto(Vector2(50, 116), "Nome: " + str(g["nome"]) + "   (toque aqui para colar o nome da area de transferencia)", 14)

	for i in LINHAS_ESQ.size():
		_desenhar_campo(g, LINHAS_ESQ[i], 40.0, 136.0 + i * 34.0)
	for i in LINHAS_DIR.size():
		_desenhar_campo(g, LINHAS_DIR[i], 500.0, 136.0 + i * 34.0)

	_botao_ui(Rect2(40, 458, 280, 40), "EXPORTAR PERSONAGEM")
	_botao_ui(Rect2(340, 458, 280, 40), "IMPORTAR PERSONAGEM")
	_botao_ui(Rect2(640, 458, 280, 40), "FECHAR", Color(0.2, 0.5, 0.2))
	_texto(Vector2(40, 518), mensagem, 14, Color(1, 0.9, 0.4))

func _desenhar_campo(g: Dictionary, chave: String, cx: float, y: float) -> void:
	draw_rect(Rect2(cx, y, 410, 30), Color(0.12, 0.12, 0.17))
	_texto(Vector2(cx + 10, y + 21), str(ROTULOS[chave]), 14)
	var v = _ler_campo(g, chave)
	if NUMEROS.has(chave):
		_texto(Vector2(cx + 230, y + 21), str(v), 16, Color(1, 1, 0.6))
		_botao_ui(Rect2(cx + 320, y + 2, 42, 26), "-")
		_botao_ui(Rect2(cx + 370, y + 2, 42, 26), "+")
	else:
		var txt: String = str(v)
		if typeof(v) == TYPE_BOOL:
			txt = "SIM" if v else "NAO"
		_texto(Vector2(cx + 230, y + 21), txt, 16, Color(1, 1, 0.6))

func _botao_ui(r: Rect2, txt: String, cor: Color = Color(0.2, 0.3, 0.5)) -> void:
	draw_rect(r, cor)
	_texto_centro(r.get_center(), txt, 14)

func _texto(pos: Vector2, txt: String, tamanho: int = 16, cor: Color = Color.WHITE) -> void:
	draw_string(ThemeDB.fallback_font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho, cor)

func _texto_centro(centro: Vector2, txt: String, tamanho: int) -> void:
	var larg: float = ThemeDB.fallback_font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho).x
	_texto(centro + Vector2(-larg / 2.0, tamanho / 3.0), txt, tamanho)