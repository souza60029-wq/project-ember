extends RefCounted

# FERRAMENTA DE DEBUG (pode ser removida): guarda a posição e o tamanho das camadas do menu.
# Salva em user://debug/ (no iPhone: Arquivos > No meu iPhone > Ember > debug):
#   layout_menu.json  usado pelo app para aplicar na tela inicial
#   layout_menu.txt   texto para você me mandar (tem os valores exatos e um bloco pronto de código)
#
# Para tirar da versão final: apague a pasta engine/debug/ inteira. O app continua funcionando
# (o Menu só usa isto se o arquivo existir). Depois cole os valores em Menu.gd, na constante LAYOUT_FIXO.

const PASTA := "user://debug/"
const ARQ_JSON := "user://debug/layout_menu.json"
const ARQ_TXT := "user://debug/layout_menu.txt"


# Layout salvo: {"nome_da_camada": {"x": float, "y": float, "esc": float}}
static func ler() -> Dictionary:
	var r := {}
	if not FileAccess.file_exists(ARQ_JSON):
		return r
	var f := FileAccess.open(ARQ_JSON, FileAccess.READ)
	if f == null:
		return r
	var d: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(d) != TYPE_DICTIONARY:
		return r
	for k in (d as Dictionary).keys():
		var v: Variant = d[k]
		if typeof(v) == TYPE_DICTIONARY:
			r[str(k)] = {"x": float(v.get("x", 0.0)), "y": float(v.get("y", 0.0)), "esc": float(v.get("esc", 1.0))}
	return r


# Ordem das camadas salva (de trás para frente). Vazia se não houver.
static func ler_ordem() -> Array:
	var r: Array = []
	if not FileAccess.file_exists(ARQ_JSON):
		return r
	var f := FileAccess.open(ARQ_JSON, FileAccess.READ)
	if f == null:
		return r
	var d: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(d) == TYPE_DICTIONARY and typeof((d as Dictionary).get("_ordem", null)) == TYPE_ARRAY:
		for n in (d as Dictionary)["_ordem"]:
			r.append(str(n))
	return r


# Texto legível + bloco de código. retangulos: {"nome": Rect2} (onde cada camada ficou na tela de 960x540).
static func texto(layout: Dictionary, retangulos: Dictionary, ordem: Array = []) -> String:
	var linhas: PackedStringArray = []
	linhas.append("EMBER - layout das camadas do menu (tela de referencia 960 x 540)")
	linhas.append("x e y = deslocamento em pixels a partir da posicao padrao; esc = multiplicador de tamanho")
	if not ordem.is_empty():
		linhas.append("ordem das camadas (de tras para frente): " + " > ".join(PackedStringArray(ordem)))
	linhas.append("")
	var nomes: Array = layout.keys()
	for n in retangulos.keys():
		if not nomes.has(n):
			nomes.append(n)
	nomes.sort()
	for n in nomes:
		var a: Dictionary = layout.get(n, {"x": 0.0, "y": 0.0, "esc": 1.0})
		var linha: String = "%s: x=%.1f y=%.1f esc=%.3f" % [str(n), float(a["x"]), float(a["y"]), float(a["esc"])]
		if retangulos.has(n):
			var r: Rect2 = retangulos[n]
			linha += "  | na tela: x=%.1f y=%.1f largura=%.1f altura=%.1f" % [r.position.x, r.position.y, r.size.x, r.size.y]
		linhas.append(linha)
	linhas.append("")
	linhas.append("# Cole em Menu.gd:")
	linhas.append("const LAYOUT_FIXO := {")
	for n in nomes:
		var a2: Dictionary = layout.get(n, {})
		if a2.is_empty():
			continue
		linhas.append("\t\"%s\": {\"x\": %.1f, \"y\": %.1f, \"esc\": %.3f}," % [str(n), float(a2["x"]), float(a2["y"]), float(a2["esc"])])
	linhas.append("}")
	return "\n".join(linhas)


# Devolve "" se salvou, ou a mensagem de erro.
static func salvar(layout: Dictionary, retangulos: Dictionary, ordem: Array = []) -> String:
	DirAccess.make_dir_recursive_absolute(PASTA)
	var f := FileAccess.open(ARQ_JSON, FileAccess.WRITE)
	if f == null:
		return "Nao consegui gravar em " + ARQ_JSON
	var dados: Dictionary = layout.duplicate(true)
	dados["_ordem"] = ordem
	f.store_string(JSON.stringify(dados, "\t"))
	f.close()
	var t := FileAccess.open(ARQ_TXT, FileAccess.WRITE)
	if t == null:
		return "Nao consegui gravar em " + ARQ_TXT
	t.store_string(texto(layout, retangulos, ordem))
	t.close()
	return ""


static func apagar() -> void:
	if FileAccess.file_exists(ARQ_JSON):
		DirAccess.remove_absolute(ARQ_JSON)
	if FileAccess.file_exists(ARQ_TXT):
		DirAccess.remove_absolute(ARQ_TXT)
