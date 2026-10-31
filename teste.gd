extends SceneTree

const Personagem = preload("res://Personagem.gd")

func _init():
	print("=== Simulando ARMADURA (exemplo Kyo vs duas magias da King) ===")

	var kyo = Personagem.new("Kyo")

	# Golpe do Kyo: startup 5, active 3, recovery 10
	# Armadura resiste a golpes de poder <= 2, mas so vale ate o frame 5 (durante o startup)
	kyo.iniciar_golpe(5, 3, 10, 2, 5, 1)

	# As duas magias da King chegando em momentos diferentes
	var ataques_da_king = [
		{"frame": 2, "poder": 2, "dano": 10},  # chega durante a janela de armadura
		{"frame": 9, "poder": 2, "dano": 10},  # chega depois da armadura ja ter expirado
	]

	for frame in range(20):
		print("--- Frame %d ---" % frame)

		for ataque in ataques_da_king:
			if ataque["frame"] == frame:
				print("King lanca uma magia (poder %d)..." % ataque["poder"])
				kyo.receber_ataque(ataque["poder"], ataque["dano"])

		kyo.avancar_frame()

	print("=== Fim da simulacao ===")
	print("Vida final do Kyo: %d" % kyo.vida)

	if kyo.vida == 90:
		print("RESULTADO: SUCESSO - primeira magia absorvida, segunda acertou normal!")
	else:
		print("RESULTADO: FALHOU")

	quit()
