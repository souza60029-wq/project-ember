extends SceneTree

const Personagem = preload("res://Personagem.gd")
const Caixa = preload("res://Caixa.gd")

func _init():
	print("=== TESTE 1: Esquiva da imunidade total ===")
	var ash = Personagem.new("Ash")
	ash.iniciar_esquiva()
	ash.receber_ataque(5, 20)  # deve ser ignorado, esta imune
	print("Vida do Ash apos ataque durante esquiva: %d (esperado 100)" % ash.vida)

	print("\n=== TESTE 2: Combo com escala de dano ===")
	var kyo = Personagem.new("Kyo")
	var iori = Personagem.new("Iori")
	kyo.iniciar_golpe(1, 1, 1, null, Personagem.Forca.FRACO)
	iori.receber_ataque(1, 20)  # hit 1: 100% -> 20 dano
	kyo.iniciar_golpe(1, 1, 1, null, Personagem.Forca.FRACO)
	iori.receber_ataque(1, 20)  # hit 2: 85% -> 17 dano
	kyo.iniciar_golpe(1, 1, 1, null, Personagem.Forca.FRACO)
	iori.receber_ataque(1, 20)  # hit 3: 70% -> 14 dano
	print("Vida final do Iori: %d (esperado 49)" % iori.vida)

	print("\n=== TESTE 3: Regra de cancelamento por forca ===")
	var rock = Personagem.new("Rock")
	var sucesso1 = rock.iniciar_golpe(1, 5, 5, null, Personagem.Forca.FORTE)
	var sucesso2 = rock.iniciar_golpe(1, 1, 1, null, Personagem.Forca.FRACO)  # tentando cancelar forte->fraco, DEVE FALHAR
	print("Cancelar FORTE para FRACO foi permitido? %s (esperado false)" % sucesso2)

	print("\n=== TESTE 4: Bloqueio de cancelamento para COMANDO ===")
	var ralf = Personagem.new("Ralf")
	ralf.iniciar_golpe(1, 5, 5, null, Personagem.Forca.FRACO)
	var sucesso3 = ralf.iniciar_golpe(1, 1, 1, null, Personagem.Forca.COMANDO, false, false)  # flag desligada, DEVE FALHAR
	print("Cancelar para COMANDO sem flag foi permitido? %s (esperado false)" % sucesso3)

	print("\n=== RESULTADO GERAL ===")
	if ash.vida == 100 and iori.vida == 49 and sucesso2 == false and sucesso3 == false:
		print("SUCESSO TOTAL - todas as 4 mecanicas validadas!")
	else:
		print("FALHOU em algum ponto, revisar acima")

	quit()