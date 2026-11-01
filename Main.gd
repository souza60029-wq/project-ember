extends Node2D

const Caixa = preload("res://Caixa.gd")
const Personagem = preload("res://Personagem.gd")

const ARQUIVO_SAVE := "user://personagem.json"
const VIEW_W := 960.0
const VIEW_H := 540.0
const NOME_PADRAO := "Ash Crimson"
const VISIVEIS := 12
const FRAMES_KO := 150
const TECLAS := ["LP", "LK", "HP", "HK", "CD", "ROLL"]
const BOTOES_VALIDOS := ["LP", "LK", "HP", "HK", "CD"]
const INTEIROS := ["forca", "startup", "active", "recovery"]
const PREVIEW_X := 780.0
const PREVIEW_CHAO := 280.0

const DPAD_C := Vector2(120.0, 430.0)
const DPAD_R := 80.0
const BOTAO_R := 36.0
const BOTOES := {
	"HP": Vector2(720.0, 330.0),
	"CD": Vector2(840.0, 330.0),
	"LP": Vector2(660.0, 410.0),
	"HK": Vector2(780.0, 410.0),
	"LK": Vector2(720.0, 490.0),
	"ROLL": Vector2(860.0, 470.0),
}

const RECT_EDITOR := Rect2(400.0, 8.0, 160.0, 34.0)
const RECT_RESET := Rect2(260.0, 8.0, 120.0, 34.0)
const RECT_EXPORTAR := Rect2(540.0, 8.0, 130.0, 34.0)
const RECT_IMPORTAR := Rect2(680.0, 8.0, 130.0, 34.0)
const RECT_FECHAR := Rect2(820.0, 8.0, 130.0, 34.0)
const RECT_NOVO := Rect2(10.0, 372.0, 78.0, 28.0)
const RECT_COPIA := Rect2(92.0, 372.0, 78.0, 28.0)
const RECT_APAGA := Rect2(174.0, 372.0, 76.0, 28.0)
const RECT_SOBE := Rect2(10.0, 406.0, 115.0, 28.0)
const RECT_DESCE := Rect2(131.0, 406.0, 119.0, 28.0)
const RECT_PREVIEW := Rect2(620.0, 52.0, 330.0, 250.0)

const CAMPOS := [
	{"k": "nome", "rot": "Nome", "tipo": "texto"},
	{"k": "botao", "rot": "Botão", "tipo": "lista", "opc": ["LP", "LK", "HP", "HK", "CD"]},
	{"k": "carga", "rot": "Carga", "tipo": "lista", "opc": ["", "tras", "baixo"]},
	{"k": "carga_seg", "rot": "Carga (seg)", "tipo": "num", "min": 0.0, "max": 2.0, "passo": 0.1},
	{"k": "forca", "rot": "Força (1-3)", "tipo": "num", "min": 1.0, "max": 3.0, "passo": 1.0},
	{"k": "startup", "rot": "Startup", "tipo": "num", "min": 0.0, "max": 60.0, "passo": 1.0},
	{"k": "active", "rot": "Active", "tipo": "num", "min": 1.0, "max": 60.0, "passo": 1.0},
	{"k": "recovery", "rot": "Recovery", "tipo": "num", "min": 0.0, "max": 90.0, "passo": 1.0},
	{"k": "dano", "rot": "Dano", "tipo": "num", "min": 0.0, "max": 999.0, "passo": 10.0},
	{"k": "custo", "rot": "Custo barra", "tipo": "num", "min": 0.0, "max": 300.0, "passo": 10.0},
	{"k": "energia_ganha", "rot": "Barra ganha", "tipo": "num", "min": 0.0, "max": 300.0, "passo": 5.0},
	{"k": "antichao", "rot": "Anti-chão", "tipo": "bool"},
	{"k": "blowoff", "rot": "Blow off", "tipo": "bool"},
	{"k": "so_ar", "rot": "Só no ar", "tipo": "bool"},
	{"k": "hb_x", "rot": "Hitbox X", "tipo": "hb", "chave": "x", "min": -200.0, "max": 200.0, "passo": 5.0},
	{"k": "hb_y", "rot": "Hitbox Y", "tipo": "hb", "chave": "y", "min": -200.0, "max": 0.0, "passo": 5.0},
	{"k": "hb_w", "rot": "Hitbox W", "tipo": "hb", "chave": "w", "min": 1.0, "max": 300.0, "passo": 5.0},
	{"k": "hb_h", "rot": "Hitbox H", "tipo": "hb", "chave": "h", "min": 1.0, "max": 300.0, "passo": 5.0},
]

