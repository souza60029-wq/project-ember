extends RefCounted

const ESTOQUE: float = 100.0
const ESTOQUES_MAX: int = 3

var valor: float = 0.0
var maximo: float = 300.0

func _init(p_maximo: float = 300.0) -> void:
	maximo = p_maximo

func ganhar(q: float) -> void:
	valor = minf(maximo, valor + q)

func gastar(q: float) -> bool:
	if valor < q:
		return false
	valor -= q
	return true

func proporcao() -> float:
	return valor / maximo

func estoques_disponiveis() -> int:
	return mini(ESTOQUES_MAX, int(floor(valor / ESTOQUE)))