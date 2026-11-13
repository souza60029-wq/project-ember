# Onde colocar as artes (Ember)

Tudo é opcional: sem arte, a engine desenha formas simples no lugar.

## Telas iniciais (nesta ordem)
| Tela | Arquivo | Observação |
|---|---|---|
| 1. "Feito com Ember Engine" | `ui/ember/fundo.png` + `ui/ember/logo.png` | As duas imagens juntas formam a tela: o fundo ocupa a tela toda e a logo fica centralizada por cima. Separadas para você usar em outras telas. |
| 2. Título + AVISO | `ui/fundo_titulo.png` | Arte de fundo da tela "toque na tela / aperte start". O aviso de projeto de fã aparece em um painel escuro sobre a arte (texto em `engine/config/Textos.gd`, chaves `aviso_titulo` e `aviso_corpo`). |
| 3. Menu | veja abaixo | |

## Menu (centro inferior, ícones; esquerda/direita troca de menu, cima/baixo troca de submenu)
Menus: Online, Local (Arcade, Versus, Treino), História, Editar (Criar personagem, Editar personagem), Colecionáveis.
- **Fundo em 4 camadas** (PNGs com transparência, do tamanho da tela inteira, em `ui/menu/`; a ordem é de baixo para cima):
  1. `camada1_fundo.png` - fundo da tela inicial
  2. `camada2_movimento.png` - algo com movimento (rola na horizontal e repete)
  3. `personagem_online.png`, `personagem_local.png`, `personagem_historia.png`, `personagem_editar.png`, `personagem_colecionaveis.png` - arte do personagem; **só esta camada muda com o menu** (desliza na troca)
  4. `camada4_borda.png` - borda por cima de tudo
  - **Sprites em qualquer camada:** em vez de um arquivo, use uma sequência `nome_1.png`, `nome_2.png`, `nome_3.png`... (ex.: `camada2_movimento_1.png`, `personagem_local_1.png`). Toca em loop a 12 FPS (`CAMADAS_FPS` no `Menu.gd`).
  - Sem as camadas, usa o fundo antigo `fundo_<menu>.png`. A música do menu é aleatória (veja `sons/interface/LEIA-ME.md`).
- Ícones (se não existirem, a engine desenha um): `ui/menu/icone_online.png`, `icone_local.png`, `icone_historia.png`, `icone_editar.png`, `icone_colecionaveis.png`
- Ícones dos submenus: `ui/menu/icone_arcade.png`, `icone_versus.png`, `icone_treino.png`, `icone_criar.png`, `icone_editar.png`
- Ícone de configurações (canto superior esquerdo): `ui/menu/icone_config.png`. Em modo controle aparece o ícone do botão START ao lado.
- Disco de música (canto superior direito): desenhado em código. No controle, o botão SELECT abre a bolha e muta.

## Seleção de personagens
`ui/selecao/fundo.png`, `moldura_card.png`, `cursor_p1.png`, `cursor_p2.png`. As artes de cada personagem ficam na pasta dele: `arte/selecao.png` (grande) e `arte/card.png` (card).

## Ícones de botão do controle
`ui/glifos/xbox_A.png`, `ps_A.png`, ... Tipos: A B X Y START SELECT LB RB DPAD DPAD_LR.

Sprites: alinhados pelo **centro dos pés** (meio da base da imagem), virados para a **direita**.
