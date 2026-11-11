extends Control

# Tela de configurações (estilo menu de jogo): categorias à esquerda, opções à direita.
# Toque: toque na categoria e na opção (seta esquerda/direita do valor muda). Controle: cima/baixo
# move, esquerda/direita (direcional ou analógico) muda o valor, A entra, B volta, START fecha.
# Mapa de botões: um para o Jogador 1 e outro para o Jogador 2. O do Jogador 2 só muda
# com o segundo controle.
# Autoloads são acessados por get_node (não pelo nome), para o script compilar sem eles.

signal fechado

const Glifos = preload("res://engine/nucleo/Glifos.gd")

const VIEW_W := 960.0
const VIEW_H := 540.0
const CATS := ["cfg_jogo", "cfg_tela", "cfg_controles"]
const R_CATS := Rect2(28.0, 104.0, 220.0, 300.0)
const R_PAINEL := Rect2(268.0, 104.0, 664.0, 372.0)
const ALT_CAT := 58.0
const ALT_LINHA := 46.0
const LIMIAR_STICK := 0.6
const COR_FUNDO := Color(0.035, 0.04, 0.08, 0.97)
const COR_DESTAQUE := Color(1.0, 0.55, 0.2)
const COR_PAINEL := Color(0.08, 0.09, 0.16)
const COR_TEXTO := Color(0.94, 0.94, 1.0)
const COR_SUAVE := Color(0.62, 0.65, 0.8)

var _cat: int = 0
var _col: int = 0 # 0 = categorias, 1 = opções
var _linha: int = 0
var _sub: int = 0 # 0 = lista; 1 e 2 = mapa de botões do jogador 1 / 2
var _eixo_estado := {}
var _msg: String = ""
var _msg_t: float = 0.0
var _rect_voltar := Rect2(28.0, 486.0, 150.0, 40.0)


func _config() -> Variant:
	return get_node("/root/Config")

func _t(chave: String) -> String:
	return str(get_node("/root/Textos").t(chave))

func _som(nome: String) -> void:
	get_node("/root/Audio").tocar_interface(nome)

func _modo_controle() -> bool:
	return str(_config().modo_efetivo()) == "controle"


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if _msg_t > 0.0:
		_msg_t -= delta
	queue_redraw()


# ---------- Conteúdo ----------

func _rot_funcao(f: String) -> String:
	return _t("fn_" + f) if f != "" else _t("fn_nenhuma")

func _lig(b: bool) -> String:
	return _t("ligado") if b else _t("desligado")

# Cada linha: id, rotulo, valor, tipo ("escolha" muda com esquerda/direita; "acao" abre; "info" só mostra).
func _linhas() -> Array:
	var cfg: Variant = _config()
	var r: Array = []
	if _sub > 0:
		var m: Dictionary = cfg.mapa(_sub)
		for b in cfg.BOTOES_FISICOS:
			r.append({"id": "b:" + str(b), "tipo": "mapa", "botao": str(b), "rotulo": str(b), "valor": _rot_funcao(str(m.get(b, "")))})
		r.append({"id": "restaurar", "tipo": "acao", "rotulo": _t("mapa_restaurar"), "valor": ""})
		return r
	match _cat:
		0:
			r.append({"id": "idioma", "tipo": "escolha", "rotulo": _t("opt_idioma"), "valor": _t("idioma_" + str(cfg.idioma))})
			r.append({"id": "debug", "tipo": "escolha", "rotulo": _t("opt_debug"), "valor": _lig(bool(cfg.debug_hitboxes))})
		1:
			r.append({"id": "rotacao", "tipo": "escolha", "rotulo": _t("opt_rotacao"), "valor": _t("rot_" + str(cfg.rotacao))})
			r.append({"id": "hud", "tipo": "escolha", "rotulo": _t("opt_hud"), "valor": _t("hud_" + str(cfg.hud_modo))})
		2:
			r.append({"id": "modo", "tipo": "escolha", "rotulo": _t("opt_modo_entrada"), "valor": _t("modo_" + str(cfg.modo_escolhido))})
			var nome: String = str(cfg.controle_nome) if bool(cfg.controle_conectado) else "-"
			r.append({"id": "info", "tipo": "info", "rotulo": _t("ctrl_nome"), "valor": nome})
			r.append({"id": "mapa1", "tipo": "acao", "rotulo": _t("opt_mapa_p1"), "valor": ""})
			r.append({"id": "mapa2", "tipo": "acao", "rotulo": _t("opt_mapa_p2"), "valor": ""})
	return r


func _ciclo(lista: Array, atual: String, d: int) -> String:
	var i: int = lista.find(atual)
	return str(lista[posmod(i + d, lista.size())])


