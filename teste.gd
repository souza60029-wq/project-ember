extends SceneTree

func _init():
	print("Iniciando teste de combate...")

	var hp_jogador2 = 100
	var dano_do_golpe = 15

	print("Jogador 2 tem %d de vida." % hp_jogador2)
	print("Jogador 1 aplica um golpe de %d de dano..." % dano_do_golpe)

	hp_jogador2 -= dano_do_golpe

	print("Jogador 2 agora tem %d de vida." % hp_jogador2)

	if hp_jogador2 == 85:
		print("RESULTADO: SUCESSO - o calculo de dano esta correto!")
	else:
		print("RESULTADO: FALHOU - algo esta errado.")

	quit()
