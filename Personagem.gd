extends RefCounted

const Caixa = preload("res://Caixa.gd")
const Barra = preload("res://Barra.gd")

const DT: float = 1.0 / 60.0
const NOMES_ESTADO = ["PARADO", "ANDANDO", "PULANDO", "DEFENDENDO", "ATACANDO", "GOLPEADO", "CAIDO", "LEVANTANDO", "ESQUIVANDO", "KO"]

enum Estado { PARADO, ANDANDO, PULANDO, DEFENDENDO, ATACANDO, GOLPEADO, CAIDO, LEVANTANDO, ESQUIVANDO, KO }

var nome: String = "Lutador"
var pos: Vector2 = Vector2.ZERO
var vel: Vector2 = Vector2.ZERO
var virado_direita: bool = true
var estado: int = Estado.PARADO
var tempo_estado: float = 0.0

var vida: Barra
var energia: Barra

var chao_y: float = 480.0
var gravidade: float = 1800.0
var vel_pulo: float = -750.0
var vel_pulo_sombra: float = -950.0
var vel_andar: float = 240.0

var invulneravel: bool = false
var knockdown_sem_recuperacao: bool = false
var eh_pulo_sombra: bool = false
var frames_hitstun: int = 0

var charge_tras: float = 0.0
var charge_baixo: float = 0.0
var ultimo_baixo: float = 0.0
var tempo_desde_soltou_baixo: float = 99.0

var golpes: Array = []
var golpe_atual: Dictionary = {}
var frame_golpe: int = 0
var golpe_acertou: bool = false
var em_guard_cancel: bool = false

var hurtboxes: Array = []
var hitboxes: Array = []

func _init(p_nome: String, p_pos: Vector2, p_direita: bool) -> void:
	nome = p_nome
	hurtboxes.append(Caixa.new(Caixa.Tipo.CORPO, -20, -95, 40, 95))
	golpes = golpes_padrao_ash()
	resetar(p_pos, p_direita)

func resetar(p_pos: Vector2, p_direita: bool) -> void:
	pos = p_pos
	vel = Vector2.ZERO
	virado_direita = p_direita
	estado = Estado.PARADO
	tempo_estado = 0.0
	invulneravel = false
	knockdown_sem_recuperacao = false
	eh_pulo_sombra = false
	frames_hitstun = 0
	charge_tras = 0.0
	charge_baixo = 0.0
	ultimo_baixo = 0.0
	tempo_desde_soltou_baixo = 99.0
	golpe_atual = {}
	frame_golpe = 0
	golpe_acertou = false
	em_guard_cancel = false
	hitboxes.clear()
	vida = Barra.new(100.0, 1, true)
	energia = Barra.new(100.0, 3, false)

# ---------- Golpes (dados) ----------

static func golpe_padrao() -> Dictionary:
	return {
		"nome": "Novo golpe",
		"botao": "LP",
		"carga": "nenhuma",
		"carga_seg": 0.5,
		"forca": 0,
		"startup": 5,
		"active": 3,
		"recovery": 8,
		"dano": 5.0,
		"custo": 0.0,
		"energia_ganha": 0.0,
		"antichao": false,
		"blowoff": false,
		"so_ar": false,
		"hitbox": {"x": 20.0, "y": -75.0, "w": 45.0, "h": 20.0}
	}

static func normalizar_golpe(g: Dictionary) -> Dictionary:
	var base := golpe_padrao()
	for k in base.keys():
		if k != "hitbox" and g.has(k):
			base[k] = g[k]
	if g.has("hitbox") and typeof(g["hitbox"]) == TYPE_DICTIONARY:
		for eixo in ["x", "y", "w", "h"]:
			base.hitbox[eixo] = float(g.hitbox.get(eixo, base.hitbox[eixo]))
	return base

static func _montar(n: String, botao: String, carga: String, forca: int, st: int, at: int, rc: int, dano: float, custo: float, ganho: float, hit: Array, blowoff: bool = false) -> Dictionary:
	var g := golpe_padrao()
	g.nome = n
	g.botao = botao
	g.carga = carga
	g.forca = forca
	g.startup = st
	g.active = at
	g.recovery = rc
	g.dano = dano
	g.custo = custo
	g.energia_ganha = ganho
	g.blowoff = blowoff
	g.hitbox = {"x": float(hit[0]), "y": float(hit[1]), "w": float(hit[2]), "h": float(hit[3])}
	return g