# Jogador 2 só muda com o segundo controle (dispositivo 1).
func _pode_editar_mapa(dev: int) -> bool:
	if _sub == 2 and dev != 1:
		_aviso(_t("mapa_p2_aviso") if Input.get_connected_joypads().size() >= 2 else _t("mapa_p2_sem"))
		return false
	return true


func _aviso(t: String) -> void:
	_msg = t
	_msg_t = 3.0


func _mudar(d: int, dev: int) -> void:
	var l: Array = _linhas()
	if l.is_empty():
		return
	var it: Dictionary = l[clampi(_linha, 0, l.size() - 1)]
	var cfg: Variant = _config()
	var id: String = str(it["id"])
	if id.begins_with("b:"):
		if not _pode_editar_mapa(dev):
			return
		var botao: String = id.substr(2)
		var atual: String = str((cfg.mapa(_sub) as Dictionary).get(botao, ""))
		cfg.definir_funcao(_sub, botao, _ciclo(cfg.FUNCOES, atual, d))
		_som("menu_mover")
		return
	match id:
		"idioma":
			cfg.definir_idioma(_ciclo(cfg.IDIOMAS, str(cfg.idioma), d))
		"debug":
			cfg.definir_debug(not bool(cfg.debug_hitboxes))
		"rotacao":
			cfg.definir_rotacao(_ciclo(cfg.ROTACOES, str(cfg.rotacao), d))
		"hud":
			cfg.definir_hud(_ciclo(cfg.HUD_MODOS, str(cfg.hud_modo), d))
		"modo":
			cfg.definir_modo(_ciclo(cfg.MODOS, str(cfg.modo_escolhido), d))
		_:
			return
	_som("menu_mover")


func _acionar(dev: int) -> void:
	var l: Array = _linhas()
	if l.is_empty():
		return
	var it: Dictionary = l[clampi(_linha, 0, l.size() - 1)]
	match str(it["tipo"]):
		"escolha", "mapa":
			_mudar(1, dev)
		"acao":
			match str(it["id"]):
				"mapa1":
					_sub = 1
					_linha = 0
					_som("menu_confirma")
				"mapa2":
					_sub = 2
					_linha = 0
					_som("menu_confirma")
				"restaurar":
					if _pode_editar_mapa(dev):
						_config().restaurar_mapa(_sub)
						_som("menu_confirma")


func _voltar() -> void:
	_som("menu_voltar")
	if _sub > 0:
		_linha = 2 if _sub == 1 else 3
		_sub = 0
	elif _col == 1:
		_col = 0
	else:
		fechado.emit()
		queue_free()


func _mover(d: int) -> void:
	if _col == 0 and _sub == 0:
		var novo: int = clampi(_cat + d, 0, CATS.size() - 1)
		if novo != _cat:
			_cat = novo
			_linha = 0
			_som("menu_mover")
	else:
		var n: int = _linhas().size()
		var novo2: int = clampi(_linha + d, 0, n - 1)
		if novo2 != _linha:
			_linha = novo2
			_som("menu_mover")


# ---------- Entrada ----------

func _unhandled_input(ev: InputEvent) -> void:
	var st := ev as InputEventScreenTouch
	if st != null and st.pressed:
		_tocar(st.position)
		get_viewport().set_input_as_handled()
		return
	var bt := ev as InputEventJoypadButton
	if bt != null and bt.pressed:
		_botao(int(bt.button_index), bt.device)
		get_viewport().set_input_as_handled()
		return
	var jm := ev as InputEventJoypadMotion
	if jm != null:
		_analogico(jm)
		get_viewport().set_input_as_handled()


func _analogico(ev: InputEventJoypadMotion) -> void:
	var eixo: int = ev.axis
	if eixo != JOY_AXIS_LEFT_X and eixo != JOY_AXIS_LEFT_Y:
		return
	var v: float = ev.axis_value
	var agora: int = 0
	if v > LIMIAR_STICK:
		agora = 1
	elif v < -LIMIAR_STICK:
		agora = -1
	var chave: int = eixo + 10 * ev.device
	var antes: int = int(_eixo_estado.get(chave, 0))
	_eixo_estado[chave] = agora
	if agora == 0 or agora == antes:
		return
	if eixo == JOY_AXIS_LEFT_X:
		_botao(JOY_BUTTON_DPAD_RIGHT if agora > 0 else JOY_BUTTON_DPAD_LEFT, ev.device)
	else:
		_botao(JOY_BUTTON_DPAD_DOWN if agora > 0 else JOY_BUTTON_DPAD_UP, ev.device)