var p1 = null
var p2 = null
var nome_p1: String = NOME_PADRAO
var editando := false
var ed_golpes: Array = []
var ed_sel := 0
var ed_scroll := 0
var ed_nome: String = NOME_PADRAO
var msg_ed := ""
var toques := {}
var mask1 := {}
var mask2 := {}
var ko_t := 0
var ignorar_mouse := 0
var atualizando_campos := false
var le_golpe: LineEdit = null
var le_pers: LineEdit = null

# ---------- Ciclo de vida ----------

func _ready() -> void:
	p2 = Personagem.new()
	p2.definir_golpes(Personagem.golpes_padrao_ash())
	p1 = Personagem.new()
	_carregar()
	_criar_campos_editor()
	_reiniciar_luta()

func _criar_campos_editor() -> void:
	le_golpe = LineEdit.new()
	le_golpe.position = Vector2(420.0, 52.0)
	le_golpe.size = Vector2(180.0, 22.0)
	le_golpe.visible = false
	le_golpe.text_changed.connect(_on_nome_golpe)
	add_child(le_golpe)
	le_pers = LineEdit.new()
	le_pers.position = Vector2(10.0, 478.0)
	le_pers.size = Vector2(240.0, 30.0)
	le_pers.visible = false
	le_pers.text_changed.connect(_on_nome_pers)
	add_child(le_pers)

func _process(_delta: float) -> void:
	if ignorar_mouse > 0:
		ignorar_mouse -= 1
	queue_redraw()

func _physics_process(_delta: float) -> void:
	if editando or p1 == null:
		return
	_passo_jogador(p1, (_dir_pad(0) + _vec_dpad()).limit_length(1.0), _entrada_p1(), mask1)
	_passo_jogador(p2, _dir_pad(1), _entrada_pad(1), mask2)
	_resolver_combate(p1, p2)
	_resolver_combate(p2, p1)
	_separar_corpos()
	_checar_combos()
	if p1.estado == Personagem.Estado.KO or p2.estado == Personagem.Estado.KO:
		ko_t += 1
		if ko_t > FRAMES_KO:
			_reiniciar_luta()
	else:
		ko_t = 0

# ---------- Persistência e validação ----------

func _carregar() -> void:
	var dados = null
	if FileAccess.file_exists(ARQUIVO_SAVE):
		dados = JSON.parse_string(FileAccess.get_file_as_string(ARQUIVO_SAVE))
	var r: Dictionary = _validar_personagem(dados)
	if r["ok"]:
		nome_p1 = str(r["nome"])
		p1.definir_golpes(r["golpes"])
	else:
		nome_p1 = NOME_PADRAO
		p1.definir_golpes(Personagem.golpes_padrao_ash())

func _salvar() -> void:
	var f := FileAccess.open(ARQUIVO_SAVE, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"nome": nome_p1, "golpes": p1.golpes}, "  "))
	f.close()

func _validar_personagem(dados) -> Dictionary:
	if not (dados is Dictionary):
		return {"ok": false, "erro": "JSON inválido: esperado um objeto com nome e golpes.", "nome": "", "golpes": []}
	if not dados.has("golpes") or not (dados["golpes"] is Array):
		return {"ok": false, "erro": "Faltou a lista 'golpes'.", "nome": "", "golpes": []}
	var lista: Array = []
	for g in dados["golpes"]:
		if not (g is Dictionary):
			return {"ok": false, "erro": "Há um golpe que não é objeto.", "nome": "", "golpes": []}
		if not BOTOES_VALIDOS.has(str(g.get("botao", ""))):
			return {"ok": false, "erro": "Golpe com botão inválido: " + str(g.get("botao", "")), "nome": "", "golpes": []}
		var carga: String = str(g.get("carga", ""))
		if carga != "" and carga != "tras" and carga != "baixo":
			return {"ok": false, "erro": "Carga inválida: " + carga, "nome": "", "golpes": []}
		lista.append(Personagem.normalizar_golpe(g))
	if lista.size() > 40:
		return {"ok": false, "erro": "Máximo de 40 golpes.", "nome": "", "golpes": []}
	var nome: String = str(dados.get("nome", "")).strip_edges()
	if nome == "":
		nome = "Sem nome"
	return {"ok": true, "erro": "", "nome": nome, "golpes": lista}

# ---------- Entrada ----------

