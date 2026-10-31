extends RefCounted

const Barra = preload("res://Barra.gd")
const Caixa = preload("res://Caixa.gd")

enum Estado { PARADO, ATACANDO, APANHANDO, BLOQUEANDO, CAINDO, LEVANTANDO, ESQUIVANDO, PULO_PREPARANDO, NO_AR }
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
var golpe_acerta_caido: bool = false
var golpe_e_blow_off: bool = false
var golpe_invencivel: bool = false

var golpe_armadura_contra: int = -1
var golpe_armadura_fim: int = 0
var armadura_cargas_restantes: int = 0

var golpe_hitbox: Caixa = null
var hurtbox_padrao: Caixa

var esquiva_frames_imune: int = 12
var esquiva_frames_recovery: int = 6
var esquiva_frame_atual: int = 0

var hits_consecutivos_no_oponente: int = 0
var ultima_forca_usada: int = -1

var pode_recuperar_queda: bool = true
var frames_caido_atual: int = 0
var frames_caido_antes_de_levantar: int = 40
var frames_levantando_atual: int = 0
var frames_levantando_total: int = 12

var pulo_frames_preparo_total: int = 0
var pulo_frame_preparo_atual: int = 0
var pulo_frames_ar_total: int = 0
var pulo_frame_ar_atual: int = 0

var segurando_direcao_frames: int = 0

func _init(nome_personagem: String, x_inicial: float = 0.0):
	nome = nome_personagem
	pos_x = x_inicial
	hurtbox_padrao = Caixa.new(0, 0, 40, 100)

func esta_no_ar() -> bool:
	return estado == Estado.NO_AR or estado == Estado.PULO_PREPARANDO

func iniciar_golpe(startup: int, active: int, recovery: int, hitbox: Caixa, forca: int = Forca.FRACO, e_comando_especial: bool = false, pode_cancelar_para_comando: bool = false, armadura_contra: int = -1, armadura_fim: int = 0, armadura_cargas: int = 0, acerta_caido: bool = false, e_blow_off: bool = false, invencivel: bool = false, requer_ar: bool = false, requer_charge: int = 0) -> bool:

	if requer_ar and not esta_no_ar():
		print("%s NAO PODE - golpe exige estar no ar" % nome)
		return false

	if requer_charge > 0 and segurando_direcao_frames < requer_charge:
		print("%s NAO PODE - charge insuficiente (%d/%d)" % [nome, segurando_direcao_frames, requer_charge])
		return false

	if estado == Estado.ATACANDO:
		if forca < ultima_forca_usada:
			print("%s NAO PODE cancelar forca %d para forca %d" % [nome, ultima_forca_usada, forca])
			return false
		if forca == Forca.COMANDO and not golpe_pode_cancelar_para_comando:
			print("%s NAO PODE cancelar para COMANDO (flag desligada)" % nome)
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
	golpe_acerta_caido = acerta_caido
	golpe_e_blow_off = e_blow_off
	golpe_invencivel = invencivel
	ultima_forca_usada = forca

	print("%s iniciou golpe (forca:%d startup:%d active:%d blow_off:%s)" % [nome, forca, startup, active, e_blow_off])

	if e_comando_especial:
		barra.ganhar(20.0)

	return true

func tentar_guard_cancel(hitbox: Caixa, startup: int, active: int, recovery: int) -> bool:
	if estado != Estado.BLOQUEANDO:
		print("%s nao esta bloqueando, nao pode fazer Guard Cancel" % nome)
		return false
	if not barra.gastar(50.0):
		return false
	estado = Estado.PARADO
	iniciar_golpe(startup, active, recovery, hitbox, Forca.COMANDO, false, false, -1, 0, 0, false, true, true)
	print("%s executou GUARD CANCEL BLOW BACK (invencivel)!" % nome)
	return true

func iniciar_esquiva():
	estado = Estado.ESQUIVANDO
	esquiva_frame_atual = 0
	hits_consecutivos_no_oponente = 0
	print("%s iniciou uma ESQUIVA" % nome)

func iniciar_queda(recuperavel: bool):
	estado = Estado.CAINDO
	pode_recuperar_queda = recuperavel
	frames_caido_atual = 0
	print("%s caiu no chao (recuperavel: %s)" % [nome, recuperavel])

func tentar_recuperacao_rapida() -> bool:
	if estado != Estado.CAINDO:
		return false
	if not pode_recuperar_queda:
		print("%s NAO PODE recuperacao rapida (foi Blow Off)" % nome)
		return false
	estado = Estado.LEVANTANDO
	frames_levantando_atual = 0
	print("%s fez RECUPERACAO RAPIDA (invencivel)" % nome)
	return true

