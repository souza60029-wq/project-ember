extends Node2D

# Tela de luta: liga o núcleo (Personagem) à tela, ao toque e ao controle.
# Não guarda dados de personagem: lê o JSON pelo Formato.
# Nesta versão, o botão EDITOR saiu da luta. O editor volta na próxima entrega.

const Caixa = preload("res://engine/nucleo/Caixa.gd")
const Personagem = preload("res://engine/nucleo/Personagem.gd")
const Formato = preload("res://engine/formato/Formato.gd")

const PERSONAGEM_INICIAL := "res://personagens/ash_crimson/personagem.json"
const VIEW_W := 960.0
const VIEW_H := 540.0
const FRAMES_KO := 150
const TECLAS := ["LP", "LK", "HP", "HK", "CD", "ROLL"]

const DPAD_C := Vector2(120.0, 430.0)
const DPAD_R := 80.0
const BOTAO_R := 36.0
const BOTOES := {
	"HP": Vector2(720.0, 330.0),
	"CD": Vector2(840.0, 330.0),
	"LP": Vector2(660.0, 410.0),
	"HK": Vector2(780.0, 410.0),
	"LK": Vector2(720.0, 490.0),
	"ROLL": Vector2(860.0, 470.0),
}

const RECT_RESET := Rect2(260.0, 8.0, 120.0, 34.0)

const COR_P1 := Color(0.9, 0.15, 0.15)
const COR_P1_FUNDO := Color(0.3, 0.05, 0.05)
const COR_P2 := Color(0.2, 0.5, 1.0)
const COR_P2_FUNDO := Color(0.05, 0.12, 0.3)
const COR_DANO := Color(1.0, 0.9, 0.2)

# Altura da faixa de dano em relação à barra de vida (0.35 = 35%).
const FRACAO_FAIXA_DANO := 0.35

var p1 = Personagem.new()
var p2 = Personagem.new()
var nome_p1: String = "Sem personagem"
var aviso: String = ""
var toques := {}
var mask1 := {}
var mask2 := {}
var ko_t := 0

# ---------- Ciclo de vida ----------

func _init() -> void:
	p1.oponente = p2
	p2.oponente = p1
	_carregar_personagem()

func _ready() -> void:
	_reiniciar_luta()

func _process(_delta: float) -> void:
	queue_redraw()

func _physics_process(_delta: float) -> void:
	_passo_jogador(p1, (_dir_pad(0) + _vec_dpad()).limit_length(1.0), _entrada_p1(), mask1)
	_passo_jogador(p2, _dir_pad(1), _entrada_pad(1), mask2)
	_resolver_combate(p1, p2)
	_resolver_combate(p2, p1)
	_separar_corpos()
	_expirar_combos()
	if p1.estado == Personagem.Estado.KO or p2.estado == Personagem.Estado.KO:
		ko_t += 1
		if ko_t > FRAMES_KO:
			_reiniciar_luta()
	else:
		ko_t = 0

# ---------- Carregamento ----------

func _carregar_personagem() -> void:
	var r: Dictionary = Formato.ler(PERSONAGEM_INICIAL)
	if r["ok"]:
		var per: Dictionary = r["personagem"]
		nome_p1 = str(per["nome"])
		p1.definir_golpes(per["golpes"])
		p2.definir_golpes(per["golpes"])
		aviso = ""
	else:
		nome_p1 = "Sem personagem"
		p1.definir_golpes([Formato.padrao_golpe()])
		p2.definir_golpes([Formato.padrao_golpe()])
		aviso = "Personagem não carregado: " + str(r["erro"])

# ---------- Entrada ----------

func _unhandled_input(ev: InputEvent) -> void:
	var st := ev as InputEventScreenTouch
	var sd := ev as InputEventScreenDrag
	if st != null:
		if st.pressed:
			var alvo := _alvo_toque(st.position)
			toques[st.index] = {"alvo": alvo, "pos": st.position}
			if alvo == "RESET":
				_reiniciar_luta()
		else:
			toques.erase(st.index)
	elif sd != null:
		if toques.has(sd.index):
			toques[sd.index]["pos"] = sd.position