func _unhandled_input(ev: InputEvent) -> void:
	var mb := ev as InputEventMouseButton
	var st := ev as InputEventScreenTouch
	var sd := ev as InputEventScreenDrag
	if editando:
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_clique_editor(mb.position)
		return
	if st != null:
		if st.pressed:
			var alvo := _alvo_toque(st.position)
			toques[st.index] = {"alvo": alvo, "pos": st.position}
			if alvo == "EDITOR":
				_abrir_editor()
			elif alvo == "RESET":
				_reiniciar_luta()
		else:
			toques.erase(st.index)
	elif sd != null:
		if toques.has(sd.index):
			toques[sd.index]["pos"] = sd.position

func _alvo_toque(p: Vector2) -> String:
	if RECT_EDITOR.has_point(p):
		return "EDITOR"
	if RECT_RESET.has_point(p):
		return "RESET"
	if p.distance_to(DPAD_C) <= DPAD_R * 1.2:
		return "DPAD"
	var melhor := ""
	var menor: float = BOTAO_R * 1.25
	for k in BOTOES:
		var d: float = p.distance_to(BOTOES[k])
		if d < menor:
			menor = d
			melhor = str(k)
	return melhor

func _vec_dpad() -> Vector2:
	for idx in toques:
		if str(toques[idx]["alvo"]) == "DPAD":
			var pos_t: Vector2 = toques[idx]["pos"]
			var v: Vector2 = (pos_t - DPAD_C) / DPAD_R
			if v.length() < 0.25:
				return Vector2.ZERO
			return v.limit_length(1.0)
	return Vector2.ZERO

func _botoes_tocados() -> Dictionary:
	var r := {}
	for idx in toques:
		var alvo: String = str(toques[idx]["alvo"])
		if BOTOES.has(alvo):
			r[alvo] = true
	return r

func _dir_pad(dev: int) -> Vector2:
	var v := Vector2(Input.get_joy_axis(dev, JOY_AXIS_LEFT_X), Input.get_joy_axis(dev, JOY_AXIS_LEFT_Y))
	if v.length() < 0.3:
		v = Vector2.ZERO
	if Input.is_joy_button_pressed(dev, JOY_BUTTON_DPAD_LEFT):
		v.x -= 1.0
	if Input.is_joy_button_pressed(dev, JOY_BUTTON_DPAD_RIGHT):
		v.x += 1.0
	if Input.is_joy_button_pressed(dev, JOY_BUTTON_DPAD_UP):
		v.y -= 1.0
	if Input.is_joy_button_pressed(dev, JOY_BUTTON_DPAD_DOWN):
		v.y += 1.0
	return v.limit_length(1.0)

func _entrada_pad(dev: int) -> Dictionary:
	return {
		"LP": Input.is_joy_button_pressed(dev, JOY_BUTTON_X),
		"LK": Input.is_joy_button_pressed(dev, JOY_BUTTON_A),
		"HP": Input.is_joy_button_pressed(dev, JOY_BUTTON_Y),
		"HK": Input.is_joy_button_pressed(dev, JOY_BUTTON_B),
		"CD": Input.is_joy_button_pressed(dev, JOY_BUTTON_RIGHT_SHOULDER),
		"ROLL": Input.is_joy_button_pressed(dev, JOY_BUTTON_LEFT_SHOULDER),
	}

func _entrada_p1() -> Dictionary:
	var pad := _entrada_pad(0)
	var tocado := _botoes_tocados()
	var r := {}
	for k in TECLAS:
		r[k] = bool(pad[k]) or tocado.has(k)
	return r

# Combos de toque: LP+LK = ROLL, HP+HK = CD.
func _logico(raw: Dictionary) -> Dictionary:
	var roll_c: bool = bool(raw["LP"]) and bool(raw["LK"])
	var cd_c: bool = bool(raw["HP"]) and bool(raw["HK"])
	return {
		"LP": bool(raw["LP"]) and not roll_c,
		"LK": bool(raw["LK"]) and not roll_c,
		"HP": bool(raw["HP"]) and not cd_c,
		"HK": bool(raw["HK"]) and not cd_c,
		"CD": bool(raw["CD"]) or cd_c,
		"ROLL": bool(raw["ROLL"]) or roll_c,
	}

