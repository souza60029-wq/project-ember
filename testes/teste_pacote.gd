extends SceneTree

# Testa a edição de golpes (Edicao), o backup BEP1 (Pacote) e se o editor e o menu compilam.
# Não depende de autoloads. Grava só em user:// e apaga ao final.

const Formato = preload("res://engine/formato/Formato.gd")
const Edicao = preload("res://engine/editor/Edicao.gd")
const Pacote = preload("res://engine/formato/Pacote.gd")

const ID_TESTE := "teste_pacote_tmp"
const PASTA_ORIGEM := "user://teste_pacote_origem/"

var oks := 0
var falhas := 0


func _init() -> void:
	print("Edição de golpes")
	_testar_edicao()
	print("Backup BEP1")
	_testar_backup()
	print("Compilação")
	_testar_compilacao()
	_apagar_pasta(PASTA_ORIGEM)
	_apagar_pasta("user://personagens/" + ID_TESTE + "/")
	_apagar_pasta("user://personagens/" + ID_TESTE + "_2/")
	print("Resultado: %d ok, %d falha(s)" % [oks, falhas])
	quit(1 if falhas > 0 else 0)


func _testar_edicao() -> void:
	var p: Dictionary = Edicao.novo_personagem("Teste", "teste")
	var golpes: Array = p["golpes"]
	_checar("começa sem golpes", golpes.size() == 0)
	_checar("inserir cria golpe", Edicao.inserir_golpe(p, 0))
	Edicao.inserir_golpe(p, 0)
	golpes[0]["nome"] = "A"
	golpes[1]["nome"] = "B"
	_checar("copiar funciona", Edicao.copiar_golpe(p, 0))
	_checar("cópia vem logo depois", golpes[1]["nome"] == "A (cópia)")
	_checar("tem três golpes", golpes.size() == 3)
	Edicao.mover_golpe(p, 2, -1)
	_checar("mover sobe", golpes[1]["nome"] == "B")
	Edicao.excluir_golpe(p, 0)
	_checar("excluir remove", golpes.size() == 2)
	while Edicao.inserir_golpe(p, 0):
		pass
	_checar("limite de 40 golpes", golpes.size() == Formato.MAX_GOLPES)
	var q: Dictionary = Edicao.novo_personagem("Q", "q")
	_checar("adiciona golpe fixo LP", Edicao.adicionar_base(q, "LP") == 0)
	_checar("não duplica golpe fixo", Edicao.adicionar_base(q, "LP") == 0 and (q["golpes"] as Array).size() == 1)
	_checar("golpe fixo só troca sprites e som", Edicao.chave_editavel(q["golpes"][0], "frames") and not Edicao.chave_editavel(q["golpes"][0], "dano"))


func _testar_backup() -> void:
	_preparar_origem()
	var p: Dictionary = Edicao.novo_personagem("Teste Backup", ID_TESTE)
	Edicao.inserir_golpe(p, 0)
	var r: Dictionary = Pacote.exportar(p, PASTA_ORIGEM)
	_checar("exporta", r["ok"])
	if not r["ok"]:
		return
	var texto: String = r["texto"]
	_checar("começa com BEP1:", texto.begins_with("BEP1:"))
	_checar("frame repetido guardado uma vez (2 blobs)", Pacote.ler_indice(texto)["indice"]["blobs"].size() == 2)

	var i: Dictionary = Pacote.importar(texto)
	_checar("importa", i["ok"])
	if not i["ok"]:
		return
	_checar("mantém o id", str(i["id"]) == ID_TESTE)
	var som := FileAccess.get_file_as_bytes(str(i["pasta"]) + "sons/voz_dano_leve.wav")
	_checar("som volta igual", som == "TESTE-SOM".to_utf8_buffer())
	var frame := FileAccess.get_file_as_bytes(str(i["pasta"]) + "golpes/frame_copia.png")
	_checar("frame repetido volta igual", frame == "TESTE-FRAME".to_utf8_buffer())

	var i2: Dictionary = Pacote.importar(texto)
	_checar("id repetido vira _2", str(i2.get("id", "")) == ID_TESTE + "_2")
	_checar("texto inválido recusado", not Pacote.importar("abc")["ok"])


func _testar_compilacao() -> void:
	for caminho in [
		"res://engine/menu/Menu.gd",
		"res://engine/editor/Edicao.gd",
		"res://engine/editor/EditorPersonagem.gd",
		"res://engine/formato/Pacote.gd",
		"res://engine/formato/Medidas.gd",
		"res://engine/nucleo/Sprites.gd",
		"res://engine/nucleo/Glifos.gd",
		"res://engine/selecao/Selecao.gd",
		"res://engine/luta/Luta.gd",
	]:
		_checar("compila " + caminho.get_file(), load(caminho) != null)


func _preparar_origem() -> void:
	_apagar_pasta(PASTA_ORIGEM)
	DirAccess.make_dir_recursive_absolute(PASTA_ORIGEM + "sons")
	DirAccess.make_dir_recursive_absolute(PASTA_ORIGEM + "golpes")
	_gravar(PASTA_ORIGEM + "sons/voz_dano_leve.wav", "TESTE-SOM")
	_gravar(PASTA_ORIGEM + "golpes/frame.png", "TESTE-FRAME")
	_gravar(PASTA_ORIGEM + "golpes/frame_copia.png", "TESTE-FRAME")


func _gravar(caminho: String, texto: String) -> void:
	var f := FileAccess.open(caminho, FileAccess.WRITE)
	f.store_string(texto)
	f.close()


func _apagar_pasta(caminho: String) -> void:
	var dir := DirAccess.open(caminho)
	if dir == null:
		return
	for f in dir.get_files():
		DirAccess.remove_absolute(caminho + f)
	for d in dir.get_directories():
		_apagar_pasta(caminho + d + "/")
	DirAccess.remove_absolute(caminho.trim_suffix("/"))


func _checar(nome: String, cond: bool) -> void:
	if cond:
		oks += 1
		print("  ok    - " + nome)
	else:
		falhas += 1
		print("  FALHA - " + nome)