extends SceneTree

# Testes de lógica. Rodam sem cena e sem autoloads (Config, Textos, Audio, Navegacao, Catalogo).
# Usam só fixtures em testes/fixtures/, nunca o conteúdo do usuário.

const Caixa = preload("res://engine/nucleo/Caixa.gd")
const Barra = preload("res://engine/nucleo/Barra.gd")
const Personagem = preload("res://engine/nucleo/Personagem.gd")
const Formato = preload("res://engine/formato/Formato.gd")
const Eventos = preload("res://engine/sons/Eventos.gd")

const FIXTURE := "res://testes/fixtures/boneco_teste/personagem.json"

var falhas: int = 0
var passou: int = 0

func _init() -> void:
	_testar_formato()
	_testar_personagem()
	_testar_caixa_barra()
	_testar_combate()
	_testar_tempo_sprites()
	_testar_eventos()
	print("Resultado: %d ok, %d falha(s)" % [passou, falhas])
	quit(1 if falhas > 0 else 0)

func _checar(nome: String, cond: bool) -> void:
	if cond:
		passou += 1
		print("  ok    - " + nome)
	else:
		falhas += 1
		print("  FALHA - " + nome)

func _sem_botoes() -> Dictionary:
	return {"LP": false, "LK": false, "HP": false, "HK": false, "BO": false, "ESQ": false}

func _testar_formato() -> void:
	print("Formato")
	var r: Dictionary = Formato.ler(FIXTURE)
	_checar("fixture carrega", bool(r["ok"]))
	if not bool(r["ok"]):
		print("    erro: " + str(r["erro"]))
		return
	var per: Dictionary = r["personagem"]
	_checar("fixture tem 2 golpes", per["golpes"].size() == 2)
	_checar("sanitizar_id", Formato.sanitizar_id("Ash Crimson!") == "ash_crimson")
	var futuro: Dictionary = Formato.normalizar({"formato": 99, "nome": "X", "golpes": []})
	_checar("versão futura recusada", not bool(futuro["ok"]))
	var ms: Array = Formato.moveset(per)
	_checar("moveset tem um item por golpe", ms.size() == 2)

func _testar_personagem() -> void:
	print("Personagem")
	var r: Dictionary = Formato.ler(FIXTURE)
	var per: Dictionary = r["personagem"]
	var p = Personagem.new()
	var outro = Personagem.new()
	p.oponente = outro
	outro.oponente = p
	p.definir_golpes(per["golpes"])
	outro.definir_golpes(per["golpes"])
	p.resetar(200.0, true)
	outro.resetar(720.0, false)
	_checar("começa parado", p.estado == Personagem.Estado.PARADO)
	_checar("sem hitbox antes de atacar", not p.hitbox_ativa())

	var lp := _sem_botoes()
	lp["LP"] = true
	p.atualizar(Vector2.ZERO, lp)
	_checar("LP inicia ataque", p.estado == Personagem.Estado.ATACANDO)

	var sem := _sem_botoes()
	var passou_hit := false
	for i in range(60):
		p.atualizar(Vector2.ZERO, sem)
		if p.hitbox_ativa():
			passou_hit = true
	_checar("hitbox ativa durante o golpe", passou_hit)
	_checar("golpe termina e volta a parado", p.estado == Personagem.Estado.PARADO)

	var g: Dictionary = per["golpes"][0]
	outro.estado = Personagem.Estado.PARADO
	_checar("golpe normal acerta alvo parado", outro.resultado_para(g) == "acerto")
	outro.estado = Personagem.Estado.CAIDO
	_checar("golpe normal não acerta caído", outro.resultado_para(g) == "nada")

