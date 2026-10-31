extends RefCounted

enum Estado { PARADO, ATACANDO, APANHANDO }

var nome: String
var vida: int = 100
var estado: Estado = Estado.PARADO

var golpe_startup: int = 0
var golpe_active: int = 0
var golpe_recovery: int = 0
var frame_atual: int = 0

# Novos atributos para armadura
var golpe_armadura_contra: int = -1  # -1 significa "sem armadura"
var golpe_armadura_fim: int = 0      # ate qual frame a armadura vale
var armadura_cargas_restantes: int = 0

func _init(nome_personagem: String):
	nome = nome_personagem

func iniciar_golpe(startup: int, active: int, recovery: int, armadura_contra: int = -1, armadura_fim: int = 0, armadura_cargas: int = 0):
	estado = Estado.ATACANDO
	golpe_startup = startup
	golpe_active = active
	golpe_recovery = recovery
	frame_atual = 0
	golpe_armadura_contra = armadura_contra
	golpe_armadura_fim = armadura_fim
	armadura_cargas_restantes = armadura_cargas
	print("%s iniciou um golpe (startup:%d active:%d recovery:%d)" % [nome, startup, active, recovery])

func esta_no_frame_ativo() -> bool:
	return estado == Estado.ATACANDO and frame_atual >= golpe_startup and frame_atual < (golpe_startup + golpe_active)

func esta_com_armadura_ativa() -> bool:
	return estado == Estado.ATACANDO and golpe_armadura_contra >= 0 and frame_atual < golpe_armadura_fim and armadura_cargas_restantes > 0

func avancar_frame():
	if estado == Estado.ATACANDO:
		frame_atual += 1
		var total = golpe_startup + golpe_active + golpe_recovery
		if frame_atual >= total:
			estado = Estado.PARADO
			print("%s voltou ao estado PARADO" % nome)

func levar_dano(quantidade: int):
	vida -= quantidade
	estado = Estado.APANHANDO
	print("%s levou %d de dano! Vida restante: %d" % [nome, quantidade, vida])

func receber_ataque(poder_do_golpe: int, dano: int):
	if esta_com_armadura_ativa():
		if poder_do_golpe <= golpe_armadura_contra:
			armadura_cargas_restantes -= 1
			print("%s ABSORVEU o ataque com ARMADURA! (sem dano)" % nome)
			return
		else:
			print("%s teve a ARMADURA QUEBRADA por um golpe forte demais!" % nome)
			levar_dano(dano)
			return

	levar_dano(dano)
