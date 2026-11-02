extends RefCounted

# Regras de um lutador: estados, física, golpes e combo.
# Não desenha nada e não lê arquivos.
# Pulo: decolagem no chão (4 frames no normal, 2 na sombra). A direção é escolhida
# na decolagem e fica travada até cair. Sem controle aéreo.
# Escala: corpo e hitbox crescem; velocidade e altura do pulo ficam em px.

const Barra = preload("res://engine/nucleo/Barra.gd")
const Formato = preload("res://engine/formato/Formato.gd")

enum Estado { PARADO, ANDANDO, PULANDO, DEFENDENDO, ATACANDO, GOLPEADO, CAIDO, LEVANTANDO, ESQUIVANDO, KO, DECOLANDO }

const NOMES_ESTADO := ["PARADO", "ANDANDO", "PULANDO", "DEFENDENDO", "ATACANDO", "GOLPEADO", "CAIDO", "LEVANTANDO", "ESQUIVANDO", "KO", "DECOLANDO"]
const DT: float = 1.0 / 60.0
const GRAVIDADE: float = 1800.0

# Velocidade inicial do pulo (px/s; negativo sobe).
# Normal: alto -560 (25% abaixo de -750), baixo -400.
# Sombra: 25% acima do normal correspondente: alto -700, baixo -500.
const VEL_NORMAL_ALTO: float = -560.0
const VEL_NORMAL_BAIXO: float = -400.0
const VEL_SOMBRA_ALTO: float = -700.0
const VEL_SOMBRA_BAIXO: float = -500.0
# Frames de decolagem no chão antes de sair do chão.
const DECOLAGEM_NORMAL: int = 4
const DECOLAGEM_SOMBRA: int = 2

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
const ESCALA_MIN: float = 0.5
const ESCALA_MAX: float = 4.0
const JANELA_PULO_SOMBRA: int = 6
const JANELA_COMBO: int = 50
const DIRECAO_SALTO_MIN: float = 0.3

var golpes: Array = []
var barra = Barra.new()
var escala: float = 1.0
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
var janela_combo: int = 0
var dano_combo: float = 0.0
var oponente = null
var bloqueando: bool = false
var bloqueado: bool = false
var caido_recuperavel: bool = true
var carga_tras_t: float = 0.0
var carga_baixo_t: float = 0.0
var frames_desde_baixo: int = 999
var pulo_sombra: bool = false
var pulo_direcao_x: float = 0.0

# ---------- Ciclo de vida ----------

func definir_golpes(lista: Array) -> void:
	golpes = []
	for g in lista:
		if typeof(g) == TYPE_DICTIONARY:
			golpes.append(Formato.normalizar_golpe(g))


func definir_escala(e: float) -> void:
	escala = clampf(e, ESCALA_MIN, ESCALA_MAX)


func largura_corpo() -> float:
	return CORPO_LARGURA * escala


func altura_corpo() -> float:
	return CORPO_ALTURA * escala


func resetar(x: float, olhando_direita: bool) -> void:
	pos = Vector2(x, CHAO_Y)
	vel = Vector2.ZERO
	no_chao = false
	direita = olhando_direita
	vida = VIDA_MAX
	barra.valor = 0.0
	combo = 0
	janela_combo = 0
	dano_combo = 0.0
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
	pulo_sombra = false
	pulo_direcao_x = 0.0

# ---------- Entrada e estados ----------

func atualizar(dir: Vector2, apertados: Dictionary) -> void:
	if estado == Estado.KO:
		_aplicar_fisica()
		return
	# Vira para o oponente só no chão, em estado livre. No ar a direção fica travada.
	if oponente != null and not no_chao and estado in [Estado.PARADO, Estado.ANDANDO, Estado.DEFENDENDO]:
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
		Estado.DECOLANDO:
			_processar_decolagem(dir)
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
		# No ar: a direção foi escolhida na decolagem. Sem controle aéreo.
		estado = Estado.PULANDO
		return
	if cima:
		_iniciar_decolagem(dir)
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


# Decolagem: começa no chão, sem movimento. Ao fim, decide alto ou baixo pelo cima
# (ainda segurado = alto; já solto = baixo) e sai com a direção escolhida no início.
func _iniciar_decolagem(dir: Vector2) -> void:
	pulo_sombra = frames_desde_baixo <= JANELA_PULO_SOMBRA
	pulo_direcao_x = dir.x if absf(dir.x) > DIRECAO_SALTO_MIN else 0.0
	estado = Estado.DECOLANDO
	tempo = 0
	duracao = DECOLAGEM_SOMBRA if pulo_sombra else DECOLAGEM_NORMAL
	vel = Vector2.ZERO


func _processar_decolagem(dir: Vector2) -> void:
	tempo += 1
	vel.x = 0.0
	if tempo < duracao:
		return
	var alto: bool = dir.y < -0.5
	if pulo_sombra:
		vel.y = VEL_SOMBRA_ALTO if alto else VEL_SOMBRA_BAIXO
	else:
		vel.y = VEL_NORMAL_ALTO if alto else VEL_NORMAL_BAIXO
	vel.x = pulo_direcao_x * VEL_ANDAR
	no_chao = true
	estado = Estado.PULANDO
	tempo = 0
	duracao = 0


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

# ---------- Hitbox e colisão (quem decide o acerto é a Luta) ----------

func corpo_rect() -> Rect2:
	var w: float = largura_corpo()
	var h: float = altura_corpo()
	return Rect2(pos.x - w * 0.5, pos.y - h, w, h)


func hitbox_ativa() -> bool:
	if estado != Estado.ATACANDO or golpe_atual.is_empty():
		return false
	var inicio: int = int(golpe_atual["startup"])
	var fim: int = inicio + int(golpe_atual["active"])
	return tempo > inicio and tempo <= fim


# Hitbox na escala do personagem. Virado para a esquerda, espelha em relação ao corpo.
func hitbox_rect() -> Rect2:
	if not hitbox_ativa():
		return Rect2()
	var hb: Dictionary = golpe_atual["hitbox"]
	var x_rel: float = float(hb["x"]) * escala
	var w: float = float(hb["w"]) * escala
	var x: float = pos.x + x_rel if direita else pos.x - x_rel - w
	return Rect2(x, pos.y + float(hb["y"]) * escala, w, float(hb["h"]) * escala)


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
			# Pouso: deslize horizontal do pulo ou do ataque aéreo para no chão.
			if estado == Estado.PULANDO or estado == Estado.ATACANDO:
				vel.x = 0.0
			if estado == Estado.PULANDO:
				estado = Estado.PARADO
	pos.x = clampf(pos.x, LIMITE_ESQ, LIMITE_DIR)


func nome_estado() -> String:
	return NOMES_ESTADO[estado]