# Botão segurado não repete golpe. Ao iniciar um golpe, ou ao sair de um
# estado livre e voltar a um livre, os botões ainda segurados ficam mascarados
# até serem soltos.
func _passo_jogador(p, dir: Vector2, raw: Dictionary, mask: Dictionary) -> void:
	var logico: Dictionary = _logico(raw)
	var ap := {}
	for k in TECLAS:
		ap[k] = bool(logico[k]) and not bool(mask[k])
	var era_livre: bool = _livre(p.estado)
	p.atualizar(dir, ap)
	if era_livre != _livre(p.estado):
		for k in TECLAS:
			if bool(raw[k]) or bool(logico[k]):
				mask[k] = true
	for k in TECLAS:
		if not (bool(raw[k]) or bool(logico[k])):
			mask[k] = false

func _livre(est: int) -> bool:
	return est == Personagem.Estado.PARADO or est == Personagem.Estado.ANDANDO or est == Personagem.Estado.PULANDO or est == Personagem.Estado.DEFENDENDO

func _mascara_vazia() -> Dictionary:
	var d := {}
	for k in TECLAS:
		d[k] = false
	return d

# ---------- Combate ----------

func _reiniciar_luta() -> void:
	p1.resetar(200.0, true)
	p2.resetar(720.0, false)
	p1.oponente = p2
	p2.oponente = p1
	p1.combo = 0
	p2.combo = 0
	mask1 = _mascara_vazia()
	mask2 = _mascara_vazia()
	ko_t = 0

func _resolver_combate(atk, dfn) -> void:
	if not atk.hitbox_ativa() or atk.golpe_acertou:
		return
	var g: Dictionary = atk.golpe_atual
	if not Caixa.colidem(atk.hitbox_rect(), dfn.corpo_rect()):
		return
	var res: String = dfn.resultado_para(g)
	if res == "nada":
		return
	atk.golpe_acertou = true
	if res == "bloqueio":
		dfn.receber_bloqueio(g)
		return
	var escala: float = maxf(0.5, 1.0 - 0.1 * float(atk.combo))
	var dano: float = float(g["dano"]) * escala
	dfn.receber_acerto(g, dano)
	atk.combo += 1
	if str(g["carga"]) != "" and float(g["energia_ganha"]) > 0.0:
		atk.barra.ganhar(float(g["energia_ganha"]))

func _checar_combos() -> void:
	var caidos := [Personagem.Estado.GOLPEADO, Personagem.Estado.CAIDO, Personagem.Estado.LEVANTANDO, Personagem.Estado.KO]
	if not (p2.estado in caidos):
		p1.combo = 0
	if not (p1.estado in caidos):
		p2.combo = 0

func _separar_corpos() -> void:
	if p1.no_chao or p2.no_chao:
		return
	var d: float = p2.pos.x - p1.pos.x
	var falta: float = Personagem.CORPO_LARGURA - absf(d)
	if falta <= 0.0:
		return
	var s: float = 1.0 if d >= 0.0 else -1.0
	var metade: float = falta * 0.5
	p1.pos = Vector2(clampf(p1.pos.x - s * metade, Personagem.LIMITE_ESQ, Personagem.LIMITE_DIR), p1.pos.y)
	p2.pos = Vector2(clampf(p2.pos.x + s * metade, Personagem.LIMITE_ESQ, Personagem.LIMITE_DIR), p2.pos.y)

# ---------- Editor ----------

func _abrir_editor() -> void:
	ed_golpes = []
	for g in p1.golpes:
		ed_golpes.append(g.duplicate(true))
	ed_nome = nome_p1
	ed_sel = 0
	ed_scroll = 0
	msg_ed = ""
	editando = true
	toques.clear()
	ignorar_mouse = 10
	le_golpe.visible = true
	le_pers.visible = true
	_atualizar_campos()

func _fechar_editor() -> void:
	nome_p1 = ed_nome.strip_edges()
	if nome_p1 == "":
		nome_p1 = "Sem nome"
	p1.definir_golpes(ed_golpes)
	_salvar()
	editando = false
	le_golpe.release_focus()
	le_pers.release_focus()
	le_golpe.visible = false
	le_pers.visible = false
	toques.clear()
	ignorar_mouse = 10
	_reiniciar_luta()

func _atualizar_campos() -> void:
	atualizando_campos = true
	le_pers.text = ed_nome
	if ed_golpes.is_empty():
		le_golpe.text = ""
		le_golpe.editable = false
	else:
		le_golpe.editable = true
		le_golpe.text = str(ed_golpes[ed_sel]["nome"])
	atualizando_campos = false

