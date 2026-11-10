extends Node

# Textos do motor: menu, configurações, título e botões fixos.
# Cada chave tem português (pt) e inglês (en).

const TABELA := {
	"aba_multiplayer": {"pt": "Multiplayer", "en": "Multiplayer"},
	"aba_local": {"pt": "Local", "en": "Local"},
	"aba_personagem": {"pt": "Personagem", "en": "Character"},
	"mp_local": {"pt": "Local", "en": "Local"},
	"mp_online": {"pt": "On-line", "en": "Online"},
	"sub_arcade": {"pt": "Arcade", "en": "Arcade"},
	"sub_classico": {"pt": "Clássico", "en": "Classic"},
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
	"tela_toque": {"pt": "TOQUE NA TELA", "en": "TOUCH THE SCREEN"},
	"tela_start": {"pt": "APERTE START", "en": "PRESS START"},
	"cfg_debug": {"pt": "Modo debug (hitboxes)", "en": "Debug mode (hitboxes)"},
	"dica_confirmar": {"pt": "Confirmar", "en": "Confirm"},
	"dica_voltar": {"pt": "Voltar", "en": "Back"},
	"dica_mover": {"pt": "Mover", "en": "Move"},
	"dica_trocar": {"pt": "Trocar menu", "en": "Switch menu"},
	"dica_toque": {"pt": "Toque para escolher", "en": "Tap to choose"},
	"sel_player1": {"pt": "JOGADOR 1", "en": "PLAYER 1"},
	"sel_player2": {"pt": "JOGADOR 2", "en": "PLAYER 2"},
	"sel_vazio": {"pt": "Nenhum personagem. Crie um em Personagem > Criar.", "en": "No characters yet. Create one in Character > Create."},
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