func _alvo_toque(p: Vector2) -> String:
	if RECT_RESET.has_point(p):
		return "RESET"
	if p.distance_to(DPAD_C) <= DPAD_R * 1.2:
		return "DPAD"
	var melhor := ""
	var menor: float = BOTAO_R * 1.25
	for k in BOTOES:
		var d: float = p.distance_to(BOTOES[k])
		if d < menor:
			menor = d
			melhor = str(k)
	return melhor

func _vec_dpad() -> Vector2:
	for idx in toques:
		if str(toques[idx]["alvo"]) == "DPAD":
			var pos_t: Vector2 = toques[idx]["pos"]
			var v: Vector2 = (pos_t - DPAD_C) / DPAD_R
			if v.length() < 0.25:
				return Vector2.ZERO
			return v.limit_length(1.0)
	return Vector2.ZERO

func _botoes_tocados() -> Dictionary:
	var r := {}
	for idx in toques:
		var alvo: String = str(toques[idx]["alvo"])
		if BOTOES.has(alvo):
			r[alvo] = true
	return r

func _dir_pad(dev: int) -> Vector2:
	var v := Vector2(Input.get_joy_axis(dev, JOY_AXIS_LEFT_X), Input.get_joy_axis(dev, JOY_AXIS_LEFT_Y))
	if v.length() < 0.3:
		v = Vector2.ZERO
	if Input.is_joy_button_pressed(dev, JOY_BUTTON_DPAD_LEFT):
		v.x -= 1.0
	if Input.is_joy_button_pressed(dev, JOY_BUTTON_DPAD_RIGHT):
		v.x += 1.0
	if Input.is_joy_button_pressed(dev, JOY_BUTTON_DPAD_UP):
		v.y -= 1.0
	if Input.is_joy_button_pressed(dev, JOY_BUTTON_DPAD_DOWN):
		v.y += 1.0
	return v.limit_length(1.0)

func _entrada_pad(dev: int) -> Dictionary:
	return {
		"LP": Input.is_joy_button_pressed(dev, JOY_BUTTON_X),
		"LK": Input.is_joy_button_pressed(dev, JOY_BUTTON_A),
		"HP": Input.is_joy_button_pressed(dev, JOY_BUTTON_Y),
		"HK": Input.is_joy_button_pressed(dev, JOY_BUTTON_B),
		"CD": Input.is_joy_button_pressed(dev, JOY_BUTTON_RIGHT_SHOULDER),
		"ROLL": Input.is_joy_button_pressed(dev, JOY_BUTTON_LEFT_SHOULDER),
	}

func _entrada_p1() -> Dictionary:
	var pad := _entrada_pad(0)
	var tocado := _botoes_tocados()
	var r := {}
	for k in TECLAS:
		r[k] = bool(pad[k]) or tocado.has(k)
	return r

# Combos de toque: LP+LK = ROLL, HP+HK = CD.
func _logico(raw: Dictionary) -> Dictionary:
	var roll_c: bool = bool(raw["LP"]) and bool(raw["LK"])
	var cd_c: bool = bool(raw["HP"]) and bool(raw["HK"])
	return {
		"LP": bool(raw["LP"]) and not roll_c,
		"LK": bool(raw["LK"]) and not roll_c,
		"HP": bool(raw["HP"]) and not cd_c,
		"HK": bool(raw["HK"]) and not cd_c,
		"CD": bool(raw["CD"]) or cd_c,
		"ROLL": bool(raw["ROLL"]) or roll_c,
	}

