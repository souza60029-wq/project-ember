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
- **Fundo em 4 camadas** (imagens com transparência, em `ui/menu/`; ordem de baixo para cima):
  1. `camada1_fundo` - fundo da tela inicial. **GIF** (animado em loop) ou **PNG** (parado).
  2. `camada2_grade` - grade **parada** por cima do fundo. PNG ou GIF. Sempre usa o mesmo tamanho e o mesmo zoom do fundo (se a tela for de outro formato, os dois ganham o mesmo ajuste juntos; `FUNDO_AJUSTE` no `Menu.gd` escolhe "cobrir" a tela ou "caber" inteiro). Faça a grade com as mesmas dimensões do fundo.
  2b. `camada2_movimento` - algo com movimento (rola na horizontal e repete). PNG ou GIF.
  3. `personagem_online`, `personagem_local`, `personagem_historia`, `personagem_editar`, `personagem_colecionaveis` - arte do personagem; **só esta camada muda com o menu** (desliza na troca).
  4. `camada4_borda_topo` e `camada4_borda_baixo` - as duas bordas (uma gruda no topo, a outra embaixo, na largura da tela). **GIF** ou **PNG**. Se forem GIF, **só se movem quando a pessoa troca de menu** (uma volta do GIF a cada troca); parados, mostram o primeiro quadro. Se forem PNG, ficam paradas. (`camada4_borda` de tela inteira ainda funciona se você não usar as duas.)
  - **GIF:** o Godot não lê GIF, então ele vira quadros PNG (`nome_1.png`, `nome_2.png`... e `nome.anim.json` com o tempo de cada quadro). A conversão é automática: ao enviar um `.gif` para o GitHub, a ação **Converter GIFs** faz isso e envia os quadros. No computador: `python3 ferramentas/gif_para_frames.py` (precisa do Pillow). GIF de um quadro só vira PNG.
  - **Memória:** cada quadro é uma textura. Use GIFs com até ~60 quadros e largura de 960 (a conversão já limita a 90 quadros e 960 de largura; mude com `--max-frames` e `--largura`).
  - Também vale para sequências feitas por você: `nome_1.png`, `nome_2.png`... tocam a 12 FPS (`CAMADAS_FPS` no `Menu.gd`) se não houver `nome.anim.json`.
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
