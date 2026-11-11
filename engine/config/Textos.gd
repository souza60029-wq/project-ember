extends Node

# Textos do motor: menu, configurações, título e botões fixos.
# Cada chave tem português (pt) e inglês (en).

const TABELA := {
	"menu_online": {"pt": "Online", "en": "Online"},
	"menu_local": {"pt": "Local", "en": "Local"},
	"menu_historia": {"pt": "História", "en": "Story"},
	"menu_editar": {"pt": "Editar", "en": "Edit"},
	"menu_colecionaveis": {"pt": "Colecionáveis", "en": "Collectibles"},
	"sub_versus": {"pt": "Versus", "en": "Versus"},
	"sub_criar_personagem": {"pt": "Criar personagem", "en": "Create character"},
	"sub_editar_personagem": {"pt": "Editar personagem", "en": "Edit character"},
	"musica_tocando": {"pt": "Tocando", "en": "Now playing"},
	"musica_mutar": {"pt": "Mutar", "en": "Mute"},
	"musica_ativar": {"pt": "Ativar som", "en": "Unmute"},
	"aviso_titulo": {"pt": "AVISO", "en": "NOTICE"},
	"aviso_corpo": {
		"pt": "Este jogo é um projeto de fã, feito sem fins lucrativos.\n\nO criador do jogo não é dono dos personagens, músicas, nomes e demais obras que possam aparecer aqui, e não possui os direitos sobre eles. Todos os direitos pertencem aos seus respectivos titulares, e nenhuma ligação ou apoio deles é afirmado.\n\nAs artes geradas com inteligência artificial usadas neste jogo também não são de propriedade do criador.\n\nA Ember Engine é apenas uma engine (motor) para criar jogos de luta. Ela não contém nem distribui personagens, músicas ou artes de terceiros: tudo o que aparece no jogo foi adicionado por quem o criou.\n\nSe você é titular de algum direito e deseja a remoção de um conteúdo, fale com o criador do jogo.",
		"en": "This game is a fan project, made without profit.\n\nThe game's creator does not own the characters, music, names or other works that may appear here, and does not hold the rights to them. All rights belong to their respective owners, and no connection or endorsement from them is claimed.\n\nThe AI-generated artwork used in this game is also not owned by the creator.\n\nEmber Engine is only an engine for making fighting games. It does not contain or distribute third-party characters, music or art: everything shown in the game was added by whoever made it.\n\nIf you own a right and want some content removed, please contact the game's creator."
	},
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