func _testar_caixa_barra() -> void:
	print("Caixa e Barra")
	var hb := {"x": 30, "y": -100, "w": 40, "h": 30}
	var r: Rect2 = Caixa.rect_hitbox(hb, Vector2(100.0, 480.0), true)
	_checar("hitbox tem o tamanho do JSON", r.size == Vector2(40.0, 30.0))
	_checar("hitbox olhando para a direita", r.position == Vector2(130.0, 380.0))
	_checar("colisão simples", Caixa.colidem(Rect2(0, 0, 10, 10), Rect2(5, 5, 10, 10)))
	_checar("encostando não colide", not Caixa.colidem(Rect2(0, 0, 10, 10), Rect2(10, 0, 10, 10)))

	var b = Barra.new()
	_checar("barra começa sem estoque", b.estoques_disponiveis() == 0)
	b.ganhar(100.0)
	_checar("ganho sai 20% mais rápido (100 vira 120)", absf(float(b.valor) - 120.0) < 0.001)
	_checar("120 já é 1 estoque", b.estoques_disponiveis() == 1)
	b.ganhar(1000.0)
	_checar("barra enche em 500 (5 estoques)", absf(float(b.valor) - 500.0) < 0.001)
	_checar("5 estoques quando cheia", b.estoques_disponiveis() == 5)
	_checar("gastar meia barra com barra cheia", b.gastar(Barra.MEIA_BARRA) and absf(float(b.valor) - 450.0) < 0.001)
	_checar("gastar sem energia é recusado", not b.gastar(9999.0))

func _testar_eventos() -> void:
	print("Eventos de som")
	_checar("evento válido", Eventos.valido("voz_dano_leve"))
	_checar("evento inválido recusado", not Eventos.valido("xyz"))

func _novo_par() -> Array:
	var r: Dictionary = Formato.ler(FIXTURE)
	var per: Dictionary = r["personagem"]
	var a = Personagem.new()
	var b = Personagem.new()
	a.oponente = b
	b.oponente = a
	a.definir_golpes(per["golpes"])
	b.definir_golpes(per["golpes"])
	a.resetar(200.0, true)
	b.resetar(240.0, false)
	return [a, b]

func _testar_combate() -> void:
	print("Combate")
	var g: Dictionary = Formato.golpe_base("LP")
	var par: Array = _novo_par()
	var d = par[1]
	var sem := _sem_botoes()

	# Defesa normal (segurando trás desde antes) não é parry e gasta a barra.
	var atras := Vector2(1.0, 0.0)
	for i in range(30):
		d.atualizar(atras, sem)
	_checar("segurar trás vira defesa normal", d.resultado_para(g) == "bloqueio")
	var antes: float = d.guarda
	d.receber_bloqueio(g)
	_checar("defender gasta a barra de defesa", d.guarda < antes)

	# Just defense: apertar trás no instante do golpe.
	par = _novo_par()
	d = par[1]
	for i in range(10):
		d.atualizar(Vector2.ZERO, sem)
	d.atualizar(atras, sem)
	_checar("apertar trás agora abre a janela de parry", d.resultado_para(g) == "parry")
	var g_antes: float = d.guarda
	var vida_antes: float = d.vida
	d.receber_parry(g)
	_checar("parry não gasta barra", d.guarda == g_antes)
	_checar("parry não tira vida", d.vida == vida_antes)
	_checar("parry entra no estado PARRY", d.estado == Personagem.Estado.PARRY)

	# Janela fecha depois de poucos frames.
	par = _novo_par()
	d = par[1]
	d.atualizar(atras, sem)
	for i in range(Personagem.JANELA_PARRY + 2):
		d.atualizar(atras, sem)
	_checar("depois da janela vira defesa normal", d.resultado_para(g) == "bloqueio")

	# Guarda quebra depois de vários golpes e a barra recupera.
	par = _novo_par()
	d = par[1]
	for i in range(40):
		d.atualizar(atras, sem)
	var n: int = 0
	while d.estado != Personagem.Estado.GUARDA_QUEBRADA and n < 50:
		d.estado = Personagem.Estado.PARADO
		d.receber_bloqueio(g)
		n += 1
	_checar("guarda quebra com golpes defendidos", d.estado == Personagem.Estado.GUARDA_QUEBRADA)
	_checar("guarda quebrada leva alguns golpes", n > 2)
	d.atualizar(Vector2.ZERO, sem)
	_checar("guarda quebrada não defende", d.resultado_para(g) == "acerto")
	for i in range(Personagem.GUARDA_QUEBRADA_FRAMES + 2):
		d.atualizar(Vector2.ZERO, sem)
	_checar("barra recupera na guarda quebrada", d.guarda >= Personagem.GUARDA_MAX - 0.01)
	_checar("volta ao normal depois", d.estado == Personagem.Estado.PARADO)

	# Regeneração lenta só depois de 1 segundo sem defender.
	par = _novo_par()
	d = par[1]
	d.guarda = 50.0
	d.frames_sem_guarda = 0
	for i in range(Personagem.GUARDA_REGEN_ESPERA):
		d.atualizar(Vector2.ZERO, sem)
	_checar("não regenera antes de 1 s", d.guarda == 50.0)
	for i in range(30):
		d.atualizar(Vector2.ZERO, sem)
	_checar("regenera devagar depois de 1 s", d.guarda > 50.0 and d.guarda < Personagem.GUARDA_MAX)

	# Esquiva: sem custo, para frente por padrão, para trás com o direcional trás.
	par = _novo_par()
	var a = par[0]
	var x0: float = a.pos.x
	var esq := _sem_botoes()
	esq["ESQ"] = true
	a.atualizar(Vector2.ZERO, esq)
	_checar("esquiva não gasta barra", a.barra.valor == 0.0)
	for i in range(Personagem.ESQUIVA_FRAMES):
		a.atualizar(Vector2.ZERO, sem)
	_checar("esquiva neutra vai para frente", a.pos.x > x0 + 100.0)
	par = _novo_par()
	a = par[0]
	a.pos.x = 400.0
	# P1 olha para a esquerda (oponente em 240): "trás" é o eixo X positivo.
	a.atualizar(Vector2(1.0, 0.0), esq)
	for i in range(Personagem.ESQUIVA_FRAMES):
		a.atualizar(Vector2(1.0, 0.0), sem)
	_checar("esquiva com trás vai para trás", a.pos.x > 400.0 + 100.0)

	# Dano: golpes fortes causam 30% menos.
	var fraco: Dictionary = Formato.golpe_base("LP")
	var forte: Dictionary = Formato.golpe_base("HP")
	_checar("golpe fraco mantém o dano", absf(Personagem.dano_do_golpe(fraco) - float(fraco["dano"])) < 0.001)
	_checar("golpe forte tem 30% menos dano", absf(Personagem.dano_do_golpe(forte) - float(forte["dano"]) * 0.7) < 0.001)

	# Reação de acerto pela altura.
	par = _novo_par()
	d = par[1]
	d.receber_acerto(Formato.golpe_base("LK"), 10.0)
	_checar("chute baixo gera reação baixa", d.slot_animacao() == "golpeado_baixo")

	# BO e migração de CD.
	var antigo: Dictionary = Formato.normalizar_golpe({"botao": "CD"})
	_checar("botão CD antigo vira BO", str(antigo["botao"]) == "BO")
	_checar("golpes fixos existem", Formato.golpe_base("BO")["base"] == true and Formato.golpe_base("BO")["blowoff"] == true)

