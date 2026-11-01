extends SceneTree

func _init() -> void:
	print("=== TESTE VISUAL: carregando Main.tscn ===")
	var cena = load("res://Main.tscn")
	if cena == null:
		print("ERRO: nao foi possivel carregar Main.tscn")
		quit(1)
		return
	var main = cena.instantiate()
	get_root().add_child(main)
	if main.p1 == null or main.p2 == null:
		print("ERRO: lutadores nao criados em _ready")
		quit(1)
		return
	print("Lutadores: ", main.p1.nome, " vs ", main.p2.nome)
	print("SUCESSO TOTAL - CENA VISUAL VALIDADA!")
	quit(0)