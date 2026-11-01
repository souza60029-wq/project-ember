extends SceneTree

const Personagem = preload("res://Personagem.gd")

var falhas: int = 0

func check(cond: bool, msg: String) -> void:
	if cond:
		print("  OK    ", msg)
	else:
		print("  FALHA ", msg)
		falhas += 1

func novo(direita: bool = true):
	return Personagem.new("Teste", Vector2(300, 480), direita)

func _init() -> void:
	print("=== TESTES DA ENGINE ===")
	teste_antichao()
	teste_blowoff()
	teste_guard_cancel()
	teste_pulo_sombra()
	teste_golpe_so_ar()
	teste_carga()
	teste_hit_unico()
	teste_bloqueio()
	teste_json()
	if falhas == 0:
		print("SUCESSO TOTAL - ENGINE VALIDADA!")
		quit(0)
	else:
		print("TOTAL DE FALHAS: ", falhas)
		quit(1)

func teste_antichao() -> void:
	print("A. Anti-chao so acerta CAIDO")
	var p = novo()
	var ac = Personagem.normalizar_golpe({"antichao": true})
	var normal = Personagem.normalizar_golpe({})
	p.estado = Personagem.Estado.CAIDO
	check(p.pode_ser_atingido_por(ac), "anti-chao acerta CAIDO")
	check(not p.pode_ser_atingido_por(normal), "golpe normal nao acerta CAIDO")
	p.estado = Personagem.Estado.GOLPEADO
	check(not p.pode_ser_atingido_por(ac), "anti-chao nao acerta GOLPEADO")
	p.estado = Personagem.Estado.LEVANTANDO
	p.invulneravel = true
	check(not p.pode_ser_atingido_por(ac), "anti-chao nao acerta LEVANTANDO invulneravel")

func teste_blowoff() -> void:
	print("B. Blow Off gera knockdown sem recuperacao")
	var p = novo()
	p.receber_golpe(Personagem.normalizar_golpe({"blowoff": true, "dano": 12.0}))
	check(p.estado == Personagem.Estado.CAIDO, "blow off derruba (CAIDO)")
	check(p.vida.valor == 88.0, "dano aplicado (100 -> 88)")
	p.atualizar(Vector2.ZERO, {"ROLL": true})
	check(p.estado == Personagem.Estado.CAIDO, "roll nao recupera blow off")
	check(p.knockdown_sem_recuperacao, "flag de knockdown sem recuperacao ativa")

func teste_guard_cancel() -> void:
	print("C. Guard Cancel custa 50 e da invulnerabilidade")
	var p = novo()
	p.energia.valor = 300.0
	p.estado = Personagem.Estado.DEFENDENDO
	p.atualizar(Vector2(-1, 0), {"CD": true})
	check(p.energia.valor == 250.0, "custo 50 (300 -> 250)")
	check(p.estado == Personagem.Estado.ATACANDO, "entra em ataque")
	check(p.invulneravel, "invulneravel durante guard cancel")

func teste_pulo_sombra() -> void:
	print("D. Pulo de sombra")
	var s = novo()
	for i in 10:
		s.atualizar(Vector2(0, 1), {})
	s.atualizar(Vector2(0, -1), {})
	check(s.estado == Personagem.Estado.PULANDO and s.eh_pulo_sombra, "agachar + cima = pulo de sombra")
	var n = novo()
	n.atualizar(Vector2(0, -1), {})
	check(n.estado == Personagem.Estado.PULANDO and not n.eh_pulo_sombra, "cima sem agachar = pulo normal")

func teste_golpe_so_ar() -> void:
	print("E. Golpe que exige ar")
	var chao = novo()
	chao.golpes = [Personagem.normalizar_golpe({"botao": "LP", "so_ar": true})]
	chao.atualizar(Vector2.ZERO, {"LP": true})
	check(chao.estado != Personagem.Estado.ATACANDO, "nao sai no chao")
	var ar = novo()
	ar.golpes = [Personagem.normalizar_golpe({"botao": "LP", "so_ar": true})]
	ar.pos.y = 300.0
	ar.atualizar(Vector2.ZERO, {"LP": true})
	check(ar.estado == Personagem.Estado.ATACANDO, "sai no ar")

func teste_carga() -> void:
	print("F. Carga e prioridade")
	var sem = novo()
	sem.atualizar(Vector2.ZERO, {"HP": true})
	check(sem.golpe_atual.get("nome", "") == "Soco Forte", "HP sem carga = Soco Forte")
	var com = novo()
	for i in 40:
		com.atualizar(Vector2(-1, 0), {})
	com.atualizar(Vector2(-1, 0), {"HP": true})
	check(com.golpe_atual.get("nome", "") == "Ventose", "HP com tras 0.66s = Ventose")

func teste_hit_unico() -> void:
	print("G. Hitbox acerta uma vez por golpe")
	var p = novo()
	p.atualizar(Vector2.ZERO, {"LP": true})
	for i in 4:
		p.atualizar(Vector2.ZERO, {})
	check(not p.hitboxes.is_empty(), "hitbox ativa na fase active")
	p.marcar_acerto(p.golpe_atual)
	check(p.hitboxes.is_empty(), "hitbox some ao acertar")
	for i in 3:
		p.atualizar(Vector2.ZERO, {})
	check(p.hitboxes.is_empty(), "hitbox nao volta depois do acerto")

func teste_bloqueio() -> void:
	print("H. Bloqueio")
	var p = novo()
	p.estado = Personagem.Estado.DEFENDENDO
	p.receber_golpe(Personagem.normalizar_golpe({"dano": 20.0}))
	check(p.vida.valor == 100.0, "bloqueio nao da dano")
	check(p.estado == Personagem.Estado.GOLPEADO, "bloqueio gera hitstun")

func teste_json() -> void:
	print("I. Ida e volta JSON")
	var original = Personagem.golpes_padrao_ash()
	var txt = JSON.stringify(original)
	var volta = JSON.parse_string(txt)
	check(typeof(volta) == TYPE_ARRAY and volta.size() == original.size(), "JSON com mesma quantidade de golpes")
	var sup = Personagem.normalizar_golpe(volta[7])
	check(sup.nome == "Pluviose (Super)" and int(sup.startup) == 5, "golpe volta com nome e frames")
	check(sup.hitbox.w == 70.0, "hitbox volta corretamente")