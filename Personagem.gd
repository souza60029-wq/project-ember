extends RefCounted

const Caixa = preload("res://Caixa.gd")
const Barra = preload("res://Barra.gd")

enum Estado { PARADO, ANDANDO, PULANDO, DEFENDENDO, ATACANDO, GOLPEADO, CAIDO, LEVANTANDO, ESQUIVANDO, KO }

const NOMES_ESTADO := ["PARADO", "ANDANDO", "PULANDO", "DEFENDENDO", "ATACANDO", "GOLPEADO", "CAIDO", "LEVANTANDO", "ESQUIVANDO", "KO"]
const DT: float = 1.0 / 60.0
const GRAVIDADE: float = 1800.0
const VEL_PULO: float = -750.0
const VEL_PULO_SOMBRA: float = -950.0
const VEL_ANDAR: float = 240.0
const CHAO_Y: float = 480.0
const LIMITE_ESQ: float = 40.0
const LIMITE_DIR: float = 920.0
const VIDA_MAX: float = 1000.0
const HITSTUN: int = 18
const HITSTUN_BLOWBACK: int = 20
const BLOQUEIO: int = 10
const CAIDO_FRAMES: int = 36
const CAIDO_BLOWOFF: int = 90
const LEVANTAR_FRAMES: int = 18
const ESQUIVA_FRAMES: int = 24
const ESQUIVA_VEL: float = 260.0
const CUSTO_ESQUIVA: float = 25.0
const CUSTO_GUARD_CANCEL: float = 50.0
const CORPO_LARGURA: float = 50.0
const CORPO_ALTURA: float = 120.0
const JANELA_PULO_SOMBRA: int = 6

var golpes: Array = []
var barra = Barra.new(300.0)
var pos: Vector2 = Vector2.ZERO
var vel: Vector2 = Vector2.ZERO
var no_chao: bool = false
var direita: bool = true
var vida: float = VIDA_MAX
var estado: Estado = Estado.PARADO
var tempo: int = 0
var duracao: int = 0
var total_ataque: int = 0
var golpe_atual: Dictionary = {}
var golpe_acertou: bool = false
var combo: int = 0
var oponente = null
var bloqueando: bool = false
var bloqueado: bool = false
var caido_recuperavel: bool = true
var carga_tras_t: float = 0.0
var carga_baixo_t: float = 0.0
var frames_desde_baixo: int = 999

# ---------- Dados dos golpes (funções estáticas, sem estado) ----------

static func golpe_padrao() -> Dictionary:
	return {
		"nome": "Golpe", "botao": "LP", "carga": "", "carga_seg": 0.0,
		"forca": 1, "startup": 5, "active": 3, "recovery": 8,
		"dano": 40.0, "custo": 0.0, "energia_ganha": 0.0,
		"antichao": false, "blowoff": false, "so_ar": false,
		"hitbox": {"x": 30.0, "y": -100.0, "w": 40.0, "h": 30.0}
	}

static func normalizar_golpe(g: Dictionary) -> Dictionary:
	var base: Dictionary = golpe_padrao()
	for k in base.keys():
		if k != "hitbox" and g.has(k):
			base[k] = g[k]
	if g.has("hitbox") and typeof(g["hitbox"]) == TYPE_DICTIONARY:
		var src: Dictionary = g["hitbox"]
		for h in ["x", "y", "w", "h"]:
			if src.has(h):
				base["hitbox"][h] = float(src[h])
	base["nome"] = str(base["nome"])
	base["botao"] = str(base["botao"])
	base["carga"] = str(base["carga"])
	base["carga_seg"] = float(base["carga_seg"])
	base["forca"] = int(base["forca"])
	base["startup"] = int(base["startup"])
	base["active"] = maxi(1, int(base["active"]))
	base["recovery"] = int(base["recovery"])
	base["dano"] = float(base["dano"])
	base["custo"] = float(base["custo"])
	base["energia_ganha"] = float(base["energia_ganha"])
	base["antichao"] = bool(base["antichao"])
	base["blowoff"] = bool(base["blowoff"])
	base["so_ar"] = bool(base["so_ar"])
	return base

