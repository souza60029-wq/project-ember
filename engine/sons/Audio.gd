extends Node

# Toca sons e músicas. Só olha pastas, não sabe nada sobre o seu jogo.
# Ordem de busca de um evento: som do golpe → som do personagem → comum → silêncio.
# Música: troca com fade cruzado (a atual desce e a nova sobe, 0,5 s cada).

const Eventos = preload("res://engine/sons/Eventos.gd")

const PASTA_COMUNS := "res://sons/comuns/"
const PASTA_INTERFACE := "res://sons/interface/"
const PASTA_MUSICA := "res://musica/"
const PASTAS_PERSONAGEM := ["res://personagens/", "user://personagens/"]
const EXTENSOES := ["ogg", "mp3", "wav"]
const CANAIS := 8
const FADE_MUSICA := 0.5
const VOLUME_MUDO := -60.0

var _canais: Array[AudioStreamPlayer] = []
var _musicas: Array[AudioStreamPlayer] = []
var _ativa: int = 0
var _nome_musica: String = ""
var _cache := {}
var _fades := {}


func _ready() -> void:
	for i in CANAIS:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_canais.append(p)
	for i in 2:
		var m := AudioStreamPlayer.new()
		m.volume_db = VOLUME_MUDO
		add_child(m)
		_musicas.append(m)


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


# Toca sons/interface/<nome>; se não existir, toca o da reserva (ex.: "start" -> "menu_confirma").
func tocar_interface_ou(nome: String, reserva: String) -> void:
	var caminho: String = _achar_base(PASTA_INTERFACE + nome)
	if caminho == "":
		caminho = _achar_base(PASTA_INTERFACE + reserva)
	_tocar_efeito(caminho)


func tocar_musica(nome: String, repetir: bool = true) -> void:
	if nome == _nome_musica and _musicas[_ativa].playing:
		return
	var stream = _carregar(_achar_base(PASTA_MUSICA + nome))
	var saindo: AudioStreamPlayer = _musicas[_ativa]
	_ativa = 1 - _ativa
	var entrando: AudioStreamPlayer = _musicas[_ativa]
	_nome_musica = nome if stream != null else ""
	if saindo.playing:
		_fade(saindo, VOLUME_MUDO, true)
	if stream == null:
		return
	_definir_loop(stream, repetir)
	entrando.stream = stream
	entrando.volume_db = VOLUME_MUDO
	entrando.play()
	_fade(entrando, 0.0, false)


func parar_musica() -> void:
	_nome_musica = ""
	var p: AudioStreamPlayer = _musicas[_ativa]
	if p.playing:
		_fade(p, VOLUME_MUDO, true)


func _fade(p: AudioStreamPlayer, alvo: float, parar_no_fim: bool) -> void:
	if _fades.has(p):
		_fades[p].kill()
	var t := create_tween()
	_fades[p] = t
	t.tween_property(p, "volume_db", alvo, FADE_MUSICA)
	if parar_no_fim:
		t.tween_callback(p.stop)


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


func _definir_loop(stream, repetir: bool) -> void:
	if stream is AudioStreamOggVorbis or stream is AudioStreamMP3:
		stream.loop = repetir
	elif stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD if repetir else AudioStreamWAV.LOOP_DISABLED


# res:// passa pelo importador do Godot (a exportação já importa tudo).
# user:// não tem importador: lê os bytes direto.
func _carregar(caminho: String):
	if caminho == "":
		return null
	if _cache.has(caminho):
		return _cache[caminho]
	var stream = null
	if caminho.begins_with("res://"):
		stream = load(caminho)
	else:
		stream = _carregar_de_bytes(caminho)
	_cache[caminho] = stream
	return stream


func _carregar_de_bytes(caminho: String):
	var bytes := FileAccess.get_file_as_bytes(caminho)
	if bytes.is_empty():
		return null
	match caminho.get_extension().to_lower():
		"mp3":
			var mp3 := AudioStreamMP3.new()
			mp3.data = bytes
			return mp3
		"wav":
			return _wav_de_bytes(bytes)
		"ogg":
			push_warning("OGG de pasta do usuário ainda não é suportado: " + caminho + " (use WAV ou MP3)")
			return null
	return null


# Lê um WAV PCM de 16 bits direto dos bytes (formato 1, sem compressão).
func _wav_de_bytes(b: PackedByteArray) -> AudioStreamWAV:
	if b.size() < 12 or b.slice(0, 4).get_string_from_ascii() != "RIFF" or b.slice(8, 12).get_string_from_ascii() != "WAVE":
		return null
	var pos := 12
	var formato := -1
	var canais := 1
	var taxa := 44100
	var bits := 16
	var dados := PackedByteArray()
	while pos + 8 <= b.size():
		var id := b.slice(pos, pos + 4).get_string_from_ascii()
		var tam := b.decode_u32(pos + 4)
		var ini := pos + 8
		if id == "fmt " and ini + 16 <= b.size():
			formato = b.decode_u16(ini)
			canais = b.decode_u16(ini + 2)
			taxa = b.decode_u32(ini + 4)
			bits = b.decode_u16(ini + 14)
		elif id == "data":
			dados = b.slice(ini, mini(ini + tam, b.size()))
		pos = ini + tam + (tam & 1)
	if formato != 1 or bits != 16 or dados.is_empty():
		return null
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = taxa
	s.stereo = canais == 2
	s.data = dados
	return s