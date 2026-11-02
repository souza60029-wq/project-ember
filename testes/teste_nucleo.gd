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
	return {"LP": false, "LK": false, "HP": false, "HK": false, "CD": false, "ROLL": false}

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