static func golpes_padrao_ash() -> Array:
	return [
		_montar("Soco Fraco", "LP", "nenhuma", 0, 4, 3, 6, 4.0, 0.0, 0.0, [20, -75, 45, 20]),
		_montar("Chute Fraco", "LK", "nenhuma", 0, 5, 3, 7, 4.0, 0.0, 0.0, [20, -45, 50, 20]),
		_montar("Soco Forte", "HP", "nenhuma", 1, 8, 4, 12, 8.0, 0.0, 0.0, [20, -80, 50, 25]),
		_montar("Chute Forte", "HK", "nenhuma", 1, 9, 5, 14, 10.0, 0.0, 0.0, [20, -65, 60, 25]),
		_montar("Ventose", "HP", "tras", 2, 11, 6, 16, 14.0, 0.0, 15.0, [25, -60, 70, 30]),
		_montar("Nivose", "HK", "baixo", 2, 7, 8, 22, 16.0, 0.0, 20.0, [0, -110, 50, 70]),
		_montar("Blow Off", "CD", "nenhuma", 1, 14, 5, 20, 12.0, 0.0, 0.0, [15, -70, 65, 35], true),
		_montar("Pluviose (Super)", "HP", "nenhuma", 3, 5, 12, 26, 32.0, 100.0, 0.0, [10, -120, 70, 90], true),
	]

static func golpe_guard_cancel() -> Dictionary:
	return _montar("Guard Cancel Blow Back", "CD", "nenhuma", 3, 3, 5, 14, 8.0, 0.0, 0.0, [15, -70, 60, 35], true)

# ---------- Atualizacao (1 frame fixo) ----------

func atualizar(dir: Vector2, apertados: Dictionary) -> void:
	tempo_estado += DT
	if estado == Estado.KO:
		return

	var tras: bool = (dir.x < -0.5 and virado_direita) or (dir.x > 0.5 and not virado_direita)
	_atualizar_cargas(dir, tras)

	if apertados.get("ROLL", false) and _pode_esquivar():
		_iniciar_esquiva()
	elif apertados.get("CD", false) and estado == Estado.DEFENDENDO and energia.gastar(50.0):
		_executar(golpe_guard_cancel(), true)
	elif estado in [Estado.PARADO, Estado.ANDANDO, Estado.DEFENDENDO, Estado.PULANDO, Estado.ATACANDO]:
		var escolhido: Dictionary = _escolher_golpe(apertados)
		if not escolhido.is_empty() and _pode_cancelar_para(escolhido):
			_executar(escolhido)

	match estado:
		Estado.PARADO, Estado.ANDANDO, Estado.DEFENDENDO:
			_processar_chao(dir, tras)
		Estado.ATACANDO:
			_processar_ataque()
		Estado.GOLPEADO:
			frames_hitstun -= 1
			if frames_hitstun <= 0:
				_mudar_estado(_estado_padrao())
		Estado.CAIDO:
			if tempo_estado >= 0.6:
				_mudar_estado(Estado.LEVANTANDO)
				invulneravel = true
		Estado.LEVANTANDO:
			if tempo_estado >= 0.3:
				invulneravel = false
				knockdown_sem_recuperacao = false
				_mudar_estado(_estado_padrao())
		Estado.ESQUIVANDO:
			pos.x += vel_andar * 1.5 * DT * (1.0 if virado_direita else -1.0)
			if tempo_estado >= 0.4:
				invulneravel = false
				_mudar_estado(_estado_padrao())

	_fisica()

func _atualizar_cargas(dir: Vector2, tras: bool) -> void:
	if tras:
		charge_tras += DT
	else:
		charge_tras = 0.0
	if dir.y > 0.5:
		charge_baixo += DT
		tempo_desde_soltou_baixo = 0.0
	else:
		if charge_baixo > 0.0:
			ultimo_baixo = charge_baixo
		charge_baixo = 0.0
		tempo_desde_soltou_baixo += DT

func _processar_chao(dir: Vector2, tras: bool) -> void:
	if pos.y < chao_y:
		return
	if dir.y < -0.5:
		_pular(dir.x)
		return
	if tras:
		_mudar_estado(Estado.DEFENDENDO)
		return
	if abs(dir.x) > 0.2:
		pos.x += dir.x * vel_andar * DT
		_mudar_estado(Estado.ANDANDO)
	else:
		_mudar_estado(Estado.PARADO)

