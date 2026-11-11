extends RefCounted

# Lista fixa dos eventos de som do personagem e dos sons comuns.
# O nome do arquivo é o nome do evento. Ex.: personagens/boneco_treino_1/sons/voz_dano_leve.ogg

const TODOS := [
	"ataque_leve", "ataque_forte", "ataque_especial",
	"voz_ataque_leve", "voz_ataque_forte",
	"voz_dano_leve", "voz_dano_forte",
	"voz_queda", "voz_morte",
	"bloqueio", "impacto_leve", "impacto_forte",
	"pulo", "pouso", "passo", "esquiva", "levantar",
	"vitoria", "derrota", "parry", "guarda_quebrada",
]

# Sons da interface (menu). Ficam em sons/interface/.
const INTERFACE := ["menu_mover", "menu_confirma", "menu_voltar", "start", "selecao_mover", "selecao_confirma"]


static func valido(nome: String) -> bool:
	return TODOS.has(nome)