static func _golpe(nome: String, botao: String, carga: String, carga_seg: float, forca: int, startup: int, active: int, recovery: int, dano: float, custo: float, ganha: float, antichao: bool, blowoff: bool, hx: float, hy: float, hw: float, hh: float) -> Dictionary:
	return {
		"nome": nome, "botao": botao, "carga": carga, "carga_seg": carga_seg,
		"forca": forca, "startup": startup, "active": active, "recovery": recovery,
		"dano": dano, "custo": custo, "energia_ganha": ganha,
		"antichao": antichao, "blowoff": blowoff, "so_ar": false,
		"hitbox": {"x": hx, "y": hy, "w": hw, "h": hh}
	}

static func golpes_padrao_ash() -> Array:
	# Ordem importa: o primeiro golpe da lista que bater nas condições é o escolhido.
	return [
		_golpe("Pluviose Super", "HP", "", 0.0, 3, 20, 6, 40, 300.0, 100.0, 0.0, false, false, 20.0, -130.0, 120.0, 120.0),
		_golpe("Ventose", "HP", "tras", 0.5, 3, 16, 5, 30, 140.0, 0.0, 30.0, false, false, 40.0, -110.0, 80.0, 50.0),
		_golpe("Nivose", "HK", "baixo", 0.5, 3, 12, 4, 28, 120.0, 0.0, 30.0, false, false, 40.0, -30.0, 80.0, 30.0),
		_golpe("Blow Off", "CD", "", 0.0, 3, 12, 4, 26, 100.0, 0.0, 0.0, false, true, 20.0, -100.0, 70.0, 60.0),
		_golpe("Soco Forte", "HP", "", 0.0, 2, 10, 4, 18, 90.0, 0.0, 0.0, false, false, 30.0, -105.0, 60.0, 35.0),
		_golpe("Chute Forte", "HK", "", 0.0, 3, 14, 4, 24, 110.0, 0.0, 0.0, false, false, 30.0, -60.0, 70.0, 40.0),
		_golpe("Soco Fraco", "LP", "", 0.0, 1, 5, 3, 8, 40.0, 0.0, 0.0, false, false, 30.0, -100.0, 40.0, 30.0),
		_golpe("Chute Fraco", "LK", "", 0.0, 1, 6, 3, 10, 40.0, 0.0, 0.0, false, false, 25.0, -50.0, 50.0, 30.0)
	]

# ---------- Ciclo de vida ----------

func definir_golpes(lista: Array) -> void:
	golpes = []
	for g in lista:
		if typeof(g) == TYPE_DICTIONARY:
			golpes.append(normalizar_golpe(g))

func resetar(x: float, olhando_direita: bool) -> void:
	pos = Vector2(x, CHAO_Y)
	vel = Vector2.ZERO
	no_chao = false
	direita = olhando_direita
	vida = VIDA_MAX
	barra.valor = 0.0
	combo = 0
	estado = Estado.PARADO
	tempo = 0
	duracao = 0
	total_ataque = 0
	golpe_atual = {}
	golpe_acertou = false
	bloqueando = false
	bloqueado = false
	caido_recuperavel = true
	carga_tras_t = 0.0
	carga_baixo_t = 0.0
	frames_desde_baixo = 999

# ---------- Entrada e estados ----------

func atualizar(dir: Vector2, apertados: Dictionary) -> void:
	if estado == Estado.KO:
		_aplicar_fisica()
		return
	if oponente != null and estado in [Estado.PARADO, Estado.ANDANDO, Estado.PULANDO, Estado.DEFENDENDO]:
		direita = oponente.pos.x >= pos.x
	var frente: float = 1.0 if direita else -1.0
	var atras: bool = dir.x * frente < -0.5
	var cima: bool = dir.y < -0.5
	var baixo: bool = dir.y > 0.5
	carga_tras_t = carga_tras_t + DT if atras else 0.0
	carga_baixo_t = carga_baixo_t + DT if baixo else 0.0
	frames_desde_baixo = 0 if baixo else mini(frames_desde_baixo + 1, 999)
	bloqueando = atras and estado in [Estado.PARADO, Estado.ANDANDO, Estado.PULANDO, Estado.DEFENDENDO, Estado.GOLPEADO]
	match estado:
		Estado.PARADO, Estado.ANDANDO, Estado.PULANDO, Estado.DEFENDENDO:
			_estado_livre(dir, apertados, atras, cima)
		Estado.ATACANDO:
			_processar_ataque()
		Estado.GOLPEADO:
			if bloqueado and apertados.get("CD", false) and barra.valor >= CUSTO_GUARD_CANCEL and oponente != null:
				_guard_cancel()
			else:
				_processar_golpeado()
		Estado.CAIDO:
			_processar_caido(apertados)
		Estado.LEVANTANDO, Estado.ESQUIVANDO:
			_processar_temporizado()
	_aplicar_fisica()