func iniciar_pulo(tipo_pulo: String = "normal", tipo_altura: String = "normal") -> bool:
	if estado != Estado.PARADO:
		return false

	var preparo = 4
	var duracao_ar = 30
	if tipo_altura == "curto":
		duracao_ar = 18
	if tipo_pulo == "sombra":
		preparo = 0
		duracao_ar += 6

	pulo_frames_preparo_total = preparo
	pulo_frame_preparo_atual = 0
	pulo_frames_ar_total = duracao_ar
	pulo_frame_ar_atual = 0

	estado = Estado.PULO_PREPARANDO if preparo > 0 else Estado.NO_AR

	print("%s iniciou pulo (%s, %s) preparo:%d ar:%d" % [nome, tipo_pulo, tipo_altura, preparo, duracao_ar])
	return true

func esta_na_janela_defesa_aerea() -> bool:
	if estado != Estado.NO_AR:
		return false
	var inicio = pulo_frames_ar_total * 0.25
	var fim = pulo_frames_ar_total * 0.75
	return pulo_frame_ar_atual >= inicio and pulo_frame_ar_atual < fim

func esta_imune_na_esquiva() -> bool:
	return estado == Estado.ESQUIVANDO and esquiva_frame_atual < esquiva_frames_imune

func esta_invencivel_no_golpe() -> bool:
	return estado == Estado.ATACANDO and golpe_invencivel and frame_atual < (golpe_startup + golpe_active)

func esta_no_frame_ativo() -> bool:
	return estado == Estado.ATACANDO and frame_atual >= golpe_startup and frame_atual < (golpe_startup + golpe_active)

func esta_com_armadura_ativa() -> bool:
	return estado == Estado.ATACANDO and golpe_armadura_contra >= 0 and frame_atual < golpe_armadura_fim and armadura_cargas_restantes > 0

func obter_hitbox_absoluta() -> Rect2:
	return golpe_hitbox.obter_retangulo_absoluto(pos_x, pos_y, virado_para_direita)

func obter_hurtbox_absoluta() -> Rect2:
	return hurtbox_padrao.obter_retangulo_absoluto(pos_x, pos_y, virado_para_direita)

func avancar_frame():
	match estado:
		Estado.ATACANDO:
			frame_atual += 1
			if frame_atual >= (golpe_startup + golpe_active + golpe_recovery):
				estado = Estado.PARADO
				ultima_forca_usada = -1

		Estado.ESQUIVANDO:
			esquiva_frame_atual += 1
			if esquiva_frame_atual >= (esquiva_frames_imune + esquiva_frames_recovery):
				estado = Estado.PARADO

		Estado.CAINDO:
			frames_caido_atual += 1
			if frames_caido_atual >= frames_caido_antes_de_levantar:
				estado = Estado.LEVANTANDO
				frames_levantando_atual = 0

		Estado.LEVANTANDO:
			frames_levantando_atual += 1
			if frames_levantando_atual >= frames_levantando_total:
				estado = Estado.PARADO

		Estado.PULO_PREPARANDO:
			pulo_frame_preparo_atual += 1
			if pulo_frame_preparo_atual >= pulo_frames_preparo_total:
				estado = Estado.NO_AR
				pulo_frame_ar_atual = 0

		Estado.NO_AR:
			pulo_frame_ar_atual += 1
			if pulo_frame_ar_atual >= pulo_frames_ar_total:
				estado = Estado.PARADO

func levar_dano(quantidade: int, empurrar_x: float = 0.0) -> int:
	var escala = max(1.0 - (hits_consecutivos_no_oponente * 0.15), 0.2)
	var dano_final = int(quantidade * escala)
	vida -= dano_final
	pos_x += empurrar_x
	hits_consecutivos_no_oponente += 1
	print("%s levou %d de dano! Vida restante: %d" % [nome, dano_final, vida])
	return dano_final

func receber_ataque(poder_do_golpe: int, dano: int, empurrar_x: float = 0.0, e_blow_off: bool = false, acerta_caido: bool = false):
	if estado == Estado.LEVANTANDO:
		print("%s esta LEVANTANDO (invencivel) - ignorado!" % nome)
		return

	if estado == Estado.CAINDO:
		if not acerta_caido:
			print("%s esta CAIDO - golpe normal nao alcanca" % nome)
			return
		print("%s foi atingido CAIDO por golpe anti-chao!" % nome)
		levar_dano(dano, empurrar_x)
		return

	if esta_imune_na_esquiva():
		print("%s estava IMUNE (esquiva) - ignorado!" % nome)
		return

	if esta_invencivel_no_golpe():
		print("%s estava INVENCIVEL (Guard Cancel) - ignorado!" % nome)
		return

	if esta_com_armadura_ativa():
		if poder_do_golpe <= golpe_armadura_contra:
			armadura_cargas_restantes -= 1
			print("%s ABSORVEU com ARMADURA!" % nome)
			return
		else:
			print("%s teve ARMADURA QUEBRADA!" % nome)
			levar_dano(dano, empurrar_x)
			estado = Estado.APANHANDO
			return

	levar_dano(dano, empurrar_x)

	if e_blow_off:
		iniciar_queda(false)
	else:
		estado = Estado.APANHANDO