extends RefCounted

# Barra de especial. Não desenha nada.
# Um estoque = 100. A barra enche até 5 estoques (500).
# Todo ganho sai 20% mais rápido (ganho x 1,2). O custo no JSON não muda.
# Meia barra (50) é o custo do contra-ataque (Guard Cancel).
# A marca do meio na tela é só visual.

const ESTOQUE: float = 100.0
const ESTOQUES_MAX: int = 5
const MULTIPLICADOR_GANHO: float = 1.2
const MEIA_BARRA: float = 50.0

var valor: float = 0.0
var maximo: float = ESTOQUE * ESTOQUES_MAX


func _init(p_maximo: float = ESTOQUE * ESTOQUES_MAX) -> void:
	maximo = p_maximo


func ganhar(q: float) -> void:
	valor = minf(maximo, valor + q * MULTIPLICADOR_GANHO)


func gastar(q: float) -> bool:
	if valor < q:
		return false
	valor -= q
	return true


func proporcao() -> float:
	return valor / maximo


# Vai de 0 a 5. Na tela, 5 aparece como "MAX".
func estoques_disponiveis() -> int:
	return mini(ESTOQUES_MAX, int(floor(valor / ESTOQUE)))