extends RefCounted

# Valida e completa o personagem.json. Não depende de cena nem de nó.
# Campos que faltam recebem o padrão, então arquivos antigos continuam funcionando.

const VERSAO := 2
const BOTOES := ["LP", "LK", "HP", "HK", "BO"]
const MAX_QUADROS := 64
const ALTURA_PADRAO: int = 120

# Animações do personagem (cada uma é uma lista de arquivos de sprite).
# Os golpes têm os próprios quadros, dentro de cada golpe.
const SLOTS := [
	"parado", "andando", "pulando", "defendendo", "bloqueio", "parry",
	"guarda_quebrada", "esquiva", "golpeado_alto", "golpeado_medio",
	"golpeado_baixo", "rasteira", "caido", "levantando", "ko", "vitoria", "derrota",
]
const ROTULOS_SLOT := {
	"parado": "Parado", "andando": "Andando", "pulando": "Pulando",
	"defendendo": "Defendendo", "bloqueio": "Defendeu um golpe",
	"parry": "Just defense (parry)", "guarda_quebrada": "Guarda quebrada",
	"esquiva": "Esquiva", "golpeado_alto": "Apanhando (alto)",
	"golpeado_medio": "Apanhando (meio)", "golpeado_baixo": "Apanhando (baixo)",
	"rasteira": "Caindo de rasteira", "caido": "Caído", "levantando": "Levantando",
	"ko": "K.O.", "vitoria": "Vitória", "derrota": "Derrota",
}
# Animações que repetem em ciclo. As outras acompanham a duração do estado.
const SLOTS_EM_CICLO := ["parado", "andando", "pulando", "defendendo"]
const FRAMES_POR_SPRITE_CICLO: int = 8

# Golpes que todo personagem tem. Só os quadros e o som deles podem ser trocados.
const BASE := {
	"LP": {"nome": "Low Punch", "forca": 1, "startup": 5, "active": 3, "recovery": 8, "dano": 40,
		"blowoff": false, "hitbox": {"x": 30, "y": -100, "w": 40, "h": 30}},
	"LK": {"nome": "Low Kick", "forca": 1, "startup": 6, "active": 3, "recovery": 10, "dano": 40,
		"blowoff": false, "hitbox": {"x": 25, "y": -50, "w": 50, "h": 30}},
	"HP": {"nome": "High Punch", "forca": 2, "startup": 10, "active": 4, "recovery": 18, "dano": 90,
		"blowoff": false, "hitbox": {"x": 30, "y": -105, "w": 60, "h": 35}},
	"HK": {"nome": "High Kick", "forca": 3, "startup": 14, "active": 4, "recovery": 24, "dano": 110,
		"blowoff": false, "hitbox": {"x": 30, "y": -60, "w": 70, "h": 40}},
	"BO": {"nome": "Blow Off", "forca": 3, "startup": 12, "active": 4, "recovery": 26, "dano": 100,
		"blowoff": true, "hitbox": {"x": 20, "y": -100, "w": 70, "h": 60}},
}
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
		"base": false,
		"sprite_impacto": -1,
		"frames": [],
		"sons": {"uso": ""},
		"efeitos": {
			"acerto": {"frames": [], "som": ""},
			"bloqueio": {"frames": [], "som": ""}
		}
	}


# Golpe fixo de um botão (LP, LK, HP, HK ou BO).
static func golpe_base(botao: String) -> Dictionary:
	if not BASE.has(botao):
		return padrao_golpe()
	var g: Dictionary = padrao_golpe()
	var b: Dictionary = BASE[botao]
	for k in b.keys():
		g[k] = (b[k] as Dictionary).duplicate(true) if typeof(b[k]) == TYPE_DICTIONARY else b[k]
	g["botao"] = botao
	g["base"] = true
	return normalizar_golpe(g)


