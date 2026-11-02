extends RefCounted

# Backup de personagem (BEP1). Um único texto com o personagem inteiro:
# JSON + todos os arquivos de mídia, cada conteúdo guardado uma só vez (SHA-256),
# comprimido com GZIP e convertido para Base64 uma única vez no fim.
# Conteúdo interno: [u32 tam_cabeçalho][cabeçalho JSON][dados dos arquivos]
# Texto final: "BEP1:" + base64([u32 tam_original] + gzip(conteúdo interno))

const Formato = preload("res://engine/formato/Formato.gd")

const PREFIXO := "BEP1:"
const EXTENSOES_MIDIA := ["png", "jpg", "jpeg", "webp", "ogg", "mp3", "wav"]
const AVISO_TAMANHO := 3000000
const RAIZES := ["res://personagens/", "user://personagens/"]


# personagem: dicionário do personagem como está no editor.
# pasta_midia: pasta onde estão os arquivos (ex.: "user://personagens/ash_crimson/").
static func exportar(personagem: Dictionary, pasta_midia: String) -> Dictionary:
	var norm: Dictionary = Formato.normalizar(personagem)
	if not norm["ok"]:
		return {"ok": false, "erro": str(norm["erro"]), "texto": "", "aviso": ""}
	var dados: Dictionary = norm["personagem"]

	var caminhos: Array[String] = []
	_listar(pasta_midia, "", caminhos)

	var blobs: Array = []
	var vistos := {}
	var dados_blobs := PackedByteArray()
	var arquivos := {}
	for rel in caminhos:
		var bytes := FileAccess.get_file_as_bytes(pasta_midia + rel)
		if bytes.is_empty():
			continue
		var h := _sha256(bytes)
		arquivos[rel] = h
		if not vistos.has(h):
			vistos[h] = true
			blobs.append({
				"hash": h,
				"ext": rel.get_extension().to_lower(),
				"tam": bytes.size(),
				"offset": dados_blobs.size(),
			})
			dados_blobs.append_array(bytes)

	var cab := JSON.stringify({
		"formato": Formato.VERSAO,
		"personagem": dados,
		"arquivos": arquivos,
		"blobs": blobs,
	}).to_utf8_buffer()

	var conteudo := PackedByteArray()
	conteudo.resize(4)
	conteudo.encode_u32(0, cab.size())
	conteudo.append_array(cab)
	conteudo.append_array(dados_blobs)

	var payload := PackedByteArray()
	payload.resize(4)
	payload.encode_u32(0, conteudo.size())
	payload.append_array(conteudo.compress(FileAccess.COMPRESSION_GZIP))

	var texto := PREFIXO + Marshalls.raw_to_base64(payload)
	var aviso := ""
	if texto.length() > AVISO_TAMANHO:
		aviso = "Backup grande (%d KB). Se a área de transferência recusar, vamos exportar por arquivo." % (texto.length() / 1024)
	return {"ok": true, "erro": "", "texto": texto, "aviso": aviso}


# Lê o texto do backup sem gravar nada. Usado pelo importar e pelos testes.
static func ler_indice(texto: String) -> Dictionary:
	var t := texto.strip_edges().replace("\n", "").replace("\r", "").replace(" ", "").replace("\t", "")
	if not t.begins_with(PREFIXO):
		return _falha("Esse texto não é um backup de personagem.")
	var payload := Marshalls.base64_to_raw(t.substr(PREFIXO.length()))
	if payload.size() < 5:
		return _falha("Backup incompleto.")
	var tam := payload.decode_u32(0)
	var conteudo := payload.slice(4, payload.size()).decompress(tam, FileAccess.COMPRESSION_GZIP)
	if conteudo.size() != tam or conteudo.size() < 4:
		return _falha("Não consegui descomprimir o backup.")
	var tam_cab := conteudo.decode_u32(0)
	if 4 + tam_cab > conteudo.size():
		return _falha("Backup corrompido.")
	var cab := conteudo.slice(4, 4 + tam_cab).get_string_from_utf8()
	var indice = JSON.parse_string(cab)
	if typeof(indice) != TYPE_DICTIONARY:
		return _falha("Backup corrompido (índice).")
	return {"ok": true, "erro": "", "indice": indice, "conteudo": conteudo, "inicio": 4 + tam_cab}


