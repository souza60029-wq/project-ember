extends RefCounted

enum Estado { PARADO, ATACANDO, APANHANDO }

var nome: String
var vida: int = 100
var estado: Estado = Estado.PARADO

# Dados do golpe atual (frame data)
var golpe_startup: int = 0
var golpe_active: int = 0
var golpe_recovery: int = 0
var frame_atual: int = 0

func _init(nome_personagem: String):
	nome = nome_personagem

func iniciar_golpe(startup: int, active: int, recovery: int):
	estado = Estado.ATACANDO
	golpe_startup = startup
	golpe_active = active
	golpe_recovery = recovery
	frame_atual = 0
	print("%s iniciou um golpe (startup:%d active:%d recovery:%d)" % [nome, startup, active, recovery])

func esta_no_frame_ativo() -> bool:
	return estado == Estado.ATACANDO and frame_atual >= golpe_startup and frame_atual < (golpe_startup + golpe_active)

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