func _ajustar_scroll() -> void:
	if ed_sel < ed_scroll:
		ed_scroll = ed_sel
	elif ed_sel >= ed_scroll + VISIVEIS:
		ed_scroll = ed_sel - VISIVEIS + 1
	ed_scroll = maxi(0, ed_scroll)

func _on_nome_golpe(t: String) -> void:
	if atualizando_campos or ed_golpes.is_empty():
		return
	ed_golpes[ed_sel]["nome"] = t

func _on_nome_pers(t: String) -> void:
	if atualizando_campos:
		return
	ed_nome = t

func _clique_editor(p: Vector2) -> void:
	if ignorar_mouse > 0:
		return
	if RECT_EXPORTAR.has_point(p):
		_exportar()
	elif RECT_IMPORTAR.has_point(p):
		_importar()
	elif RECT_FECHAR.has_point(p):
		_fechar_editor()
	elif RECT_NOVO.has_point(p):
		_novo()
	elif RECT_COPIA.has_point(p):
		_copia()
	elif RECT_APAGA.has_point(p):
		_apaga()
	elif RECT_SOBE.has_point(p):
		_sobe()
	elif RECT_DESCE.has_point(p):
		_desce()
	else:
		_clique_lista_ou_campo(p)

func _clique_lista_ou_campo(p: Vector2) -> void:
	for i in range(ed_scroll, mini(ed_golpes.size(), ed_scroll + VISIVEIS)):
		var y_l: float = 52.0 + float(i - ed_scroll) * 26.0
		if Rect2(10.0, y_l, 240.0, 24.0).has_point(p):
			ed_sel = i
			_ajustar_scroll()
			_atualizar_campos()
			return
	if ed_golpes.is_empty():
		return
	for i in range(CAMPOS.size()):
		var c: Dictionary = CAMPOS[i]
		var y_c: float = 52.0 + float(i) * 24.0
		var tipo: String = str(c["tipo"])
		if tipo == "num" or tipo == "hb":
			if Rect2(530.0, y_c, 30.0, 22.0).has_point(p):
				_mudar_campo(i, -1)
				return
			if Rect2(565.0, y_c, 30.0, 22.0).has_point(p):
				_mudar_campo(i, 1)
				return
		elif tipo == "lista" or tipo == "bool":
			if Rect2(420.0, y_c, 160.0, 22.0).has_point(p):
				_mudar_campo(i, 1)
				return

func _mudar_campo(i: int, sentido: int) -> void:
	if ed_golpes.is_empty():
		return
	var c: Dictionary = CAMPOS[i]
	var g: Dictionary = ed_golpes[ed_sel]
	var k: String = str(c.get("k", ""))
	var tipo: String = str(c["tipo"])
	if tipo == "bool":
		g[k] = not bool(g[k])
	elif tipo == "lista":
		var opc: Array = c["opc"]
		var idx: int = opc.find(str(g[k]))
		g[k] = opc[posmod(idx + sentido, opc.size())]
	elif tipo == "num":
		var v: float = clampf(float(g[k]) + float(sentido) * float(c["passo"]), float(c["min"]), float(c["max"]))
		if INTEIROS.has(k):
			g[k] = roundi(v)
		else:
			g[k] = v
	elif tipo == "hb":
		var hb: Dictionary = g["hitbox"]
		var ck: String = str(c["chave"])
		hb[ck] = clampf(float(hb[ck]) + float(sentido) * float(c["passo"]), float(c["min"]), float(c["max"]))

func _novo() -> void:
	var g: Dictionary = Personagem.golpe_padrao()
	g["nome"] = "Novo golpe"
	ed_golpes.append(g)
	ed_sel = ed_golpes.size() - 1
	_ajustar_scroll()
	_atualizar_campos()

func _copia() -> void:
	if ed_golpes.is_empty():
		return
	var c: Dictionary = ed_golpes[ed_sel].duplicate(true)
	c["nome"] = str(c["nome"]) + " (cópia)"
	ed_golpes.insert(ed_sel + 1, c)
	ed_sel += 1
	_ajustar_scroll()
	_atualizar_campos()

func _apaga() -> void:
	if ed_golpes.is_empty():
		return
	ed_golpes.remove_at(ed_sel)
	ed_sel = clampi(ed_sel, 0, maxi(0, ed_golpes.size() - 1))
	_ajustar_scroll()
	_atualizar_campos()

func _sobe() -> void:
	if ed_golpes.is_empty() or ed_sel <= 0:
		return
	_trocar(ed_sel, ed_sel - 1)
	ed_sel -= 1
	_ajustar_scroll()
	_atualizar_campos()