# Botão segurado não repete golpe. Ao iniciar um golpe, ou ao sair de um
# estado livre e voltar a um livre, os botões ainda segurados ficam mascarados
# até serem soltos.
func _passo_jogador(p, dir: Vector2, raw: Dictionary, mask: Dictionary) -> void:
	var logico: Dictionary = _logico(raw)
	var ap := {}
	for k in TECLAS:
		ap[k] = bool(logico[k]) and not bool(mask[k])
	var era_livre: bool = _livre(p.estado)
	p.atualizar(dir, ap)
	if era_livre != _livre(p.estado):
		for k in TECLAS:
			if bool(raw[k]) or bool(logico[k]):
				mask[k] = true
	for k in TECLAS:
		if not (bool(raw[k]) or bool(logico[k])):
			mask[k] = false

func _livre(est: int) -> bool:
	return est == Personagem.Estado.PARADO or est == Personagem.Estado.ANDANDO or est == Personagem.Estado.PULANDO or est == Personagem.Estado.DEFENDENDO

func _mascara_vazia() -> Dictionary:
	var d := {}
	for k in TECLAS:
		d[k] = false
	return d

# ---------- Combate ----------

func _reiniciar_luta() -> void:
	p1.resetar(200.0, true)
	p2.resetar(720.0, false)
	p1.oponente = p2
	p2.oponente = p1
	mask1 = _mascara_vazia()
	mask2 = _mascara_vazia()
	ko_t = 0

func _resolver_combate(atk, dfn) -> void:
	if not atk.hitbox_ativa() or atk.golpe_acertou:
		return
	var g: Dictionary = atk.golpe_atual
	if not Caixa.colidem(atk.hitbox_rect(), dfn.corpo_rect()):
		return
	var res: String = dfn.resultado_para(g)
	if res == "nada":
		return
	atk.golpe_acertou = true
	if res == "bloqueio":
		dfn.receber_bloqueio(g)
		return
	var escala: float = maxf(0.5, 1.0 - 0.1 * float(atk.combo))
	var dano: float = float(g["dano"]) * escala
	var vida_antes: float = dfn.vida
	# Primeiro acerto de um combo zera a barra de dano do defensor.
	if atk.combo == 0:
		dfn.dano_combo = 0.0
	dfn.receber_acerto(g, dano)
	dfn.dano_combo += vida_antes - dfn.vida
	atk.combo += 1
	atk.janela_combo = Personagem.JANELA_COMBO
	if str(g["carga"]) != "" and float(g["energia_ganha"]) > 0.0:
		atk.barra.ganhar(float(g["energia_ganha"]))

# Combo para de contar quando a janela do último acerto acaba.
func _expirar_combos() -> void:
	_expirar_combo(p1, p2)
	_expirar_combo(p2, p1)

func _expirar_combo(atk, dfn) -> void:
	if atk.janela_combo <= 0:
		return
	atk.janela_combo -= 1
	if atk.janela_combo == 0:
		atk.combo = 0
		dfn.dano_combo = 0.0

func _separar_corpos() -> void:
	if p1.no_chao or p2.no_chao:
		return
	var d: float = p2.pos.x - p1.pos.x
	var falta: float = Personagem.CORPO_LARGURA - absf(d)
	if falta <= 0.0:
		return
	var s: float = 1.0 if d >= 0.0 else -1.0
	var metade: float = falta * 0.5
	p1.pos = Vector2(clampf(p1.pos.x - s * metade, Personagem.LIMITE_ESQ, Personagem.LIMITE_DIR), p1.pos.y)
	p2.pos = Vector2(clampf(p2.pos.x + s * metade, Personagem.LIMITE_ESQ, Personagem.LIMITE_DIR), p2.pos.y)

# ---------- Desenho ----------

func _draw() -> void:
	_desenhar_luta()
	_desenhar_hud()
	_desenhar_controles()

func _texto(s: String, pos: Vector2, tam: int = 14, cor: Color = Color.WHITE) -> void:
	draw_string(ThemeDB.fallback_font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1.0, tam, cor)

func _texto_dir(s: String, pos: Vector2, largura: float, tam: int = 14, cor: Color = Color.WHITE) -> void:
	draw_string(ThemeDB.fallback_font, pos, s, HORIZONTAL_ALIGNMENT_RIGHT, largura, tam, cor)