# Grava o personagem do backup em user://personagens/<id>/.
# Se o ID já existir (em res:// ou user://), usa id_2, id_3...
static func importar(texto: String) -> Dictionary:
	var lido: Dictionary = ler_indice(texto)
	if not lido["ok"]:
		return lido
	var indice: Dictionary = lido["indice"]
	var conteudo: PackedByteArray = lido["conteudo"]
	var inicio: int = lido["inicio"]

	if typeof(indice.get("personagem")) != TYPE_DICTIONARY \
			or typeof(indice.get("blobs")) != TYPE_ARRAY \
			or typeof(indice.get("arquivos")) != TYPE_DICTIONARY:
		return _falha("Backup incompleto.")

	var norm: Dictionary = Formato.normalizar(indice["personagem"])
	if not norm["ok"]:
		return _falha(str(norm["erro"]))
	var p: Dictionary = norm["personagem"]
	var id := id_livre(str(p["id"]))
	p["id"] = id
	var pasta := "user://personagens/" + id + "/"
	DirAccess.make_dir_recursive_absolute(pasta)

	var arquivos: Dictionary = indice["arquivos"]
	var blobs: Array = indice["blobs"]
	for rel in arquivos.keys():
		var nome := str(rel)
		if nome.begins_with("/") or nome.contains(".."):
			continue
		var h := str(arquivos[rel])
		var blob := _achar_blob(blobs, h)
		if blob.is_empty():
			continue
		var ini := inicio + int(blob["offset"])
		var bytes := conteudo.slice(ini, ini + int(blob["tam"]))
		if _sha256(bytes) != h:
			return _falha("Arquivo corrompido no backup: " + nome)
		DirAccess.make_dir_recursive_absolute(pasta + nome.get_base_dir())
		var f := FileAccess.open(pasta + nome, FileAccess.WRITE)
		if f == null:
			return _falha("Não consegui gravar " + nome)
		f.store_buffer(bytes)
		f.close()

	var fj := FileAccess.open(pasta + "personagem.json", FileAccess.WRITE)
	if fj == null:
		return _falha("Não consegui gravar o personagem neste aparelho.")
	fj.store_string(JSON.stringify(p, "\t"))
	fj.close()

	return {"ok": true, "erro": "", "id": id, "pasta": pasta, "personagem": p}


# Primeiro ID livre: base, base_2, base_3...
static func id_livre(base: String) -> String:
	var id := base
	var n := 2
	while _id_ocupado(id):
		id = base + "_" + str(n)
		n += 1
	return id


static func _id_ocupado(id: String) -> bool:
	for raiz in RAIZES:
		if FileAccess.file_exists(raiz + id + "/personagem.json"):
			return true
	return false


static func _listar(base: String, rel: String, saida: Array[String]) -> void:
	var dir := DirAccess.open(base + rel)
	if dir == null:
		return
	for nome in dir.get_files():
		if nome.get_extension().to_lower() in EXTENSOES_MIDIA:
			saida.append(rel + nome)
	for pasta in dir.get_directories():
		_listar(base, rel + pasta + "/", saida)


static func _achar_blob(blobs: Array, h: String) -> Dictionary:
	for b in blobs:
		if typeof(b) == TYPE_DICTIONARY and b.get("hash", "") == h:
			return b
	return {}


static func _sha256(bytes: PackedByteArray) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(bytes)
	return ctx.finish().hex_encode()


static func _falha(msg: String) -> Dictionary:
	return {"ok": false, "erro": msg}