func _desce() -> void:
	if ed_golpes.is_empty() or ed_sel >= ed_golpes.size() - 1:
		return
	_trocar(ed_sel, ed_sel + 1)
	ed_sel += 1
	_ajustar_scroll()
	_atualizar_campos()

func _trocar(a: int, b: int) -> void:
	var t = ed_golpes[a]
	ed_golpes[a] = ed_golpes[b]
	ed_golpes[b] = t

func _exportar() -> void:
	DisplayServer.clipboard_set(JSON.stringify({"nome": ed_nome, "golpes": ed_golpes}, "  "))
	msg_ed = "Personagem copiado para a área de transferência."

func _importar() -> void:
	var texto: String = DisplayServer.clipboard_get()
	var r: Dictionary = _validar_personagem(JSON.parse_string(texto))
	if not r["ok"]:
		msg_ed = "Importação falhou: " + str(r["erro"])
		return
	ed_nome = str(r["nome"])
	ed_golpes = r["golpes"]
	ed_sel = 0
	ed_scroll = 0
	msg_ed = "Importado: %s (%d golpes)" % [ed_nome, ed_golpes.size()]
	_atualizar_campos()

# ---------- Desenho ----------

func _draw() -> void:
	if editando:
		_desenhar_editor()
		return
	_desenhar_luta()
	_desenhar_hud()
	_desenhar_controles()

func _texto(s: String, pos: Vector2, tam: int = 14, cor: Color = Color.WHITE) -> void:
	draw_string(ThemeDB.fallback_font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1.0, tam, cor)

func _texto_dir(s: String, pos: Vector2, largura: float, tam: int = 14, cor: Color = Color.WHITE) -> void:
	draw_string(ThemeDB.fallback_font, pos, s, HORIZONTAL_ALIGNMENT_RIGHT, largura, tam, cor)

func _texto_c(r: Rect2, s: String, tam: int = 14, cor: Color = Color.WHITE) -> void:
	draw_string(ThemeDB.fallback_font, Vector2(r.position.x, r.position.y + r.size.y * 0.5 + tam * 0.35), s, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, tam, cor)

func _botao(r: Rect2, s: String, ativo: bool = false) -> void:
	draw_rect(r, Color(0.25, 0.35, 0.55) if ativo else Color(0.16, 0.16, 0.22))
	draw_rect(r, Color(0.6, 0.6, 0.7), false, 1.0)
	_texto_c(r, s, 13)

func _fmt(v) -> String:
	if v is bool:
		return "sim" if v else "não"
	if v is float:
		var r: float = snappedf(v, 0.01)
		if is_equal_approx(r, roundf(r)):
			return str(int(roundf(r)))
		return str(r)
	var s: String = str(v)
	return "(nenhuma)" if s == "" else s

func _valor_campo(c: Dictionary):
	var g: Dictionary = ed_golpes[ed_sel]
	if str(c["tipo"]) == "hb":
		return g["hitbox"][str(c["chave"])]
	return g[str(c["k"])]

func _desenhar_editor() -> void:
	draw_rect(Rect2(0.0, 0.0, VIEW_W, VIEW_H), Color(0.07, 0.07, 0.09))
	_texto("EDITOR - " + ed_nome, Vector2(10.0, 30.0), 18)
	_botao(RECT_EXPORTAR, "EXPORTAR")
	_botao(RECT_IMPORTAR, "IMPORTAR")
	_botao(RECT_FECHAR, "FECHAR", true)
	var n: int = ed_golpes.size()
	for i in range(ed_scroll, mini(n, ed_scroll + VISIVEIS)):
		var y: float = 52.0 + float(i - ed_scroll) * 26.0
		_botao(Rect2(10.0, y, 240.0, 24.0), "%d. %s" % [i + 1, str(ed_golpes[i]["nome"])], i == ed_sel)
	_botao(RECT_NOVO, "NOVO")
	_botao(RECT_COPIA, "COPIA")
	_botao(RECT_APAGA, "APAGA")
	_botao(RECT_SOBE, "SOBE")
	_botao(RECT_DESCE, "DESCE")
	_texto("Personagem:", Vector2(10.0, 470.0), 13, Color(0.7, 0.7, 0.7))
	if n == 0:
		_texto("Nenhum golpe. Use NOVO.", Vector2(270.0, 70.0), 14, Color(0.8, 0.8, 0.8))
	else:
		for i in range(CAMPOS.size()):
			_desenhar_campo(i)
		_desenhar_preview()
	_texto(msg_ed, Vector2(10.0, 528.0), 13, Color(0.9, 0.9, 0.5))

