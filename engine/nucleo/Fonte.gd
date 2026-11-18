extends RefCounted

# Fonte do jogo.
# 1) Se existir um letrário seu em user://fonte/letrario.fnt (exportado pelo Ember Forja), ele é usado.
#    No iPhone: Arquivos > No meu iPhone > Ember > fonte (copie letrario.fnt e letrario_0.png para lá).
# 2) Senão, usa ui/fonte/principal.ttf (Big Shoulders Bold, licença OFL em ui/fonte/LICENCA-OFL.txt).
# 3) Senão, fica a fonte padrão do Godot.

const LETRARIO := "user://fonte/letrario.fnt"
const PASTA_LETRARIO := "user://fonte/"
const TTF := "res://ui/fonte/principal.ttf"


static func carregar() -> Font:
	var base: Font = null
	if ResourceLoader.exists(TTF) or FileAccess.file_exists(TTF):
		base = load(TTF) as Font
	if FileAccess.file_exists(LETRARIO):
		var f := FontFile.new()
		if f.load_bitmap_font(LETRARIO) == OK:
			if "fixed_size_scale_mode" in f:
				f.set("fixed_size_scale_mode", 1)
			if base != null:
				f.fallbacks = [base]
			return f
		push_warning("Ember: o letrário em %s não pôde ser lido." % LETRARIO)
	return base


# Aplica a fonte a todo o jogo (textos desenhados em código e Controls).
static func aplicar(raiz: Window) -> void:
	DirAccess.make_dir_recursive_absolute(PASTA_LETRARIO)
	var f: Font = carregar()
	if f == null:
		return
	ThemeDB.fallback_font = f
	var tema := Theme.new()
	tema.default_font = f
	raiz.theme = tema
