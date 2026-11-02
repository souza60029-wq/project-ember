extends RefCounted

# Valida e completa o personagem.json. Não depende de cena nem de nó.
# Campos que faltam recebem o padrão, então arquivos antigos continuam funcionando.

const VERSAO := 1
const BOTOES := ["LP", "LK", "HP", "HK", "CD"]
const CARGAS := ["", "tras", "baixo"]
const MAX_GOLPES := 40


static func padrao_golpe() -> Dictionary:
	return {
		"nome": "Golpe novo",
		"botao": "LP",
		"carga": "",
		"carga_seg": 0.5,
		"forca": 1,
		"startup": 6,
		"active": 3,
		"recovery": 10,
		"dano": 50,
		"custo": 0,
		"energia_ganha": 0,
		"antichao": false,
		"blowoff": false,
		"so_ar": false,
		"hitbox": {"x": 30, "y": -100, "w": 40, "h": 30},
		"frames": [],
		"sons": {"uso": ""},
		"efeitos": {
			"acerto": {"frames": [], "som": ""},
			"bloqueio": {"frames": [], "som": ""}
		}
	}


static func normalizar_golpe(g: Dictionary) -> Dictionary:
	var r := padrao_golpe()
	for chave in r.keys():
		if g.has(chave):
			r[chave] = g[chave]

	r["nome"] = str(r["nome"]).strip_edges().left(40)
	if r["nome"] == "":
		r["nome"] = "Sem nome"
	if not BOTOES.has(r["botao"]):
		r["botao"] = "LP"
	if not CARGAS.has(r["carga"]):
		r["carga"] = ""
	r["carga_seg"] = clampf(float(r["carga_seg"]), 0.0, 2.0)
	r["forca"] = clampi(int(r["forca"]), 1, 3)
	r["startup"] = clampi(int(r["startup"]), 0, 60)
	r["active"] = clampi(int(r["active"]), 1, 60)
	r["recovery"] = clampi(int(r["recovery"]), 0, 90)
	r["dano"] = clampi(int(r["dano"]), 0, 999)
	r["custo"] = clampi(int(r["custo"]), 0, 300)
	r["energia_ganha"] = clampi(int(r["energia_ganha"]), 0, 300)
	r["antichao"] = bool(r["antichao"])
	r["blowoff"] = bool(r["blowoff"])
	r["so_ar"] = bool(r["so_ar"])

	var hb = r["hitbox"] if typeof(r["hitbox"]) == TYPE_DICTIONARY else {}
	r["hitbox"] = {
		"x": clampi(int(hb.get("x", 30)), -200, 200),
		"y": clampi(int(hb.get("y", -100)), -200, 0),
		"w": clampi(int(hb.get("w", 40)), 1, 300),
		"h": clampi(int(hb.get("h", 30)), 1, 300)
	}

	r["frames"] = _lista_texto(r["frames"])

	var sons = r["sons"] if typeof(r["sons"]) == TYPE_DICTIONARY else {}
	r["sons"] = {"uso": str(sons.get("uso", ""))}

	var efeitos = r["efeitos"] if typeof(r["efeitos"]) == TYPE_DICTIONARY else {}
	r["efeitos"] = {
		"acerto": _efeito(efeitos.get("acerto", {})),
		"bloqueio": _efeito(efeitos.get("bloqueio", {}))
	}
	return r


# Valida um personagem já lido do JSON. Devolve {ok, erro, personagem}.
static func normalizar(dados) -> Dictionary:
	if typeof(dados) != TYPE_DICTIONARY:
		return _erro("O arquivo não é um objeto JSON.")
	if int(dados.get("formato", 1)) > VERSAO:
		return _erro("Este personagem é de uma versão mais nova da engine.")
	if typeof(dados.get("golpes", null)) != TYPE_ARRAY:
		return _erro("Falta a lista 'golpes'.")

	var lista: Array = dados["golpes"]
	if lista.size() > MAX_GOLPES:
		return _erro("Máximo de %d golpes." % MAX_GOLPES)

	var golpes := []
	for g in lista:
		if typeof(g) != TYPE_DICTIONARY:
			return _erro("Há um golpe que não é objeto.")
		golpes.append(normalizar_golpe(g))

	var nome := str(dados.get("nome", "Sem nome")).strip_edges().left(40)
	if nome == "":
		nome = "Sem nome"
	var magias = dados.get("magias", [])
	if typeof(magias) != TYPE_ARRAY:
		magias = []

	return {
		"ok": true,
		"erro": "",
		"personagem": {
			"formato": VERSAO,
			"id": sanitizar_id(str(dados.get("id", nome))),
			"nome": nome,
			"magias": magias,
			"golpes": golpes
		}
	}


static func ler(caminho: String) -> Dictionary:
	if not FileAccess.file_exists(caminho):
		return _erro("Arquivo não encontrado.")
	return ler_texto(FileAccess.get_file_as_string(caminho))


static func ler_texto(texto: String) -> Dictionary:
	var dados = JSON.parse_string(texto)
	if dados == null:
		return _erro("JSON inválido.")
	return normalizar(dados)


static func serializar(personagem: Dictionary) -> String:
	return JSON.stringify(personagem, "  ")


# Lista pronta para mostrar no menu e no editor.
static func moveset(personagem: Dictionary) -> Array:
	var lista := []
	for g in personagem["golpes"]:
		lista.append({
			"nome": g["nome"],
			"comando": comando_texto(g),
			"dano": g["dano"],
			"startup": g["startup"],
			"active": g["active"],
			"recovery": g["recovery"],
			"custo": g["custo"],
			"forca": g["forca"]
		})
	return lista


# Texto de comando para exibição. Só ASCII, para a fonte padrão mostrar certo.
static func comando_texto(g: Dictionary) -> String:
	var texto: String = g["botao"]
	if g["carga"] == "tras":
		texto = "Carga tras + " + texto
	elif g["carga"] == "baixo":
		texto = "Carga baixo + " + texto
	if g["so_ar"]:
		texto += " (no ar)"
	if g["blowoff"]:
		texto += " (Blow Off)"
	return texto


static func sanitizar_id(texto: String) -> String:
	var base := texto.strip_edges().to_lower().replace(" ", "_")
	var saida := ""
	for c in base:
		if (c >= "a" and c <= "z") or (c >= "0" and c <= "9") or c == "_":
			saida += c
	if saida == "":
		saida = "personagem"
	return saida.left(40)


static func _efeito(e) -> Dictionary:
	if typeof(e) != TYPE_DICTIONARY:
		return {"frames": [], "som": ""}
	return {"frames": _lista_texto(e.get("frames", [])), "som": str(e.get("som", ""))}


static func _lista_texto(v) -> Array:
	var saida := []
	if typeof(v) != TYPE_ARRAY:
		return saida
	for item in v:
		saida.append(str(item))
	return saida


static func _erro(msg: String) -> Dictionary:
	return {"ok": false, "erro": msg, "personagem": {}}