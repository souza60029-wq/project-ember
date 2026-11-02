extends Node

# Textos do motor: menu, configurações e botões fixos.
# Cada chave tem português (pt) e inglês (en).

const TABELA := {
	"aba_multiplayer": {"pt": "Multiplayer", "en": "Multiplayer"},
	"aba_local": {"pt": "Local", "en": "Local"},
	"aba_personagem": {"pt": "Personagem", "en": "Character"},
	"mp_local": {"pt": "Local", "en": "Local"},
	"mp_online": {"pt": "On-line", "en": "Online"},
	"sub_arcade": {"pt": "Arcade", "en": "Arcade"},
	"sub_historia": {"pt": "História", "en": "Story"},
	"sub_treino": {"pt": "Treino", "en": "Training"},
	"sub_criar": {"pt": "Criar personagem", "en": "Create character"},
	"sub_editar": {"pt": "Editar personagem", "en": "Edit character"},
	"cfg_titulo": {"pt": "Configurações", "en": "Settings"},
	"cfg_graficos": {"pt": "Gráficos", "en": "Graphics"},
	"cfg_luta": {"pt": "Luta", "en": "Fight"},
	"cfg_controle": {"pt": "Controle", "en": "Input"},
	"cfg_idioma": {"pt": "Idioma", "en": "Language"},
	"cfg_modo": {"pt": "Modo de entrada", "en": "Input mode"},
	"cfg_mapa": {"pt": "Mapeamento de botões", "en": "Button mapping"},
	"modo_automatico": {"pt": "Automático", "en": "Automatic"},
	"modo_touch": {"pt": "Toque", "en": "Touch"},
	"modo_controle": {"pt": "Controle", "en": "Controller"},
	"modo_ativo": {"pt": "Modo ativo", "en": "Active mode"},
	"idioma_pt": {"pt": "Português", "en": "Português"},
	"idioma_en": {"pt": "English", "en": "English"},
	"voltar": {"pt": "Voltar", "en": "Back"},
	"em_breve": {"pt": "Em breve", "en": "Coming soon"},
	"menu_luta": {"pt": "MENU", "en": "MENU"},
	"dica_menu": {
		"pt": "Setas: escolher | A: confirmar | B: voltar | Toque também funciona",
		"en": "Arrows: choose | A: confirm | B: back | Touch also works",
	},
}


# Devolve o texto no idioma atual. Se a chave não existir, devolve a própria chave.
func t(chave: String) -> String:
	if not TABELA.has(chave):
		return chave
	var par: Dictionary = TABELA[chave]
	return str(par.get(Config.idioma, par.get("pt", chave)))