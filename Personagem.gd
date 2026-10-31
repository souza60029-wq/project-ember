extends RefCounted

const Barra = preload("res://Barra.gd")
const Caixa = preload("res://Caixa.gd")

enum Estado { PARADO, ATACANDO, APANHANDO, BLOQUEANDO, CAINDO }

var nome: String
var vida: int = 100
var estado: Estado = Estado.PARADO
var barra = Barra.new()

var pos_x: float = 0.0
var pos_y: float = 0.0
var virado_para_direita: bool = true

var golpe_startup: int = 0
var golpe_active: int = 0
var golpe_recovery: int = 0
var frame_atual: int = 0
var golpe_e_comando_especial: bool = false

var golpe_armadura_contra: int = -1
var golpe_armadura_fim: int = 0
var armadura_cargas_restantes: int = 0

var golpe_hitbox: Caixa = null
var hurtbox_padrao: Caixa

func _init(nome_personagem: String, x_inicial: float = 0.0):
	nome = nome_personagem
	pos_x = x_inicial
	# Hurtbox padrao: um retangulo "ocupando o corpo" do personagem
	hurtbox_padrao = Caixa.new(0, 0, 40, 100)

func iniciar_golpe(startup: int, active: int, recovery: int, hitbox: Caixa, e_comando_especial: bool = false, armadura_contra: int = -1, armadura_fim: int = 0, armadura_cargas: int = 0):
	estado = Estado.ATACANDO
	golpe_startup = startup
	golpe_active = active
	golpe_recovery = recovery
	frame_atual = 0
	golpe_hitbox = hitbox
	golpe_e_comando_especial = e_comando_especial
	golpe_armadura_contra = armadura_contra
	golpe_armadura_fim = armadura_fim
	armadura_cargas_restantes = armadura_cargas

	print("%s iniciou um golpe em x=%.0f (startup:%d active:%d recovery:%d)" % [nome, pos_x, startup, active, recovery])

	if e_comando_especial:
		barra.ganhar(20.0)

func esta_no_frame_ativo() -> bool:
	return estado == Estado.ATACANDO and frame_atual >= golpe_startup and frame_atual < (golpe_startup + golpe_active)

func esta_com_armadura_ativa() -> bool:
	return estado == Estado.ATACANDO and golpe_armadura_contra >= 0 and frame_atual < golpe_armadura_fim and armadura_cargas_restantes > 0

func obter_hitbox_absoluta() -> Rect2:
	return golpe_hitbox.obter_retangulo_absoluto(pos_x, pos_y, virado_para_direita)

func obter_hurtbox_absoluta() -> Rect2:
	return hurtbox_padrao.obter_retangulo_absoluto(pos_x, pos_y, virado_para_direita)

func avancar_frame():
	if estado == Estado.ATACANDO:
		frame_atual += 1
		var total = golpe_startup + golpe_active + golpe_recovery
		if frame_atual >= total:
			estado = Estado.PARADO
			print("%s voltou ao estado PARADO" % nome)

func levar_dano(quantidade: int, empurrar_x: float = 0.0):
	vida -= quantidade
	estado = Estado.APANHANDO
	pos_x += empurrar_x
	print("%s levou %d de dano! Vida restante: %d (empurrado para x=%.0f)" % [nome, quantidade, vida, pos_x])

func receber_ataque(poder_do_golpe: int, dano: int, empurrar_x: float = 0.0):
	if esta_com_armadura_ativa():
		if poder_do_golpe <= golpe_armadura_contra:
			armadura_cargas_restantes -= 1
			print("%s ABSORVEU o ataque com ARMADURA! (sem dano)" % nome)
			return
		else:
			print("%s teve a ARMADURA QUEBRADA por um golpe forte demais!" % nome)
			levar_dano(dano, empurrar_x)
			return

	levar_dano(dano, empurrar_x)
