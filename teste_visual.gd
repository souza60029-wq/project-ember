extends SceneTree

const Personagem = preload("res://Personagem.gd")
const ARQUIVO := "user://personagem.json"
const TECLAS := ["LP", "LK", "HP", "HK", "CD", "ROLL"]

var testes := 0
var falhas := 0

func check(cond: bool, msg: String) -> void:
	testes += 1
	if not cond:
		falhas += 1
		print("FALHOU: " + msg)

func _vazio() -> Dictionary:
	var d := {}
	for k in TECLAS:
		d[k] = false
	return d

func _com(teclas: Array) -> Dictionary:
	var d := _vazio()
	for k in teclas:
		d[k] = true
	return d

func _initialize() -> void:
	var cena: PackedScene = load("res://Main.tscn")
	var main = cena.instantiate()
	root.add_child(main)
	check(main.p1 != null and main.p2 != null, "personagens devem existir ao entrar na cena")
	if main.p1 != null and main.p2 != null:
		testar_combate(main)
		testar_repeticao(main)
		testar_editor(main)
		testar_json(main)
	root.remove_child(main)
	main.free()
	print("Testes do Main: %d | Falhas: %d" % [testes, falhas])
	quit(1 if falhas > 0 else 0)

func testar_combate(main) -> void:
	main._reiniciar_luta()
	var p1 = main.p1
	var p2 = main.p2
	p1.resetar(200.0, true)
	p2.resetar(240.0, false)
	var vida_ini: float = float(p2.vida)
	main._passo_jogador(p1, Vector2.ZERO, _com(["LP"]), main.mask1)
	check(p1.estado == Personagem.Estado.ATACANDO, "LP deve iniciar golpe")
	for i in range(12):
		main._passo_jogador(p1, Vector2.ZERO, _vazio(), main.mask1)
		main._resolver_combate(p1, p2)
	check(float(p2.vida) < vida_ini, "LP deve tirar vida do oponente parado na frente")

func testar_repeticao(main) -> void:
	main._reiniciar_luta()
	var p1 = main.p1
	var raw := _com(["LP"])
	var inicios := 0
	for i in range(80):
		var antes: int = p1.estado
		main._passo_jogador(p1, Vector2.ZERO, raw, main.mask1)
		if p1.estado == Personagem.Estado.ATACANDO and antes != Personagem.Estado.ATACANDO:
			inicios += 1
	check(inicios == 1, "segurar LP por 80 quadros deve gerar 1 golpe, gerou %d" % inicios)

func testar_editor(main) -> void:
	main._reiniciar_luta()
	main._abrir_editor()
	check(main.editando, "abrir editor deve ligar o modo editor")
	# Em teste não há quadros passando, então o bloqueio de clique precisa ser zerado.
	main.ignorar_mouse = 0
	var antes: int = main.ed_golpes.size()
	main._clique_editor(Vector2(49.0, 386.0))  # botão NOVO
	check(main.ed_golpes.size() == antes + 1, "NOVO deve adicionar um golpe")
	var sel: int = main.ed_sel
	var startup_antes: int = int(main.ed_golpes[sel]["startup"])
	main._mudar_campo(5, 1)  # índice 5 = startup
	check(int(main.ed_golpes[sel]["startup"]) == startup_antes + 1, "startup deve subir 1")
	main._fechar_editor()
	check(not main.editando, "fechar editor deve desligar o modo")

func testar_json(main) -> void:
	var bom := {"nome": "Teste", "golpes": [Personagem.golpe_padrao()]}
	var r: Dictionary = main._validar_personagem(bom)
	check(bool(r["ok"]), "JSON válido deve ser aceito")
	var ruim := {"nome": "X", "golpes": [{"botao": "ZZ"}]}
	var r2: Dictionary = main._validar_personagem(ruim)
	check(not bool(r2["ok"]), "botão ZZ deve ser recusado")
	main._salvar()
	check(FileAccess.file_exists(ARQUIVO), "_salvar deve criar o arquivo")
	var lido = JSON.parse_string(FileAccess.get_file_as_string(ARQUIVO))
	check(lido is Dictionary, "arquivo salvo deve ser JSON válido")
	if lido is Dictionary:
		check(lido.get("golpes", []).size() == main.p1.golpes.size(), "arquivo salvo deve ter os mesmos golpes")