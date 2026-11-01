extends SceneTree

const Personagem = preload("res://Personagem.gd")

var falhas := 0
var testes := 0
var main = null
var quadros := 0
var feito := false

func check(cond: bool, msg: String) -> void:
	testes += 1
	if not cond:
		falhas += 1
		print("FALHOU: " + msg)

func _initialize() -> void:
	var cena = load("res://Main.tscn")
	check(cena != null, "Main.tscn deve carregar")
	if cena == null:
		return
	main = cena.instantiate()
	root.add_child(main)
	testar_combate()
	testar_repeticao()
	testar_editor()
	testar_json()

func _process(_delta: float) -> bool:
	if feito:
		return false
	quadros += 1
	if main == null or quadros >= 60:
		feito = true
		_finalizar()
	return false

func _finalizar() -> void:
	print("Testes do Main: %d | Falhas: %d" % [testes, falhas])
	quit(1 if falhas > 0 else 0)

func testar_combate() -> void:
	var p1 = main.p1
	var p2 = main.p2
	p1.resetar(300.0, true)
	p2.resetar(360.0, false)
	p1.oponente = p2
	p2.oponente = p1
	var vida_antes: float = p2.vida
	var ap := {"LP": true, "LK": false, "HP": false, "HK": false, "CD": false, "ROLL": false}
	var vazio := {"LP": false, "LK": false, "HP": false, "HK": false, "CD": false, "ROLL": false}
	p1.atualizar(Vector2.ZERO, ap)
	check(p1.estado == Personagem.Estado.ATACANDO, "LP deve iniciar um golpe")
	for i in range(12):
		p1.atualizar(Vector2.ZERO, vazio)
		p2.atualizar(Vector2.ZERO, vazio)
		main._resolver_combate(p1, p2)
	check(p2.vida < vida_antes, "golpe deve acertar o P2 parado")

func testar_repeticao() -> void:
	var p1 = main.p1
	var p2 = main.p2
	p1.resetar(300.0, true)
	p2.resetar(900.0, false)
	p1.oponente = p2
	p2.oponente = p1
	main.mask1 = main._mascara_vazia()
	var segurando := {"LP": true, "LK": false, "HP": false, "HK": false, "CD": false, "ROLL": false}
	var inicios := 0
	for i in range(80):
		main._passo_jogador(p1, Vector2.ZERO, segurando, main.mask1)
		if p1.estado == Personagem.Estado.ATACANDO and p1.tempo == 0:
			inicios += 1
	check(inicios == 1, "segurar LP deve gerar um golpe, não vários (resultado: %d)" % inicios)

func testar_editor() -> void:
	var n0: int = main.p1.golpes.size()
	main._abrir_editor()
	check(main.editando, "abrir editor deve ligar editando")
	main.ignorar_mouse = 0
	main._clique_editor(Vector2(50.0, 386.0))
	check(main.ed_golpes.size() == n0 + 1, "clique em NOVO deve adicionar um golpe")
	main._apaga()
	check(main.ed_golpes.size() == n0, "APAGA deve remover o golpe selecionado")
	var st0: int = main.ed_golpes[main.ed_sel]["startup"]
	main._mudar_campo(5, 1)
	check(int(main.ed_golpes[main.ed_sel]["startup"]) == st0 + 1, "campo startup deve subir 1")
	main._fechar_editor()
	check(not main.editando, "fechar deve desligar editando")
	check(main.p1.golpes.size() == n0, "fechar deve aplicar a lista editada")

func testar_json() -> void:
	var entrada_ok = JSON.parse_string('{"nome":"Teste","golpes":[{"nome":"a","botao":"LP","hitbox":{"x":1,"y":-10,"w":5,"h":5}}]}')
	var r: Dictionary = main._validar_personagem(entrada_ok)
	check(r["ok"], "JSON válido deve passar")
	check(r["golpes"].size() == 1, "deve ler 1 golpe")
	var ruim = JSON.parse_string('{"nome":"X","golpes":[{"botao":"ZZ"}]}')
	var r2: Dictionary = main._validar_personagem(ruim)
	check(not r2["ok"], "botão inválido deve ser recusado")
	main._salvar()
	var volta = JSON.parse_string(FileAccess.get_file_as_string("user://personagem.json"))
	check(volta is Dictionary and volta.has("golpes"), "arquivo salvo deve ler de volta")