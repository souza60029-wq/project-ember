extends SceneTree

func _init():
	print("=== Simulando combate frame a frame ===")

	var kyo = Personagem.new("Kyo")
	var iori = Personagem.new("Iori")

	# Kyo usa um golpe com 5 frames de startup, 3 de active, 10 de recovery
	kyo.iniciar_golpe(5, 3, 10)

	for frame in range(20):
		print("--- Frame %d ---" % frame)

		if kyo.esta_no_frame_ativo():
			print("O golpe do Kyo esta ATIVO neste frame!")
			if iori.estado != Personagem.Estado.APANHANDO:
				iori.levar_dano(15)

		kyo.avancar_frame()

	print("=== Fim da simulacao ===")
	print("Vida final do Iori: %d" % iori.vida)

	if iori.vida == 85:
		print("RESULTADO: SUCESSO - sistema de frame data funcionando!")
	else:
		print("RESULTADO: FALHOU")

	quit()
