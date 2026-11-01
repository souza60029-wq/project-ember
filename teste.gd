extends SceneTree

const Caixa = preload("res://Caixa.gd")
const Barra = preload("res://Barra.gd")
const Personagem = preload("res://Personagem.gd")

var falhas := 0
var testes := 0

func check(cond: bool, msg: String) -> void:
	testes += 1
	if not cond:
		falhas += 1
		print("FALHOU: " + msg)

func _init() -> void:
	test_caixa()
	test_barra()
	test_golpes()
	test_json()
	print("Testes: %d | Falhas: %d" % [testes, falhas])
	quit(1 if falhas > 0 else 0)

func test_caixa() -> void:
	var a = Rect2(0, 0, 50, 50)
	var b = Rect2(20, 20, 50, 50)
	var c = Rect2(200, 200, 50, 50)
	check(Caixa.colidem(a, b), "caixas sobrepostas devem colidir")
	check(not Caixa.colidem(a, c), "caixas distantes não devem colidir")
	var hb = {"x": 10, "y": -100, "w": 40, "h": 30}
	var r = Caixa.rect_hitbox(hb, Vector2(100, 480), true)
	check(r.size == Vector2(40, 30), "tamanho da hitbox deve vir de w e h")

func test_barra() -> void:
	var b = Barra.new()
	check(b.valor == 0.0, "barra começa vazia")
	b.ganhar(50.0)
	check(b.valor == 50.0, "ganhar soma na barra")
	check(not b.gastar(60.0), "gastar mais do que tem deve falhar")
	check(b.valor == 50.0, "gasto falho não altera a barra")
	check(b.gastar(30.0), "gastar valor disponível deve funcionar")
	check(b.valor == 20.0, "gastar subtrai da barra")

func test_golpes() -> void:
	var golpes: Array = Personagem.golpes_padrao_ash()
	check(golpes.size() == 8, "Ash deve ter 8 golpes padrão")
	for g in golpes:
		check(g.has("nome") and g.has("botao"), "golpe sem nome ou botão")
		check(g.has("hitbox"), "golpe sem hitbox")
	var n: Dictionary = Personagem.normalizar_golpe(Personagem.golpe_padrao())
	check(n.has("startup") and n.has("active") and n.has("recovery"), "normalizar_golpe deve manter os frames")
	var p = Personagem.new()
	p.definir_golpes(golpes)
	check(p.golpes.size() == 8, "definir_golpes deve guardar a lista")

func test_json() -> void:
	var dados = {"nome": "Ash Crimson", "golpes": Personagem.golpes_padrao_ash()}
	var texto = JSON.stringify(dados)
	var volta = JSON.parse_string(texto)
	check(volta is Dictionary, "JSON deve voltar como dicionário")
	if volta is Dictionary:
		check(volta.get("nome", "") == "Ash Crimson", "nome deve sobreviver ao JSON")
		check(volta.get("golpes", []).size() == 8, "golpes devem sobreviver ao JSON")