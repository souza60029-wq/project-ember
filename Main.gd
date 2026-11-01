extends Node2D

const Personagem = preload("res://Personagem.gd")
const Caixa = preload("res://Caixa.gd")

const ARQUIVO_SAVE := "user://personagem.json"
const DPAD_CENTRO := Vector2(120, 430)
const DPAD_RAIO := 80.0
const RAIO_BOTAO := 36.0
const BOTOES := [
	["HP", 720.0, 330.0], ["CD", 840.0, 330.0], ["LP", 660.0, 410.0],
	["HK", 780.0, 410.0], ["LK", 720.0, 490.0], ["ROLL", 860.0, 470.0]
]
const BOTAO_EDITOR := Rect2(400, 8, 160, 34)
const BOTAO_RESET := Rect2(260, 8, 120, 34)
const JOY_MAPA := [
	[JOY_BUTTON_X, "LP"], [JOY_BUTTON_A, "LK"], [JOY_BUTTON_Y, "HP"],
	[JOY_BUTTON_B, "HK"], [JOY_BUTTON_RIGHT_SHOULDER, "CD"], [JOY_BUTTON_LEFT_SHOULDER, "ROLL"]
]
const CAMPOS := [
	["botao", "Botao", "lista", ["LP", "LK", "HP", "HK", "CD"]],
	["carga", "Comando de carga", "lista", ["", "tras", "baixo"]],
	["carga_seg", "Tempo de carga (s)", "float", 0.1, 0.1, 2.0],
	["forca", "Forca (3 = derruba)", "int", 1, 1, 3],
	["startup", "Startup (frames)", "int", 1, 1, 60],
	["active", "Active (frames)", "int", 1, 1, 60],
	["recovery", "Recovery (frames)", "int", 1, 0, 90],
	["dano", "Dano", "float", 10.0, 0.0, 999.0],
	["custo", "Custo de barra", "float", 10.0, 0.0, 300.0],
	["energia_ganha", "Barra ganha (so comando)", "float", 5.0, 0.0, 300.0],
	["antichao", "Anti-chao", "bool"],
	["blowoff", "Blow off", "bool"],
	["so_ar", "So no ar", "bool"],
	["hb_x", "Hitbox X", "int", 5, -200, 300],
	["hb_y", "Hitbox Y", "int", 5, -200, 0],
	["hb_w", "Hitbox W", "int", 5, 1, 300],
	["hb_h", "Hitbox H", "int", 5, 1, 300]
]
const VISIVEIS := 12
const ED_EXPORTAR := Rect2(540, 8, 130, 34)
const ED_IMPORTAR := Rect2(680, 8, 130, 34)
const ED_FECHAR := Rect2(820, 8, 130, 34)
const ED_NOVO := Rect2(10, 372, 78, 28)
const ED_COPIA := Rect2(92, 372, 78, 28)
const ED_APAGA := Rect2(174, 372, 76, 28)
const ED_SOBE := Rect2(10, 406, 115, 28)
const ED_DESCE := Rect2(131, 406, 119, 28)
const ED_PREVIEW := Rect2(620, 52, 330, 250)

enum Tela { LUTA, EDITOR }

var fonte: Font
var tela: int = Tela.LUTA
var dados: Dictionary = {}
var p1
var p2
var toques: Dictionary = {}      # indice do toque -> id ("dpad", "LP", ...)
var toque_vec: Dictionary = {}   # indice do toque -> Vector2 (so dpad)
var novos_p1: Array = []
var novos_p2: Array = []
var joy_prev: Dictionary = {}
var ed_sel: int = 0
var ed_scroll: int = 0
var ed_msg: String = ""
var ko_timer: int = 0
var campo_golpe: LineEdit
var campo_pers: LineEdit

# ---------- Inicialização e dados ----------

func _ready() -> void:
	fonte = ThemeDB.fallback_font
	dados = _carregar()
	p1 = Personagem.new()
	p2 = Personagem.new()
	campo_golpe = _criar_campo(Vector2(620, 326), _on_nome_golpe)
	campo_pers = _criar_campo(Vector2(620, 376), _on_nome_pers)
	_reiniciar_luta()

func _criar_campo(pos: Vector2, cb: Callable) -> LineEdit:
	var c := LineEdit.new()
	c.position = pos
	c.size = Vector2(330, 30)
	c.visible = false
	c.text_changed.connect(cb)
	add_child(c)
	return c

func _carregar() -> Dictionary:
	if FileAccess.file_exists(ARQUIVO_SAVE):
		var txt: String = FileAccess.get_file_as_string(ARQUIVO_SAVE)
		var lido: Variant = JSON.parse_string(txt)
		var d: Dictionary = _validar_personagem(lido)
		if not d.is_empty():
			return d
	return {"nome": "Ash Crimson", "golpes": Personagem.golpes_padrao_ash()}