func _estado_livre(dir: Vector2, apertados: Dictionary, atras: bool, cima: bool) -> void:
	if apertados.get("ROLL", false) and not no_chao and barra.valor >= CUSTO_ESQUIVA:
		barra.gastar(CUSTO_ESQUIVA)
		_iniciar_esquiva()
		return
	var g: Dictionary = _escolher_golpe(apertados)
	if not g.is_empty():
		_executar(g)
		return
	if no_chao:
		estado = Estado.PULANDO
		vel.x = dir.x * VEL_ANDAR
		return
	if cima:
		vel.y = VEL_PULO_SOMBRA if frames_desde_baixo <= JANELA_PULO_SOMBRA else VEL_PULO
		no_chao = true
		estado = Estado.PULANDO
		vel.x = dir.x * VEL_ANDAR
		return
	if atras:
		estado = Estado.DEFENDENDO
		vel.x = dir.x * VEL_ANDAR * 0.5
	elif absf(dir.x) > 0.3:
		estado = Estado.ANDANDO
		vel.x = dir.x * VEL_ANDAR
	else:
		estado = Estado.PARADO
		vel.x = 0.0

func _escolher_golpe(apertados: Dictionary) -> Dictionary:
	for g in golpes:
		var d: Dictionary = g
		if not apertados.get(d["botao"], false):
			continue
		if d["carga"] == "tras" and carga_tras_t < float(d["carga_seg"]):
			continue
		if d["carga"] == "baixo" and carga_baixo_t < float(d["carga_seg"]):
			continue
		if d["so_ar"] and not no_chao:
			continue
		if float(d["custo"]) > barra.valor:
			continue
		return d
	return {}

func _executar(g: Dictionary) -> void:
	if str(g["carga"]) != "":
		carga_tras_t = 0.0
		carga_baixo_t = 0.0
	var custo: float = float(g["custo"])
	if custo > 0.0:
		barra.gastar(custo)
	golpe_atual = g.duplicate(true)
	golpe_acertou = false
	estado = Estado.ATACANDO
	tempo = 0
	total_ataque = int(g["startup"]) + int(g["active"]) + int(g["recovery"])
	if not no_chao:
		vel.x = 0.0

func _processar_ataque() -> void:
	tempo += 1
	if tempo > total_ataque:
		golpe_atual = {}
		tempo = 0
		estado = Estado.PULANDO if no_chao else Estado.PARADO
		return
	if not no_chao:
		vel.x = 0.0

func _iniciar_esquiva() -> void:
	estado = Estado.ESQUIVANDO
	tempo = 0
	duracao = ESQUIVA_FRAMES
	golpe_atual = {}
	bloqueado = false
	vel.x = -(1.0 if direita else -1.0) * ESQUIVA_VEL

func _processar_temporizado() -> void:
	tempo += 1
	if estado == Estado.ESQUIVANDO:
		vel.x = -(1.0 if direita else -1.0) * ESQUIVA_VEL
	else:
		vel.x = 0.0
	if tempo >= duracao:
		_voltar_neutro()

func _processar_caido(apertados: Dictionary) -> void:
	tempo += 1
	vel.x *= 0.85
	if caido_recuperavel and apertados.get("ROLL", false) and barra.valor >= CUSTO_ESQUIVA:
		barra.gastar(CUSTO_ESQUIVA)
		estado = Estado.LEVANTANDO
		tempo = 0
		duracao = ESQUIVA_FRAMES
		vel.x = 0.0
		return
	if tempo >= duracao:
		estado = Estado.LEVANTANDO
		tempo = 0
		duracao = LEVANTAR_FRAMES
		vel.x = 0.0

