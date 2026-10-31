extends SceneTree

func _init():
	print("=== TESTE VISUAL: Carregando cena principal ===")
	var cena = load("res://Main.tscn")
	if cena == null:
		print("ERRO: nao foi possivel carregar Main.tscn")
		quit(1)
		return
	var instancia = cena.instantiate()
	if instancia == null:
		print("ERRO: nao foi possivel instanciar a cena")
		quit(1)
		return
	print("Cena carregada e instanciada com sucesso!")
	print("Nome do no raiz: ", instancia.name)
	var chao = instancia.get_node_or_null("Chao")
	var p1 = instancia.get_node_or_null("Personagem1")
	var p2 = instancia.get_node_or_null("Personagem2")
	if chao and p1 and p2:
		print("Todos os nos visuais encontrados (Chao, Personagem1, Personagem2)")
		print("SUCESSO TOTAL - CENA VISUAL VALIDADA!")
	else:
		print("ERRO: algum no esperado nao foi encontrado")
	quit()