func _desenhar_campo(i: int) -> void:
	var c: Dictionary = CAMPOS[i]
	var y: float = 52.0 + float(i) * 24.0
	_texto(str(c["rot"]), Vector2(270.0, y + 15.0), 13, Color(0.85, 0.85, 0.9))
	var tipo: String = str(c["tipo"])
	if tipo == "texto":
		return
	var v = _valor_campo(c)
	if tipo == "num" or tipo == "hb":
		_texto(_fmt(v), Vector2(420.0, y + 15.0), 13)
		_botao(Rect2(530.0, y, 30.0, 22.0), "-")
		_botao(Rect2(565.0, y, 30.0, 22.0), "+")
	else:
		_botao(Rect2(420.0, y, 160.0, 22.0), _fmt(v))

func _desenhar_preview() -> void:
	draw_rect(RECT_PREVIEW, Color(0.1, 0.1, 0.13))
	draw_rect(RECT_PREVIEW, Color(0.5, 0.5, 0.6), false, 1.0)
	_texto("Hitbox do golpe selecionado", Vector2(630.0, 68.0), 13, Color(0.8, 0.8, 0.8))
	draw_line(Vector2(620.0, PREVIEW_CHAO), Vector2(950.0, PREVIEW_CHAO), Color(0.4, 0.4, 0.5), 1.0)
	var base := Vector2(PREVIEW_X, PREVIEW_CHAO)
	draw_rect(Rect2(base.x - 25.0, base.y - 120.0, 50.0, 120.0), Color(0.3, 0.6, 1.0, 0.5))
	var g: Dictionary = ed_golpes[ed_sel]
	var hb: Rect2 = Caixa.rect_hitbox(g["hitbox"], base, true)
	draw_rect(hb, Color(1.0, 0.2, 0.2, 0.55))
	var tot: int = int(g["startup"]) + int(g["active"]) + int(g["recovery"])
	var y: float = 320.0
	_texto(str(g["nome"]), Vector2(620.0, y), 16)
	_texto("Startup %d | Active %d | Recovery %d | Total %d" % [int(g["startup"]), int(g["active"]), int(g["recovery"]), tot], Vector2(620.0, y + 24.0), 13)
	_texto("Dano %s | Custo %s | Barra ganha %s" % [_fmt(g["dano"]), _fmt(g["custo"]), _fmt(g["energia_ganha"])], Vector2(620.0, y + 44.0), 13)
	_texto("Botão %s | Carga: %s | Força %s" % [str(g["botao"]), _fmt(str(g["carga"])), _fmt(g["forca"])], Vector2(620.0, y + 64.0), 13)
	_texto("Anti-chão: %s | Blow off: %s | Só no ar: %s" % [_fmt(g["antichao"]), _fmt(g["blowoff"]), _fmt(g["so_ar"])], Vector2(620.0, y + 84.0), 13)
	_texto("Ordem importa: o primeiro golpe que bate", Vector2(620.0, y + 110.0), 12, Color(0.7, 0.7, 0.7))
	_texto("nas condições é o escolhido.", Vector2(620.0, y + 126.0), 12, Color(0.7, 0.7, 0.7))

func _desenhar_luta() -> void:
	draw_rect(Rect2(0.0, 0.0, VIEW_W, VIEW_H), Color(0.09, 0.09, 0.12))
	draw_rect(Rect2(0.0, Personagem.CHAO_Y, VIEW_W, VIEW_H - Personagem.CHAO_Y), Color(0.18, 0.16, 0.2))
	draw_line(Vector2(0.0, Personagem.CHAO_Y), Vector2(VIEW_W, Personagem.CHAO_Y), Color(0.5, 0.5, 0.6), 2.0)
	_desenhar_personagem(p1, Color(0.3, 0.6, 1.0))
	_desenhar_personagem(p2, Color(1.0, 0.45, 0.2))

