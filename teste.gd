extends SceneTree

const Personagem = preload("res://Personagem.gd")
const Caixa = preload("res://Caixa.gd")

func _init():
	print("=== Simulando COLISAO REAL POR DISTANCIA ===")

	var kyo = Personagem.new("Kyo", 0.0)
	var ash = Personagem.new("Ash", 50.0)  # Ash comeca perto do Kyo

	# Hitbox do golpe do Kyo: comeca 20px a frente dele, vai 30px de largura, 20 de altura
	var hitbox_kyo = Caixa.new(20, 40, 30, 20)
	kyo.iniciar_golpe(3, 2, 8, hitbox_kyo)

	for frame in range(6):
		print("--- Frame %d ---" % frame)
		if kyo.esta_no_frame_ativo():
			var h = kyo.obter_hitbox_absoluta()
			var hurt_ash = ash.obter_hurtbox_absoluta()
			if Caixa.colidem(h, hurt_ash):
				print("COLISAO! Golpe do Kyo acertou o Ash (estavam perto o suficiente)")
				ash.receber_ataque(3, 15, 80.0)  # empurra o Ash 80px pra longe
			else:
				print("Golpe do Kyo nao alcancou o Ash (fora de alcance)")
		kyo.avancar_frame()

	print("\n-- Agora o Ash esta longe (pos_x=%.0f). Kyo tenta outro golpe curto --" % ash.pos_x)

	var hitbox_kyo2 = Caixa.new(20, 40, 30, 20)
	kyo.iniciar_golpe(3, 2, 8, hitbox_kyo2)

	for frame in range(6):
		print("--- Frame %d ---" % frame)
		if kyo.esta_no_frame_ativo():
			var h = kyo.obter_hitbox_absoluta()
			var hurt_ash = ash.obter_hurtbox_absoluta()
			if Caixa.colidem(h, hurt_ash):
				print("COLISAO! Golpe alcancou mesmo longe (ISSO SERIA UM BUG)")
			else:
				print("Golpe NAO alcancou - distancia fez a fisica correta barrar o combo")
		kyo.avancar_frame()

	print("\n=== Fim da simulacao ===")
	print("Posicao final do Ash: %.0f" % ash.pos_x)
	print("Vida final do Ash: %d" % ash.vida)

	if ash.pos_x == 130.0 and ash.vida == 85:
		print("RESULTADO: SUCESSO - colisao por distancia funcionando corretamente!")
	else:
		print("RESULTADO: FALHOU")

	quit()