func _validar_personagem(v: Variant) -> Dictionary:
	if typeof(v) != TYPE_DICTIONARY:
		return {}
	if not v.has("golpes") or typeof(v["golpes"]) != TYPE_ARRAY:
		return {}
	var lidos: Array = []
	for g in v["golpes"]:
		if typeof(g) == TYPE_DICTIONARY:
			lidos.append(Personagem.normalizar_golpe(g))
	if lidos.is_empty():
		return {}
	return {"nome": str(v.get("nome", "Personagem")), "golpes": lidos}

func _salvar() -> void:
	var f := FileAccess.open(ARQUIVO_SAVE, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(dados))

func _reiniciar_luta() -> void:
	p1.definir_golpes(dados["golpes"])
	p2.definir_golpes(dados["golpes"])
	p1.resetar(300.0, true)
	p2.resetar(660.0, false)
	p1.oponente = p2
	p2.oponente = p1
	ko_timer = 0

# ---------- Toque ----------

func _input(event: InputEvent) -> void:
	var t := event as InputEventScreenTouch
	if t != null:
		var p := _para_tela(t.position)
		if t.pressed:
			_toque_inicio(t.index, p)
		else:
			_toque_fim(t.index)
		return
	var d := event as InputEventScreenDrag
	if d != null:
		_toque_arrasto(d.index, _para_tela(d.position))

func _para_tela(p: Vector2) -> Vector2:
	return get_viewport().get_final_transform().affine_inverse() * p

func _toque_inicio(idx: int, p: Vector2) -> void:
	if tela == Tela.EDITOR:
		_clique_editor(p)
		return
	if BOTAO_EDITOR.has_point(p):
		_abrir_editor()
		return
	if BOTAO_RESET.has_point(p):
		_reiniciar_luta()
		return
	if p.distance_to(DPAD_CENTRO) <= DPAD_RAIO * 1.3:
		toques[idx] = "dpad"
		toque_vec[idx] = _vec_dpad(p)
		return
	for b in BOTOES:
		var c := Vector2(b[1], b[2])
		if p.distance_to(c) <= RAIO_BOTAO * 1.2:
			toques[idx] = b[0]
			novos_p1.append(b[0])
			return

func _toque_arrasto(idx: int, p: Vector2) -> void:
	if toques.get(idx, "") == "dpad":
		toque_vec[idx] = _vec_dpad(p)

func _toque_fim(idx: int) -> void:
	toques.erase(idx)
	toque_vec.erase(idx)

func _vec_dpad(p: Vector2) -> Vector2:
	var v: Vector2 = (p - DPAD_CENTRO) / DPAD_RAIO
	return v.limit_length(1.0)

func _segurado(id: String) -> bool:
	for k in toques:
		if toques[k] == id:
			return true
	return false

# ---------- Entrada combinada (toque + controle) ----------

func _dir_p1() -> Vector2:
	var v := Vector2.ZERO
	for k in toque_vec:
		v = toque_vec[k]
	if v.length() < 0.2:
		v = _dir_joy(0)
	return v

func _dir_joy(dev: int) -> Vector2:
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

func _coletar_gamepads() -> void:
	for dev in [0, 1]:
		for m in JOY_MAPA:
			var chave := str(dev) + "_" + str(m[0])
			var agora: bool = Input.is_joy_button_pressed(dev, m[0])
			if agora and not bool(joy_prev.get(chave, false)):
				if dev == 0:
					novos_p1.append(m[1])
				else:
					novos_p2.append(m[1])
			joy_prev[chave] = agora

func _montar_apertados(lista: Array) -> Dictionary:
	var r := {}
	for b in lista:
		r[b] = true
	if r.has("LP") and r.has("LK"):
		r.erase("LP")
		r.erase("LK")
		r["ROLL"] = true
	if r.has("HP") and r.has("HK"):
		r.erase("HP")
		r.erase("HK")
		r["CD"] = true
	return r

# ---------- Loop ----------

func _physics_process(_delta: float) -> void:
	_coletar_gamepads()
	if tela == Tela.LUTA:
		_atualizar_luta()
	novos_p1.clear()
	novos_p2.clear()
	queue_redraw()

func _atualizar_luta() -> void:
	p1.atualizar(_dir_p1(), _montar_apertados(novos_p1))
	p2.atualizar(_dir_joy(1), _montar_apertados(novos_p2))
	_separar_corpos()
	_resolver_hit(p1, p2)
	_resolver_hit(p2, p1)
	_checar_combos()
	if p1.estado == Personagem.Estado.KO or p2.estado == Personagem.Estado.KO:
		ko_timer += 1
		if ko_timer > 150:
			_reiniciar_luta()