func _desenhar_personagem(p, base: Color) -> void:
	var est: int = p.estado
	var cor: Color = base
	if est == Personagem.Estado.GOLPEADO:
		cor = base.lerp(Color.WHITE, 0.5)
	elif est == Personagem.Estado.CAIDO:
		cor = base.darkened(0.4)
	elif est == Personagem.Estado.ATACANDO:
		cor = base.lightened(0.3)
	elif est == Personagem.Estado.KO:
		cor = Color(0.3, 0.3, 0.3)
	elif est == Personagem.Estado.ESQUIVANDO or est == Personagem.Estado.LEVANTANDO:
		cor = Color(base.r, base.g, base.b, 0.55)
	var c: Rect2 = p.corpo_rect()
	draw_rect(c, cor)
	draw_rect(c, Color(1.0, 1.0, 1.0, 0.8), false, 2.0)
	var frente: float = 1.0 if p.direita else -1.0
	draw_circle(Vector2(p.pos.x + frente * 14.0, p.pos.y - 96.0), 5.0, Color.WHITE)
	var hb: Rect2 = p.hitbox_rect()
	if hb.size.x > 0.0:
		draw_rect(hb, Color(1.0, 0.2, 0.2, 0.5))

func _desenhar_hud() -> void:
	_barra_vida(Rect2(20.0, 60.0, 410.0, 16.0), p1, false)
	_barra_vida(Rect2(530.0, 60.0, 410.0, 16.0), p2, true)
	_barra_energia(Rect2(20.0, 82.0, 300.0, 8.0), p1, false)
	_barra_energia(Rect2(640.0, 82.0, 300.0, 8.0), p2, true)
	_texto(nome_p1, Vector2(20.0, 54.0), 14)
	_texto_dir("Treino (P2)", Vector2(530.0, 54.0), 410.0, 14)
	_texto(p1.nome_estado(), Vector2(20.0, 110.0), 12, Color(0.8, 0.8, 0.8))
	_texto_dir(p2.nome_estado(), Vector2(530.0, 110.0), 410.0, 12, Color(0.8, 0.8, 0.8))
	if p1.combo > 1:
		_texto("%d hits" % p1.combo, Vector2(20.0, 130.0), 16, Color(1.0, 0.9, 0.3))
	if p2.combo > 1:
		_texto_dir("%d hits" % p2.combo, Vector2(530.0, 130.0), 410.0, 16, Color(1.0, 0.9, 0.3))
	_botao(RECT_EDITOR, "EDITOR")
	_botao(RECT_RESET, "RESET")
	if p1.estado == Personagem.Estado.KO or p2.estado == Personagem.Estado.KO:
		draw_string(ThemeDB.fallback_font, Vector2(0.0, 220.0), "K.O.", HORIZONTAL_ALIGNMENT_CENTER, VIEW_W, 56, Color(1.0, 0.3, 0.3))

func _barra_vida(r: Rect2, p, da_direita: bool) -> void:
	draw_rect(r, Color(0.25, 0.05, 0.05))
	var prop: float = clampf(float(p.vida) / Personagem.VIDA_MAX, 0.0, 1.0)
	var w: float = r.size.x * prop
	var x: float = r.position.x + (r.size.x - w if da_direita else 0.0)
	draw_rect(Rect2(x, r.position.y, w, r.size.y), Color(0.25, 0.9, 0.35))
	draw_rect(r, Color(1.0, 1.0, 1.0, 0.8), false, 1.0)

func _barra_energia(r: Rect2, p, da_direita: bool) -> void:
	draw_rect(r, Color(0.15, 0.15, 0.2))
	var maximo: float = maxf(1.0, float(p.barra.maximo))
	var prop: float = clampf(float(p.barra.valor) / maximo, 0.0, 1.0)
	var w: float = r.size.x * prop
	var x: float = r.position.x + (r.size.x - w if da_direita else 0.0)
	draw_rect(Rect2(x, r.position.y, w, r.size.y), Color(1.0, 0.7, 0.2))
	draw_rect(r, Color(1.0, 1.0, 1.0, 0.6), false, 1.0)

func _desenhar_controles() -> void:
	var tocado := _botoes_tocados()
	draw_circle(DPAD_C, DPAD_R, Color(1.0, 1.0, 1.0, 0.1))
	var dv: Vector2 = _vec_dpad()
	draw_circle(DPAD_C + dv * DPAD_R * 0.6, 26.0, Color(1.0, 1.0, 1.0, 0.4 if dv != Vector2.ZERO else 0.15))
	for k in BOTOES:
		var c: Vector2 = BOTOES[k]
		draw_circle(c, BOTAO_R, Color(1.0, 1.0, 1.0, 0.35 if tocado.has(k) else 0.12))
		draw_string(ThemeDB.fallback_font, c + Vector2(-BOTAO_R, 5.0), str(k), HORIZONTAL_ALIGNMENT_CENTER, BOTAO_R * 2.0, 14, Color(1.0, 1.0, 1.0, 0.8))