static func normalizar_golpe(g_in: Dictionary) -> Dictionary:
	var g: Dictionary = g_in
	if str(g.get("botao", "")) == "CD":
		g = g_in.duplicate()
		g["botao"] = "BO"
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
	r["base"] = bool(r["base"])
	r["sprite_impacto"] = clampi(int(r["sprite_impacto"]), -1, MAX_QUADROS)

	var hb = r["hitbox"] if typeof(r["hitbox"]) == TYPE_DICTIONARY else {}
	r["hitbox"] = {
		"x": clampi(int(hb.get("x", 30)), -200, 200),
		"y": clampi(int(hb.get("y", -100)), -200, 0),
		"w": clampi(int(hb.get("w", 40)), 1, 300),
		"h": clampi(int(hb.get("h", 30)), 1, 300)
	}

	r["frames"] = _lista_texto(r["frames"]).slice(0, MAX_QUADROS)

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

	if int(dados.get("formato", 1)) < 2:
		_marcar_base(golpes)

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
			"altura_px": clampi(int(dados.get("altura_px", ALTURA_PADRAO)), 40, 600),
			"arte_selecao": str(dados.get("arte_selecao", "")),
			"arte_card": str(dados.get("arte_card", "")),
			"sprites": _sprites(dados.get("sprites", {})),
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
		texto += " (BO)"
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


# ---------- Quadros e tempo (60 FPS) ----------

static func total_frames(g: Dictionary) -> int:
	return int(g["startup"]) + int(g["active"]) + int(g["recovery"])


# Divide [de, ate) em "quantos" partes iguais. Devolve [{"de", "ate"}].
static func _repartir(de: int, ate: int, quantos: int) -> Array:
	var r: Array = []
	var tam: int = maxi(0, ate - de)
	for i in range(quantos):
		r.append({"de": de + (tam * i) / quantos, "ate": de + (tam * (i + 1)) / quantos})
	return r


# Automatiza o tempo de cada sprite de um golpe dentro dos frames do golpe.
# Sem sprite de impacto: todos os sprites dividem o golpe por igual.
# Com sprite de impacto: os de antes dividem o startup, o de impacto cobre o active,
# e os de depois dividem o recovery. Devolve um item {"de", "ate"} por sprite (frames [de, ate)).
static func cronograma(g: Dictionary) -> Array:
	var n: int = (g["frames"] as Array).size()
	var total: int = total_frames(g)
	if n == 0 or total <= 0:
		return []
	var imp: int = int(g.get("sprite_impacto", -1))
	if imp < 0 or imp >= n:
		return _repartir(0, total, n)
	var st: int = int(g["startup"])
	var fim_ativo: int = st + int(g["active"])
	var r: Array = []
	r.append_array(_repartir(0, st, imp))
	var de_imp: int = st if imp > 0 else 0
	var ate_imp: int = fim_ativo if imp < n - 1 else total
	r.append({"de": de_imp, "ate": ate_imp})
	r.append_array(_repartir(fim_ativo, total, n - 1 - imp))
	return r


# Qual sprite aparece no frame "t" do golpe.
static func indice_no_tempo(g: Dictionary, t: int) -> int:
	var c: Array = cronograma(g)
	if c.is_empty():
		return -1
	for i in range(c.size()):
		var it: Dictionary = c[i]
		if t >= int(it["de"]) and t < int(it["ate"]):
			return i
	return c.size() - 1 if t > 0 else 0


# Animação que acompanha uma duração (ex.: guarda quebrada, levantar).
static func indice_proporcional(n: int, t: int, duracao: int) -> int:
	if n <= 0:
		return -1
	return clampi((t * n) / maxi(1, duracao), 0, n - 1)


# Animação em ciclo (parado, andando).
static func indice_ciclo(n: int, relogio: int) -> int:
	if n <= 0:
		return -1
	return (relogio / FRAMES_POR_SPRITE_CICLO) % n


# Marca como "base" o primeiro golpe de cada botão que é o golpe simples (sem carga, sem custo).
static func _marcar_base(golpes: Array) -> void:
	var vistos := {}
	for g in golpes:
		var d: Dictionary = g
		d["base"] = false
		if vistos.has(d["botao"]):
			continue
		if str(d["carga"]) == "" and int(d["custo"]) == 0 and not bool(d["so_ar"]):
			d["base"] = true
			vistos[d["botao"]] = true


static func _sprites(v) -> Dictionary:
	var saida := {}
	var d: Dictionary = v if typeof(v) == TYPE_DICTIONARY else {}
	for slot in SLOTS:
		saida[slot] = _lista_texto(d.get(slot, [])).slice(0, MAX_QUADROS)
	return saida


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