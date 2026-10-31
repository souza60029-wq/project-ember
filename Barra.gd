extends RefCounted

var valor: float = 0.0
var maximo: float = 100.0

func ganhar(quantidade: float):
	valor = min(valor + quantidade, maximo * 3)
	print("Barra aumentou em %.1f. Total atual: %.1f" % [quantidade, valor])

func gastar(quantidade: float) -> bool:
	if valor >= quantidade:
		valor -= quantidade
		print("Gastou %.1f de barra. Restante: %.1f" % [quantidade, valor])
		return true
	else:
		print("Barra insuficiente! Precisa de %.1f, tem %.1f" % [quantidade, valor])
		return false
