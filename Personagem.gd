extends RefCounted

const Barra = preload("res://Barra.gd")
const Caixa = preload("res://Caixa.gd")

enum Estado { PARADO, ATACANDO, APANHANDO, BLOQUEANDO, CAINDO, ESQUIVANDO }
enum Forca { FRACO, MEDIO, FORTE, ESPECIAL, SUPER, COMANDO }

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
var golpe_forca: int = Forca.FRACO
var golpe_pode_cancelar_para_comando: bool = false

var golpe_armadura_contra: int = -1
var golpe_armadura_fim: int = 0
var armadura_cargas_restantes: int = 0

var golpe_hitbox: Caixa = null
var hurtbox_padrao: Caixa

# Esquiva (reaproveitada por recovery rapido e GCBB)
var esquiva_frames_imune: int = 12
var esquiva_frames_recovery: int = 6
var esquiva_frame_atual: int = 0

# Combo tracking
var hits_consecutivos_no_oponente: int = 0
var ultima_forca_usada: int = -1

func _init(nome_personagem: String, x_inicial: float = 0.0):
	nome = nome_personagem
	pos_x = x_inicial
	hurtbox_padrao = Caixa.new(0, 0, 40, 100)

func iniciar_golpe(startup: int, active: int, recovery: int, hitbox: Caixa, forca: int = Forca.FRACO, e_comando_especial: bool = false, pode_cancelar_para_comando: bool = false, armadura_contra: int = -1, armadura_fim: int = 0, armadura_cargas: int = 0) -> bool:
	# Regra de cancelamento: so permite iniciar novo golpe durante ataque anterior
	# se a forca for igual ou maior (chain combo classico)
	if estado == Estado.ATACANDO:
		if forca < ultima_forca_usada:
			print("%s NAO PODE cancelar golpe forca %d para forca %d (regra de combo)" % [nome, ultima_forca_usada, forca])
			return false
		if forca == Forca.COMANDO and not golpe_pode_cancelar_para_comando:
			print("%s NAO PODE cancelar para um golpe de COMANDO (flag desligada)" % nome)
			return false

	estado = Estado.ATACANDO
	golpe_startup = startup
	golpe_active = active
	golpe_recovery = recovery
	frame_atual = 0
	golpe_hitbox = hitbox
	golpe_forca = forca
	golpe_e_comando_especial = e_comando_especial
	golpe_pode_cancelar_para_comando = pode_cancelar_para_comando
	golpe_armadura_contra = armadura_contra
	golpe_armadura_fim = armadura_fim
	armadura_cargas_restantes = armadura_cargas
	ultima_forca_usada = forca

	print("%s iniciou golpe (forca:%d startup:%d active:%d recovery:%d)" % [nome, forca, startup, active, recovery])

	if e_comando_especial:
		barra.ganhar(20.0)

	return true

func iniciar_esquiva():
	estado = Estado.ESQUIVANDO
	esquiva_frame_atual = 0
	hits_consecutivos_no_oponente = 0
	print("%s iniciou uma ESQUIVA" % nome)

func esta_imune_na_esquiva() -> bool:
	return estado == Estado.ESQUIVANDO and esquiva_frame_atual < esquiva_frames_imune

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
			ultima_forca_usada = -1
			print("%s voltou ao estado PARADO" % nome)

	elif estado == Estado.ESQUIVANDO:
		esquiva_frame_atual += 1
		var total = esquiva_frames_imune + esquiva_frames_recovery
		if esquiva_frame_atual >= total:
			estado = Estado.PARADO
			print("%s terminou a ESQUIVA, voltou ao PARADO" % nome)

func levar_dano(quantidade: int, empurrar_x: float = 0.0):
	# Escala de dano por combo: cada hit consecutivo reduz o dano
	var escala = max(1.0 - (hits_consecutivos_no_oponente * 0.15), 0.2)
	var dano_final = int(quantidade * escala)

	vida -= dano_final
	estado = Estado.APANHANDO
	pos_x += empurrar_x
	hits_consecutivos_no_oponente += 1

	print("%s levou %d de dano (escala %.0f%%, hit #%d)! Vida restante: %d" % [nome, dano_final, escala * 100, hits_consecutivos_no_oponente, vida])

func receber_ataque(poder_do_golpe: int, dano: int, empurrar_x: float = 0.0):
	if esta_imune_na_esquiva():
		print("%s estava IMUNE (esquiva) - ataque nao fez nada!" % nome)
		return

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