func _texto_c(r: Rect2, s: String, tam: int = 14, cor: Color = Color.WHITE) -> void:
	draw_string(ThemeDB.fallback_font, Vector2(r.position.x, r.position.y + r.size.y * 0.5 + tam * 0.35), s, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, tam, cor)

func _botao(r: Rect2, s: String, ativo: bool = false) -> void:
	draw_rect(r, Color(0.25, 0.35, 0.55) if ativo else Color(0.16, 0.16, 0.22))
	draw_rect(r, Color(0.6, 0.6, 0.7), false, 1.0)
	_texto_c(r, s, 13)

func _desenhar_luta() -> void:
	draw_rect(Rect2(0.0, 0.0, VIEW_W, VIEW_H), Color(0.09, 0.09, 0.12))
	draw_rect(Rect2(0.0, Personagem.CHAO_Y, VIEW_W, VIEW_H - Personagem.CHAO_Y), Color(0.18, 0.16, 0.2))
	draw_line(Vector2(0.0, Personagem.CHAO_Y), Vector2(VIEW_W, Personagem.CHAO_Y), Color(0.5, 0.5, 0.6), 2.0)
	_desenhar_personagem(p1, Color(0.3, 0.6, 1.0))
	_desenhar_personagem(p2, Color(1.0, 0.45, 0.2))
	if aviso != "":
		_texto(aviso, Vector2(20.0, 520.0), 12, Color(1.0, 0.8, 0.5))

func _desenhar_personagem(p, base: Color) -> void:
	var est: int = p.estado
	var cor: Color = base
	if est == Personagem.Estado.GOLPEADO:
		cor = base.lerp(Color.WHITE, 0.5)
	elif est == Personagem.Estado.CAIDO:
		cor = base.darkened(0.4)
	elif est == Personagem.Estado.ATACANDO:
		cor = base.lightened(0.3)
	elif est == Personagem.Estado.KO:
		cor = Color(0.3, 0.3, 0.3)
	elif est == Personagem.Estado.ESQUIVANDO or est == Personagem.Estado.LEVANTANDO:
		cor = Color(base.r, base.g, base.b, 0.55)
	var c: Rect2 = p.corpo_rect()
	draw_rect(c, cor)
	draw_rect(c, Color(1.0, 1.0, 1.0, 0.8), false, 2.0)
	var frente: float = 1.0 if p.direita else -1.0
	draw_circle(Vector2(p.pos.x + frente * 14.0, p.pos.y - 96.0), 5.0, Color.WHITE)
	var hb: Rect2 = p.hitbox_rect()
	if hb.size.x > 0.0:
		draw_rect(hb, Color(1.0, 0.2, 0.2, 0.5))

func _desenhar_hud() -> void:
	var r1 := Rect2(20.0, 60.0, 410.0, 16.0)
	var r2 := Rect2(530.0, 60.0, 410.0, 16.0)
	_barra_vida(r1, p1, false, COR_P1, COR_P1_FUNDO)
	_barra_vida(r2, p2, true, COR_P2, COR_P2_FUNDO)
	_barra_energia(Rect2(20.0, 82.0, 300.0, 8.0), p1, false)
	_barra_energia(Rect2(640.0, 82.0, 300.0, 8.0), p2, true)
	_texto(nome_p1, Vector2(20.0, 54.0), 14)
	_texto_dir("Treino (P2)", Vector2(530.0, 54.0), 410.0, 14)
	_texto(p1.nome_estado(), Vector2(20.0, 110.0), 12, Color(0.8, 0.8, 0.8))
	_texto_dir(p2.nome_estado(), Vector2(530.0, 110.0), 410.0, 12, Color(0.8, 0.8, 0.8))
	if p1.combo > 1:
		_texto("%d hits" % p1.combo, Vector2(20.0, 130.0), 16, Color(1.0, 0.9, 0.3))
	if p2.combo > 1:
		_texto_dir("%d hits" % p2.combo, Vector2(530.0, 130.0), 410.0, 16, Color(1.0, 0.9, 0.3))
	_botao(RECT_RESET, "RESET")
	if p1.estado == Personagem.Estado.KO or p2.estado == Personagem.Estado.KO:
		draw_string(ThemeDB.fallback_font, Vector2(0.0, 220.0), "K.O.", HORIZONTAL_ALIGNMENT_CENTER, VIEW_W, 56, Color(1.0, 0.3, 0.3))

