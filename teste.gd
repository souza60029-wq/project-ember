extends SceneTree

const Personagem = preload("res://Personagem.gd")
const Caixa = preload("res://Caixa.gd")

func _init():
	var resultados = []

	print("=== TESTE A: Golpe anti-chao so acerta CAIDO, nao LEVANTANDO ===")
	var ash = Personagem.new("Ash")
	ash.iniciar_queda(true)
	ash.receber_ataque(1, 10, 0, false, false)  # sem flag, nao deve acertar
	var teste_a1 = (ash.vida == 100)
	ash.receber_ataque(1, 10, 0, false, true)   # com flag, deve acertar
	var teste_a2 = (ash.vida == 90)
	ash.tentar_recuperacao_rapida()
	ash.receber_ataque(1, 10, 0, false, true)   # levantando = invencivel, nao deve acertar
	var teste_a3 = (ash.vida == 90)
	resultados.append(teste_a1 and teste_a2 and teste_a3)
	print("Teste A resultado: %s\n" % resultados[-1])

	print("=== TESTE B: Blow Off impede recuperacao rapida ===")
	var kyo = Personagem.new("Kyo")
	kyo.receber_ataque(1, 15, 0, true, false)  # blow off
	var teste_b1 = (kyo.estado == Personagem.Estado.CAINDO and not kyo.pode_recuperar_queda)
	var conseguiu_recuperar = kyo.tentar_recuperacao_rapida()
	var teste_b2 = (conseguiu_recuperar == false)
	resultados.append(teste_b1 and teste_b2)
	print("Teste B resultado: %s\n" % resultados[-1])

	print("=== TESTE C: Guard Cancel Blow Back (custa barra, da invencibilidade) ===")
	var iori = Personagem.new("Iori")
	iori.estado = Personagem.Estado.BLOQUEANDO
	var hitbox_gc = Caixa.new(20, 40, 30, 20)
	var falhou_sem_barra = iori.tentar_guard_cancel(hitbox_gc, 2, 3, 10)
	var teste_c1 = (falhou_sem_barra == false)
	iori.barra.ganhar(100.0)
	iori.estado = Personagem.Estado.BLOQUEANDO
	var conseguiu_gc = iori.tentar_guard_cancel(hitbox_gc, 2, 3, 10)
	iori.avancar_frame()
	iori.avancar_frame()
	iori.receber_ataque(1, 20)  # deveria ser ignorado, esta invencivel no golpe
	var teste_c2 = (conseguiu_gc and iori.vida == 100)
	resultados.append(teste_c1 and teste_c2)
	print("Teste C resultado: %s\n" % resultados[-1])

	print("=== TESTE D: Pulo normal vs sombra, janela de defesa aerea ===")
	var ralf = Personagem.new("Ralf")
	ralf.iniciar_pulo("normal", "normal")
	var teste_d1 = (ralf.estado == Personagem.Estado.PULO_PREPARANDO)
	for i in range(4): ralf.avancar_frame()
	var teste_d2 = (ralf.estado == Personagem.Estado.NO_AR)
	var teste_d3 = (ralf.esta_na_janela_defesa_aerea() == false)  # frame 0 do ar, inicio ainda nao
	for i in range(10): ralf.avancar_frame()
	var teste_d4 = (ralf.esta_na_janela_defesa_aerea() == true)  # meio do pulo

	var king = Personagem.new("King")
	king.iniciar_pulo("sombra", "normal")
	var teste_d5 = (king.estado == Personagem.Estado.NO_AR)  # sombra pula direto, sem preparo

	resultados.append(teste_d1 and teste_d2 and teste_d3 and teste_d4 and teste_d5)
	print("Teste D resultado: %s\n" % resultados[-1])

	print("=== TESTE E: Golpe que exige estar no ar ===")
	var rock = Personagem.new("Rock")
	var hitbox_aereo = Caixa.new(10, 10, 20, 20)
	var falhou_no_chao = rock.iniciar_golpe(2, 2, 5, hitbox_aereo, Personagem.Forca.FRACO, false, false, -1, 0, 0, false, false, false, true)
	var teste_e1 = (falhou_no_chao == false)
	rock.iniciar_pulo("normal", "normal")
	for i in range(4): rock.avancar_frame()  # agora no ar
	var conseguiu_no_ar = rock.iniciar_golpe(2, 2, 5, hitbox_aereo, Personagem.Forca.FRACO, false, false, -1, 0, 0, false, false, false, true)
	var teste_e2 = (conseguiu_no_ar == true)
	resultados.append(teste_e1 and teste_e2)
	print("Teste E resultado: %s\n" % resultados[-1])

	print("=== TESTE F: Golpe que exige charge ===")
	var ash2 = Personagem.new("Ash2")
	var hitbox_charge = Caixa.new(10, 10, 20, 20)
	var falhou_sem_charge = ash2.iniciar_golpe(2, 2, 5, hitbox_charge, Personagem.Forca.ESPECIAL, true, false, -1, 0, 0, false, false, false, false, 30)
	var teste_f1 = (falhou_sem_charge == false)
	ash2.segurando_direcao_frames = 35
	var conseguiu_com_charge = ash2.iniciar_golpe(2, 2, 5, hitbox_charge, Personagem.Forca.ESPECIAL, true, false, -1, 0, 0, false, false, false, false, 30)
	var teste_f2 = (conseguiu_com_charge == true)
	resultados.append(teste_f1 and teste_f2)
	print("Teste F resultado: %s\n" % resultados[-1])

	print("=== RESULTADO FINAL ===")
	var tudo_ok = true
	for r in resultados:
		if r == false:
			tudo_ok = false
	if tudo_ok:
		print("SUCESSO TOTAL - TODAS AS MECANICAS NOVAS VALIDADAS!")
	else:
		print("FALHOU em pelo menos um teste - revisar resultados acima: %s" % str(resultados))

	quit()