func _botao(b: int, dev: int) -> void:
	match b:
		JOY_BUTTON_START:
			_som("menu_voltar")
			fechado.emit()
			queue_free()
		JOY_BUTTON_B:
			_voltar()
		JOY_BUTTON_DPAD_UP:
			_mover(-1)
		JOY_BUTTON_DPAD_DOWN:
			_mover(1)
		JOY_BUTTON_DPAD_RIGHT:
			if _col == 0 and _sub == 0:
				_col = 1
				_linha = 0
			else:
				_mudar(1, dev)
		JOY_BUTTON_DPAD_LEFT:
			if _col == 1 or _sub > 0:
				_mudar(-1, dev)
		JOY_BUTTON_A:
			if _col == 0 and _sub == 0:
				_col = 1
				_linha = 0
				_som("menu_confirma")
			else:
				_acionar(dev)
		JOY_BUTTON_LEFT_SHOULDER:
			if _sub == 0:
				_col = 0
				_mover(-1)
		JOY_BUTTON_RIGHT_SHOULDER:
			if _sub == 0:
				_col = 0
				_mover(1)


func _rect_linha(j: int) -> Rect2:
	return Rect2(R_PAINEL.position.x + 12.0, R_PAINEL.position.y + 56.0 + float(j) * ALT_LINHA, R_PAINEL.size.x - 24.0, ALT_LINHA - 6.0)


func _tocar(p: Vector2) -> void:
	if _rect_voltar.has_point(p):
		_voltar()
		return
	if _sub == 0:
		for i in range(CATS.size()):
			if Rect2(R_CATS.position.x, R_CATS.position.y + float(i) * ALT_CAT, R_CATS.size.x, ALT_CAT - 6.0).has_point(p):
				_cat = i
				_col = 0
				_linha = 0
				_som("menu_mover")
				return
	var n: int = _linhas().size()
	for j in range(n):
		var r: Rect2 = _rect_linha(j)
		if r.has_point(p):
			_col = 1
			_linha = j
			var it: Dictionary = _linhas()[j]
			if str(it["tipo"]) == "escolha" or str(it["tipo"]) == "mapa":
				# Metade esquerda do valor volta, o resto avança.
				var meio: float = r.end.x - 170.0
				_mudar(-1 if (p.x > r.end.x - 330.0 and p.x < meio) else 1, -1)
			else:
				_acionar(-1)
			return


# ---------- Desenho ----------

func _draw() -> void:
	var fonte: Font = ThemeDB.fallback_font
	draw_rect(Rect2(0.0, 0.0, VIEW_W, VIEW_H), COR_FUNDO)
	# Cabeçalho
	draw_rect(Rect2(0.0, 0.0, VIEW_W, 84.0), Color(0.07, 0.08, 0.15))
	draw_rect(Rect2(0.0, 82.0, VIEW_W, 3.0), COR_DESTAQUE)
	_engrenagem(Vector2(52.0, 42.0), 18.0)
	draw_string(fonte, Vector2(86.0, 54.0), _t("cfg_titulo").to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 30, COR_TEXTO)
	_cats()
	_painel()
	_rodape()
	if _msg_t > 0.0:
		draw_string(fonte, Vector2(R_PAINEL.position.x, R_PAINEL.end.y + 22.0), _msg, HORIZONTAL_ALIGNMENT_LEFT, R_PAINEL.size.x, 14, Color(1.0, 0.8, 0.4))


func _engrenagem(c: Vector2, r: float) -> void:
	draw_arc(c, r * 0.6, 0.0, TAU, 20, COR_DESTAQUE, 4.0)
	for i in range(8):
		var a: float = float(i) * TAU / 8.0
		draw_line(c + Vector2(cos(a), sin(a)) * r * 0.7, c + Vector2(cos(a), sin(a)) * r, COR_DESTAQUE, 5.0)


func _cats() -> void:
	var fonte: Font = ThemeDB.fallback_font
	for i in range(CATS.size()):
		var r := Rect2(R_CATS.position.x, R_CATS.position.y + float(i) * ALT_CAT, R_CATS.size.x, ALT_CAT - 6.0)
		var sel: bool = i == _cat
		draw_rect(r, COR_PAINEL if not sel else Color(0.16, 0.12, 0.1))
		if sel:
			draw_rect(Rect2(r.position, Vector2(6.0, r.size.y)), COR_DESTAQUE)
			if _col == 0 and _sub == 0:
				draw_rect(r, COR_DESTAQUE, false, 2.0)
		draw_string(fonte, Vector2(r.position.x + 22.0, r.position.y + r.size.y * 0.5 + 8.0), _t(str(CATS[i])), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 30.0, 20, COR_TEXTO if sel else COR_SUAVE)