func _testar_tempo_sprites() -> void:
	print("Sprites e frames")
	var g: Dictionary = Formato.golpe_base("LP") # 5 + 3 + 8 = 16 frames
	g["frames"] = ["a.png", "b.png", "c.png", "d.png"]
	var c: Array = Formato.cronograma(g)
	_checar("um item por sprite", c.size() == 4)
	_checar("começa no frame 0", int(c[0]["de"]) == 0)
	_checar("termina no total do golpe", int(c[3]["ate"]) == 16)
	var soma: int = 0
	for it in c:
		soma += int(it["ate"]) - int(it["de"])
	_checar("sprites cobrem todos os frames", soma == 16)
	_checar("sprite no frame 0 é o primeiro", Formato.indice_no_tempo(g, 0) == 0)
	_checar("sprite no último frame é o último", Formato.indice_no_tempo(g, 15) == 3)
	g["sprite_impacto"] = 1
	var c2: Array = Formato.cronograma(g)
	_checar("sprite de impacto cobre o active", int(c2[1]["de"]) == 5 and int(c2[1]["ate"]) == 8)
	_checar("com impacto ainda cobre tudo", int(c2[3]["ate"]) == 16)
	g["frames"] = []
	_checar("sem sprites não há cronograma", Formato.cronograma(g).is_empty())
	_checar("ciclo de 2 sprites alterna", Formato.indice_ciclo(2, 0) == 0 and Formato.indice_ciclo(2, Formato.FRAMES_POR_SPRITE_CICLO) == 1)
	var r: Dictionary = Formato.normalizar({"formato": 1, "nome": "Velho", "golpes": [{"botao": "CD", "nome": "x"}]})
	_checar("personagem antigo migra", bool(r["ok"]) and str(r["personagem"]["golpes"][0]["botao"]) == "BO")
	_checar("personagem tem slots de sprite", (r["personagem"]["sprites"] as Dictionary).has("parry"))