func _separar_corpos() -> void:
	if not p1.corpo_rect().intersects(p2.corpo_rect()):
		return
	var dx: float = p2.pos.x - p1.pos.x
	var sinal: float = 1.0 if dx >= 0.0 else -1.0
	var falta: float = 50.0 - absf(dx)
	if falta <= 0.0:
		return
	p1.pos.x -= sinal * falta * 0.5
	p2.pos.x += sinal * falta * 0.5

func _resolver_hit(atk, dfn) -> void:
	if not atk.hitbox_ativa() or atk.golpe_acertou:
		return
	var g: Dictionary = atk.golpe_atual
	if not Caixa.colidem(atk.hitbox_rect(), dfn.corpo_rect()):
		return
	var r: String = dfn.resultado_para(g)
	if r == "nada":
		return
	atk.golpe_acertou = true
	if r == "bloqueio":
		dfn.receber_bloqueio(g)
		return
	var escala: float = maxf(0.5, 1.0 - 0.1 * float(atk.combo))
	var dano: float = float(g["dano"]) * escala
	atk.combo += 1
	dfn.receber_acerto(g, dano)
	if str(g["carga"]) != "" and float(g["energia_ganha"]) > 0.0:
		atk.barra.ganhar(float(g["energia_ganha"]))

func _checar_combos() -> void:
	var neutros := [Personagem.Estado.PARADO, Personagem.Estado.ANDANDO, Personagem.Estado.PULANDO, Personagem.Estado.DEFENDENDO]
	if p2.estado in neutros:
		p1.combo = 0
	if p1.estado in neutros:
		p2.combo = 0

# ---------- Editor: abrir, fechar, importar ----------

func _abrir_editor() -> void:
	tela = Tela.EDITOR
	toques.clear()
	toque_vec.clear()
	novos_p1.clear()
	novos_p2.clear()
	campo_golpe.visible = true
	campo_pers.visible = true
	ed_msg = ""
	_atualizar_campos_editor()

func _fechar_editor() -> void:
	_salvar()
	campo_golpe.release_focus()
	campo_pers.release_focus()
	campo_golpe.visible = false
	campo_pers.visible = false
	tela = Tela.LUTA
	toques.clear()
	toque_vec.clear()
	_reiniciar_luta()

func _importar() -> void:
	var lido: Variant = JSON.parse_string(DisplayServer.clipboard_get())
	var d: Dictionary = _validar_personagem(lido)
	if d.is_empty():
		ed_msg = "A area de transferencia nao tem um personagem valido."
		return
	dados = d
	ed_sel = 0
	ed_scroll = 0
	ed_msg = "Personagem importado: " + str(d["nome"])
	_atualizar_campos_editor()

func _atualizar_campos_editor() -> void:
	var golpes: Array = dados["golpes"]
	if golpes.is_empty():
		return
	ed_sel = clampi(ed_sel, 0, golpes.size() - 1)
	campo_golpe.text = str(golpes[ed_sel]["nome"])
	campo_pers.text = str(dados["nome"])

func _ajustar_scroll() -> void:
	if ed_sel < ed_scroll:
		ed_scroll = ed_sel
	if ed_sel >= ed_scroll + VISIVEIS:
		ed_scroll = ed_sel - VISIVEIS + 1

func _on_nome_golpe(t: String) -> void:
	var golpes: Array = dados["golpes"]
	golpes[ed_sel]["nome"] = t

func _on_nome_pers(t: String) -> void:
	dados["nome"] = t

# ---------- Editor: cliques ----------

func _clique_editor(p: Vector2) -> void:
	if ED_FECHAR.has_point(p):
		_fechar_editor()
		return
	if ED_EXPORTAR.has_point(p):
		DisplayServer.clipboard_set(JSON.stringify(dados, "  "))
		ed_msg = "Personagem copiado para a area de transferencia."
		return
	if ED_IMPORTAR.has_point(p):
		_importar()
		return
	var golpes: Array = dados["golpes"]
	for i in range(ed_scroll, mini(golpes.size(), ed_scroll + VISIVEIS)):
		if Rect2(10, 52 + (i - ed_scroll) * 26, 240, 24).has_point(p):
			ed_sel = i
			_atualizar_campos_editor()
			return
	if ED_NOVO.has_point(p):
		golpes.insert(ed_sel + 1, Personagem.golpe_padrao())
		ed_sel += 1
	elif ED_COPIA.has_point(p):
		var copia: Dictionary = Personagem.normalizar_golpe(golpes[ed_sel])
		copia["nome"] = str(copia["nome"]) + " (copia)"
		golpes.insert(ed_sel + 1, copia)
		ed_sel += 1
	elif ED_APAGA.has_point(p):
		if golpes.size() > 1:
			golpes.remove_at(ed_sel)
			ed_sel = clampi(ed_sel, 0, golpes.size() - 1)
		else:
			ed_msg = "Precisa existir pelo menos 1 golpe."
	elif ED_SOBE.has_point(p) and ed_sel > 0:
		_trocar(ed_sel, ed_sel - 1)
		ed_sel -= 1
	elif ED_DESCE.has_point(p) and ed_sel < golpes.size() - 1:
		_trocar(ed_sel, ed_sel + 1)
		ed_sel += 1
	else:
		_clique_campo(p)
		return
	_ajustar_scroll()
	_atualizar_campos_editor()