func _pular(dir_x: float) -> void:
	eh_pulo_sombra = ultimo_baixo >= 0.15 and tempo_desde_soltou_baixo <= 0.2
	if eh_pulo_sombra:
		ultimo_baixo = 0.0
	vel.y = vel_pulo_sombra if eh_pulo_sombra else vel_pulo
	vel.x = dir_x * vel_andar
	_mudar_estado(Estado.PULANDO)

func _fisica() -> void:
	if pos.y < chao_y or vel.y < 0.0:
		vel.y += gravidade * DT
		pos += vel * DT
	if pos.y >= chao_y and vel.y >= 0.0:
		pos.y = chao_y
		vel = Vector2.ZERO
		if estado == Estado.PULANDO:
			_mudar_estado(Estado.PARADO)

func _estado_padrao() -> int:
	return Estado.PULANDO if pos.y < chao_y else Estado.PARADO

func _mudar_estado(novo: int) -> void:
	if novo != estado:
		estado = novo
		tempo_estado = 0.0

# ---------- Escolha de golpe ----------

func _escolher_golpe(apertados: Dictionary) -> Dictionary:
	var melhor: Dictionary = {}
	var melhor_nota: int = -1
	for g in golpes:
		if not apertados.get(g.botao, false):
			continue
		if g.carga == "tras" and charge_tras < float(g.carga_seg):
			continue
		if g.carga == "baixo" and charge_baixo < float(g.carga_seg):
			continue
		if g.so_ar and pos.y >= chao_y:
			continue
		if float(g.custo) > energia.valor:
			continue
		var nota: int = int(g.forca) + (10 if g.carga != "nenhuma" else 0)
		if nota > melhor_nota:
			melhor_nota = nota
			melhor = g
	return melhor

func _pode_cancelar_para(g: Dictionary) -> bool:
	if estado != Estado.ATACANDO:
		return true
	return int(g.forca) > int(golpe_atual.forca)

func _executar(g: Dictionary, guard_cancel: bool = false) -> void:
	if not guard_cancel and float(g.custo) > 0.0:
		if not energia.gastar(float(g.custo)):
			return
	golpe_atual = g
	golpe_acertou = false
	frame_golpe = 0
	hitboxes.clear()
	em_guard_cancel = guard_cancel
	invulneravel = guard_cancel
	_mudar_estado(Estado.ATACANDO)

func _processar_ataque() -> void:
	frame_golpe += 1
	var s := int(golpe_atual.startup)
	var a := int(golpe_atual.active)
	var r := int(golpe_atual.recovery)
	if frame_golpe >= s and frame_golpe < s + a and not golpe_acertou:
		if hitboxes.is_empty():
			var h = golpe_atual.hitbox
			hitboxes.append(Caixa.new(Caixa.Tipo.ATAQUE, h.x, h.y, h.w, h.h))
	else:
		hitboxes.clear()
	if frame_golpe >= s + a + r:
		_terminar_ataque()

func _terminar_ataque() -> void:
	hitboxes.clear()
	golpe_atual = {}
	if em_guard_cancel:
		invulneravel = false
		em_guard_cancel = false
	_mudar_estado(_estado_padrao())

# ---------- Esquiva ----------

func _pode_esquivar() -> bool:
	if estado in [Estado.PARADO, Estado.ANDANDO, Estado.DEFENDENDO]:
		return true
	return estado == Estado.CAIDO and not knockdown_sem_recuperacao

func _iniciar_esquiva() -> void:
	invulneravel = true
	_mudar_estado(Estado.ESQUIVANDO)

# ---------- Recebimento de golpes ----------

func marcar_acerto(g: Dictionary) -> void:
	golpe_acertou = true
	hitboxes.clear()
	if str(g.carga) != "nenhuma":
		energia.ganhar(float(g.energia_ganha))

func pode_ser_atingido_por(g: Dictionary) -> bool:
	if invulneravel or estado == Estado.KO:
		return false
	if g.antichao:
		return estado == Estado.CAIDO
	return estado != Estado.CAIDO

func receber_golpe(g: Dictionary) -> void:
	if estado == Estado.DEFENDENDO:
		frames_hitstun = 10
		_mudar_estado(Estado.GOLPEADO)
		return
	vida.valor = max(vida.valor - float(g.dano), 0.0)
	if vida.valor <= 0.0:
		_mudar_estado(Estado.KO)
		return
	if g.blowoff:
		knockdown_sem_recuperacao = true
		_mudar_estado(Estado.CAIDO)
	else:
		frames_hitstun = 18
		_mudar_estado(Estado.GOLPEADO)

func nome_estado() -> String:
	return NOMES_ESTADO[estado]