func _painel() -> void:
	var fonte: Font = ThemeDB.fallback_font
	draw_rect(R_PAINEL, COR_PAINEL)
	draw_rect(R_PAINEL, Color(1, 1, 1, 0.12), false, 1.0)
	var titulo: String = _t(str(CATS[_cat]))
	if _sub > 0:
		titulo = _t("mapa_titulo_p%d" % _sub)
	draw_string(fonte, Vector2(R_PAINEL.position.x + 20.0, R_PAINEL.position.y + 34.0), titulo, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 22, COR_DESTAQUE)
	if _sub > 0:
		var dica: String = _t("mapa_dica")
		if _sub == 2:
			dica = _t("mapa_p2_aviso") if Input.get_connected_joypads().size() >= 2 else _t("mapa_p2_sem")
		draw_string(fonte, Vector2(R_PAINEL.position.x + 300.0, R_PAINEL.position.y + 32.0), dica, HORIZONTAL_ALIGNMENT_RIGHT, R_PAINEL.size.x - 320.0, 12, COR_SUAVE)
	var l: Array = _linhas()
	var ps: bool = bool(_config().controle_ps())
	for j in range(l.size()):
		var it: Dictionary = l[j]
		var r: Rect2 = _rect_linha(j)
		var foco: bool = _col == 1 and j == _linha
		draw_rect(r, Color(0.14, 0.12, 0.1) if foco else Color(1, 1, 1, 0.03 if j % 2 == 0 else 0.0))
		if foco:
			draw_rect(r, COR_DESTAQUE, false, 2.0)
		var cy: float = r.position.y + r.size.y * 0.5
		var tipo: String = str(it["tipo"])
		if tipo == "mapa":
			Glifos.desenhar(self, str(it["botao"]), Vector2(r.position.x + 40.0, cy), 13.0, ps)
			draw_string(fonte, Vector2(r.position.x + 76.0, cy + 7.0), str(it["botao"]), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 17, COR_SUAVE)
		else:
			draw_string(fonte, Vector2(r.position.x + 18.0, cy + 7.0), str(it["rotulo"]), HORIZONTAL_ALIGNMENT_LEFT, r.size.x * 0.5, 18, COR_TEXTO)
		if tipo == "escolha" or tipo == "mapa":
			_seletor(r, cy, str(it["valor"]), foco)
		elif tipo == "info":
			draw_string(fonte, Vector2(r.end.x - 330.0, cy + 7.0), str(it["valor"]), HORIZONTAL_ALIGNMENT_RIGHT, 316.0, 16, COR_SUAVE)
		elif tipo == "acao":
			var mx: float = r.end.x - 24.0
			draw_colored_polygon(PackedVector2Array([Vector2(mx - 10.0, cy - 8.0), Vector2(mx, cy), Vector2(mx - 10.0, cy + 8.0)]), COR_SUAVE)


# Valor com setas  <  valor  > .
func _seletor(r: Rect2, cy: float, valor: String, foco: bool) -> void:
	var fonte: Font = ThemeDB.fallback_font
	var cor: Color = COR_DESTAQUE if foco else COR_SUAVE
	var xe: float = r.end.x - 330.0
	var xd: float = r.end.x - 18.0
	draw_colored_polygon(PackedVector2Array([Vector2(xe + 10.0, cy - 8.0), Vector2(xe, cy), Vector2(xe + 10.0, cy + 8.0)]), cor)
	draw_colored_polygon(PackedVector2Array([Vector2(xd - 10.0, cy - 8.0), Vector2(xd, cy), Vector2(xd - 10.0, cy + 8.0)]), cor)
	draw_string(fonte, Vector2(xe + 14.0, cy + 7.0), valor, HORIZONTAL_ALIGNMENT_CENTER, xd - xe - 28.0, 18, COR_TEXTO)


func _rodape() -> void:
	var fonte: Font = ThemeDB.fallback_font
	draw_rect(Rect2(0.0, 500.0, VIEW_W, 40.0), Color(0.07, 0.08, 0.15))
	if not _modo_controle():
		draw_rect(_rect_voltar, Color(0.14, 0.12, 0.1))
		draw_rect(_rect_voltar, COR_DESTAQUE, false, 2.0)
		draw_string(fonte, Vector2(_rect_voltar.position.x, _rect_voltar.position.y + 27.0), _t("voltar"), HORIZONTAL_ALIGNMENT_CENTER, _rect_voltar.size.x, 18, COR_TEXTO)
		return
	var ps: bool = bool(_config().controle_ps())
	var x: float = 40.0
	var itens: Array = [["DPAD", "dica_mover"], ["DPAD_LR", "dica_alterar"], ["A", "dica_selecionar"], ["B", "dica_voltar"], ["START", "dica_fechar"]]
	for it in itens:
		var par: Array = it
		Glifos.desenhar(self, str(par[0]), Vector2(x + 12.0, 520.0), 11.0, ps)
		var rot: String = _t(str(par[1]))
		draw_string(fonte, Vector2(x + 34.0, 526.0), rot, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, COR_TEXTO)
		x += 70.0 + rot.length() * 8.0