func _processar_golpeado() -> void:
	tempo += 1
	vel.x *= 0.85
	if tempo >= duracao:
		_voltar_neutro()

func _voltar_neutro() -> void:
	estado = Estado.PULANDO if no_chao else Estado.PARADO
	tempo = 0
	duracao = 0
	bloqueado = false
	golpe_atual = {}

func _guard_cancel() -> void:
	barra.gastar(CUSTO_GUARD_CANCEL)
	var sentido: float = 1.0 if oponente.pos.x > pos.x else -1.0
	oponente.receber_blowback(sentido * 300.0)
	_voltar_neutro()

# ---------- Hitbox e colisão (quem decide o acerto é o Main) ----------

func corpo_rect() -> Rect2:
	return Rect2(pos.x - CORPO_LARGURA * 0.5, pos.y - CORPO_ALTURA, CORPO_LARGURA, CORPO_ALTURA)

func hitbox_ativa() -> bool:
	if estado != Estado.ATACANDO or golpe_atual.is_empty():
		return false
	var inicio: int = int(golpe_atual["startup"])
	var fim: int = inicio + int(golpe_atual["active"])
	return tempo > inicio and tempo <= fim

func hitbox_rect() -> Rect2:
	if not hitbox_ativa():
		return Rect2()
	return Caixa.rect_hitbox(golpe_atual["hitbox"], pos, direita)

func resultado_para(g: Dictionary) -> String:
	if estado == Estado.ESQUIVANDO or estado == Estado.LEVANTANDO or estado == Estado.KO:
		return "nada"
	var antichao: bool = g["antichao"]
	if estado == Estado.CAIDO:
		return "acerto" if antichao else "nada"
	if antichao:
		return "nada"
	if bloqueando:
		return "bloqueio"
	return "acerto"

func receber_bloqueio(_g: Dictionary) -> void:
	estado = Estado.GOLPEADO
	tempo = 0
	duracao = BLOQUEIO
	bloqueado = true
	golpe_atual = {}
	vel.x = _empurrao_base() * 60.0

func receber_acerto(g: Dictionary, dano: float) -> void:
	var era_caido: bool = estado == Estado.CAIDO
	vida = maxf(0.0, vida - dano)
	golpe_atual = {}
	bloqueado = false
	tempo = 0
	if vida <= 0.0:
		estado = Estado.KO
		vel.x = 0.0
		return
	var blowoff: bool = g["blowoff"]
	var knock: bool = era_caido or bool(g["antichao"]) or blowoff or int(g["forca"]) >= 3
	if knock:
		estado = Estado.CAIDO
		duracao = CAIDO_BLOWOFF if blowoff else CAIDO_FRAMES
		caido_recuperavel = not blowoff
		vel.x = 0.0 if era_caido else _empurrao_base() * 120.0
	else:
		estado = Estado.GOLPEADO
		duracao = HITSTUN
		vel.x = _empurrao_base() * 60.0

func receber_blowback(vx: float) -> void:
	estado = Estado.GOLPEADO
	tempo = 0
	duracao = HITSTUN_BLOWBACK
	bloqueado = false
	golpe_atual = {}
	vel.x = vx

func _empurrao_base() -> float:
	# Empurra para trás, já que o personagem está virado para o oponente
	return -1.0 if direita else 1.0

# ---------- Física e utilidades ----------

func _aplicar_fisica() -> void:
	if no_chao:
		vel.y += GRAVIDADE * DT
	pos += vel * DT
	if pos.y >= CHAO_Y:
		pos.y = CHAO_Y
		if no_chao:
			no_chao = false
			vel.y = 0.0
			if estado == Estado.PULANDO:
				estado = Estado.PARADO
	pos.x = clampf(pos.x, LIMITE_ESQ, LIMITE_DIR)

func nome_estado() -> String:
	return NOMES_ESTADO[estado]