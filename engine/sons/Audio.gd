extends Node

# Toca sons e músicas. Só olha pastas, não sabe nada sobre o seu jogo.
# Ordem de busca de um evento: som do golpe → som do personagem → comum → silêncio.

const Eventos = preload("res://engine/sons/Eventos.gd")

const PASTA_COMUNS := "res://sons/comuns/"
const PASTA_INTERFACE := "res://sons/interface/"
const PASTA_MUSICA := "res://musica/"
const PASTAS_PERSONAGEM := ["res://personagens/", "user://personagens/"]
const EXTENSOES := ["ogg", "mp3", "wav"]
const CANAIS := 8

var _canais: Array[AudioStreamPlayer] = []
var _musica: AudioStreamPlayer
var _cache := {}


func _ready() -> void:
	for i in CANAIS:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_canais.append(p)
	_musica = AudioStreamPlayer.new()
	add_child(_musica)


# Devolve o caminho do arquivo que deve tocar, ou "" se não existir nenhum.
# som_golpe: caminho relativo à pasta do personagem (ex.: "golpes/pluviose.ogg"), opcional.
func achar_som(evento: String, personagem_id: String = "", som_golpe: String = "") -> String:
	if personagem_id != "":
		if som_golpe != "":
			var do_golpe := _achar_no_personagem(personagem_id, som_golpe)
			if do_golpe != "":
				return do_golpe
		var do_personagem := _achar_no_personagem(personagem_id, "sons/" + evento)
		if do_personagem != "":
			return do_personagem
	return _achar_base(PASTA_COMUNS + evento)


func tocar(evento: String, personagem_id: String = "", som_golpe: String = "") -> void:
	_tocar_efeito(achar_som(evento, personagem_id, som_golpe))


func tocar_interface(nome: String) -> void:
	_tocar_efeito(_achar_base(PASTA_INTERFACE + nome))


func tocar_musica(nome: String, repetir: bool = true) -> void:
	var stream = _carregar(_achar_base(PASTA_MUSICA + nome))
	if stream == null:
		parar_musica()
		return
	if "loop" in stream:
		stream.loop = repetir
	_musica.stream = stream
	_musica.play()


func parar_musica() -> void:
	_musica.stop()


func _tocar_efeito(caminho: String) -> void:
	var stream = _carregar(caminho)
	if stream == null:
		return
	var livre: AudioStreamPlayer = _canais[0]
	for p in _canais:
		if not p.playing:
			livre = p
			break
	livre.stream = stream
	livre.play()


func _achar_no_personagem(personagem_id: String, relativo: String) -> String:
	for raiz in PASTAS_PERSONAGEM:
		var achado := _achar_base(raiz + personagem_id + "/" + relativo)
		if achado != "":
			return achado
	return ""


# Aceita o caminho com extensão ou sem extensão (testa ogg, mp3, wav).
func _achar_base(base: String) -> String:
	if base.get_extension().to_lower() in EXTENSOES and FileAccess.file_exists(base):
		return base
	for ext in EXTENSOES:
		if FileAccess.file_exists(base + "." + ext):
			return base + "." + ext
	return ""


# Lê o arquivo direto dos bytes, sem precisar de importação do Godot.
func _carregar(caminho: String):
	if caminho == "":
		return null
	if _cache.has(caminho):
		return _cache[caminho]
	var stream = null
	var bytes := FileAccess.get_file_as_bytes(caminho)
	if bytes.size() > 0:
		match caminho.get_extension().to_lower():
			"ogg":
				stream = AudioStreamOggVorbis.load_from_buffer(bytes)
			"mp3":
				var mp3 := AudioStreamMP3.new()
				mp3.data = bytes
				stream = mp3
			"wav":
				stream = AudioStreamWAV.load_from_buffer(bytes)
	_cache[caminho] = stream
	return stream