func _trocar(a: int, b: int) -> void:
	var golpes: Array = dados["golpes"]
	var t = golpes[a]
	golpes[a] = golpes[b]
	golpes[b] = t

func _clique_campo(p: Vector2) -> void:
	var golpes: Array = dados["golpes"]
	var g: Dictionary = golpes[ed_sel]
	for i in CAMPOS.size():
		var c: Array = CAMPOS[i]
		var y: int = 52 + i * 24
		if Rect2(530, y, 30, 22).has_point(p):
			_mudar_campo(g, c, -1)
			return
		if Rect2(565, y, 30, 22).has_point(p):
			_mudar_campo(g, c, 1)
			return

func _mudar_campo(g: Dictionary, c: Array, delta: int) -> void:
	var chave: String = str(c[0])
	var tipo: String = str(c[2])
	var atual = _get_valor(g, chave)
	var novo
	match tipo:
		"lista":
			var opts: Array = c[3]
			novo = opts[posmod(opts.find(atual) + delta, opts.size())]
		"bool":
			novo = not bool(atual)
		"int":
			novo = clampi(int(atual) + delta * int(c[3]), int(c[4]), int(c[5]))
		"float":
			novo = clampf(float(atual) + delta * float(c[3]), float(c[4]), float(c[5]))
	_set_valor(g, chave, novo)

func _get_valor(g: Dictionary, chave: String) -> Variant:
	if chave.begins_with("hb_"):
		return g["hitbox"][chave.substr(3)]
	return g[chave]

func _set_valor(g: Dictionary, chave: String, v) -> void:
	if chave.begins_with("hb_"):
		g["hitbox"][chave.substr(3)] = v
	else:
		g[chave] = v

func _fmt(c: Array, v) -> String:
	var tipo: String = str(c[2])
	if tipo == "bool":
		return "SIM" if bool(v) else "NAO"
	if tipo == "float":
		return ("%.0f" if float(c[3]) >= 1.0 else "%.1f") % float(v)
	if tipo == "int":
		return str(int(v))
	return str(v)

# ---------- Desenho ----------

func _draw() -> void:
	if tela == Tela.EDITOR:
		_desenhar_editor()
	else:
		_desenhar_luta()

func _texto(pos: Vector2, txt: String, tam: int, cor: Color) -> void:
	draw_string(fonte, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1.0, tam, cor)

func _texto_centro(r: Rect2, txt: String, tam: int, cor: Color) -> void:
	draw_string(fonte, Vector2(r.position.x, r.position.y + r.size.y * 0.5 + tam * 0.35), txt, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, tam, cor)

func _botao(r: Rect2, txt: String, sel: bool = false) -> void:
	draw_rect(r, Color(0.3, 0.3, 0.5) if sel else Color(0.18, 0.18, 0.25))
	draw_rect(r, Color(0.8, 0.8, 1.0), false, 1.0)
	_texto_centro(r, txt, 14, Color.WHITE)

func _desenhar_luta() -> void:
	draw_rect(Rect2(0, 0, 960, 540), Color(0.06, 0.06, 0.1))
	draw_rect(Rect2(0, Personagem.CHAO_Y, 960, 60), Color(0.2, 0.2, 0.25))
	_desenhar_personagem(p1, Color(0.2, 0.5, 1.0))
	_desenhar_personagem(p2, Color(1.0, 0.45, 0.1))
	_desenhar_hud()
	_desenhar_controles()
	if p1.estado == Personagem.Estado.KO or p2.estado == Personagem.Estado.KO:
		_texto_centro(Rect2(0, 200, 960, 80), "K.O.", 56, Color.RED)

func _desenhar_personagem(p, cor: Color) -> void:
	var corpo: Rect2 = p.corpo_rect()
	draw_rect(corpo, cor)
	draw_rect(corpo, Color.WHITE, false, 2.0)
	if p.hitbox_ativa():
		draw_rect(p.hitbox_rect(), Color(1.0, 0