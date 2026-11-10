extends RefCounted

# Operações sobre a lista de golpes de um personagem. Só mexe em dados, não em tela.
# Usado pelo editor e coberto por testes/teste_pacote.gd.

const Formato = preload("res://engine/formato/Formato.gd")


static func novo_personagem(nome: String, id: String) -> Dictionary:
	return {"formato": Formato.VERSAO, "id": id, "nome": nome, "magias": [], "golpes": []}


# Índice do golpe fixo de um botão, ou -1 se o personagem ainda não tem.
static func indice_base(p: Dictionary, botao: String) -> int:
	var golpes: Array = p["golpes"]
	for i in range(golpes.size()):
		var g: Dictionary = golpes[i]
		if bool(g["base"]) and str(g["botao"]) == botao:
			return i
	return -1


# Adiciona o golpe fixo (LP, LK, HP, HK, BO). Se já existe, devolve o índice dele.
# Devolve -1 se não coube (limite de golpes).
static func adicionar_base(p: Dictionary, botao: String) -> int:
	var ja: int = indice_base(p, botao)
	if ja >= 0:
		return ja
	var golpes: Array = p["golpes"]
	if golpes.size() >= Formato.MAX_GOLPES:
		return -1
	golpes.append(Formato.golpe_base(botao))
	return golpes.size() - 1


# Golpe fixo só aceita trocar quadros, sprite de impacto e som. Devolve quais chaves valem.
static func chave_editavel(g: Dictionary, chave: String) -> bool:
	if not bool(g["base"]):
		return true
	return chave in ["frames", "sprite_impacto", "sons"]


static func inserir_golpe(p: Dictionary, posicao: int) -> bool:
	var golpes: Array = p["golpes"]
	if golpes.size() >= Formato.MAX_GOLPES:
		return false
	golpes.insert(clampi(posicao, 0, golpes.size()), Formato.padrao_golpe())
	return true


static func copiar_golpe(p: Dictionary, i: int) -> bool:
	var golpes: Array = p["golpes"]
	if not _valido(golpes, i) or golpes.size() >= Formato.MAX_GOLPES:
		return false
	var copia: Dictionary = (golpes[i] as Dictionary).duplicate(true)
	copia["base"] = false
	copia["nome"] = str(copia["nome"]) + " (cópia)"
	golpes.insert(i + 1, copia)
	return true


static func excluir_golpe(p: Dictionary, i: int) -> bool:
	var golpes: Array = p["golpes"]
	if not _valido(golpes, i):
		return false
	golpes.remove_at(i)
	return true


static func mover_golpe(p: Dictionary, i: int, direcao: int) -> bool:
	var golpes: Array = p["golpes"]
	var j := i + direcao
	if not _valido(golpes, i) or not _valido(golpes, j):
		return false
	var tmp = golpes[i]
	golpes[i] = golpes[j]
	golpes[j] = tmp
	return true


static func _valido(golpes: Array, i: int) -> bool:
	return i >= 0 and i < golpes.size()