# Barra de vida com a barra de dano ATRÁS dela.
# Ordem: fundo, faixa amarela fina (dano do combo), vida por cima.
# A faixa aparece só entre a vida atual e a vida que o defensor tinha antes do combo.
# Some quando o combo para de contar (_expirar_combo zera dano_combo).
func _barra_vida(r: Rect2, p, da_direita: bool, cor: Color, fundo: Color) -> void:
	draw_rect(r, fundo)
	var atual: float = clampf(float(p.vida) / Personagem.VIDA_MAX, 0.0, 1.0)
	var antes: float = clampf((float(p.vida) + float(p.dano_combo)) / Personagem.VIDA_MAX, 0.0, 1.0)
	if float(p.dano_combo) > 0.0 and antes > atual:
		draw_rect(_faixa_dano(r, atual, antes, da_direita), COR_DANO)
	var w: float = r.size.x * atual
	var x: float = r.position.x + (r.size.x - w if da_direita else 0.0)
	draw_rect(Rect2(x, r.position.y, w, r.size.y), cor)
	draw_rect(r, Color(1.0, 1.0, 1.0, 0.8), false, 1.0)

# Faixa fina, centralizada na altura da barra, entre a proporção atual (de)
# e a proporção de antes do combo (ate).
func _faixa_dano(r: Rect2, de: float, ate: float, da_direita: bool) -> Rect2:
	var x0: float
	var x1: float
	if da_direita:
		x0 = r.position.x + r.size.x * (1.0 - ate)
		x1 = r.position.x + r.size.x * (1.0 - de)
	else:
		x0 = r.position.x + r.size.x * de
		x1 = r.position.x + r.size.x * ate
	var h: float = r.size.y * FRACAO_FAIXA_DANO
	var y: float = r.position.y + (r.size.y - h) * 0.5
	return Rect2(x0, y, x1 - x0, h)

func _barra_energia(r: Rect2, p, da_direita: bool) -> void:
	draw_rect(r, Color(0.15, 0.15, 0.2))
	var maximo: float = maxf(1.0, float(p.barra.maximo))
	var prop: float = clampf(float(p.barra.valor) / maximo, 0.0, 1.0)
	var w: float = r.size.x * prop
	var x: float = r.position.x + (r.size.x - w if da_direita else 0.0)
	draw_rect(Rect2(x, r.position.y, w, r.size.y), Color(1.0, 0.7, 0.2))
	draw_rect(r, Color(1.0, 1.0, 1.0, 0.6), false, 1.0)

func _desenhar_controles() -> void:
	var tocado := _botoes_tocados()
	draw_circle(DPAD_C, DPAD_R, Color(1.0, 1.0, 1.0, 0.1))
	var dv: Vector2 = _vec_dpad()
	draw_circle(DPAD_C + dv * DPAD_R * 0.6, 26.0, Color(1.0, 1.0, 1.0, 0.4 if dv != Vector2.ZERO else 0.15))
	for k in BOTOES:
		var c: Vector2 = BOTOES[k]
		draw_circle(c, BOTAO_R, Color(1.0, 1.0, 1.0, 0.35 if tocado.has(k) else 0.12))
		draw_string(ThemeDB.fallback_font, c + Vector2(-BOTAO_R, 5.0), str(k), HORIZONTAL_ALIGNMENT_CENTER, BOTAO_R * 2.0, 14, Color(1.0, 1.0, 1.0, 0.8))