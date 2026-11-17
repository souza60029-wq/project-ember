# Onde colocar as artes (Ember)

Tudo é opcional: sem arte, a engine desenha formas simples no lugar.

## Telas iniciais (nesta ordem)
| Tela | Arquivo | Observação |
|---|---|---|
| 1. "Feito com Ember Engine" | `ui/ember/fundo.png` + `ui/ember/logo.png` | As duas imagens juntas formam a tela: o fundo ocupa a tela toda e a logo fica centralizada por cima. Separadas para você usar em outras telas. |
| 2. Título + AVISO | `ui/fundo_titulo.png` | Arte de fundo da tela "toque na tela / aperte start". O aviso de projeto de fã aparece em um painel escuro sobre a arte (texto em `engine/config/Textos.gd`, chaves `aviso_titulo` e `aviso_corpo`). |
| 3. Menu | veja abaixo | |

## Menu (centro inferior; esquerda/direita troca de menu, cima/baixo troca de submenu)
Menus: **Multiplayer** (Online, Vs), **Local** (Arcade, História), **Treino**, **Editar** (Criar, Editar), **Colecionáveis**.
`Vs` é o multiplayer local com 2 controles. `Criar` e `Editar` são criar/editar personagem.

**Fundo em camadas** (imagens com transparência, em `ui/menu/`; de baixo para cima). As artes **não são mais esticadas**: mantêm a proporção.
1. `camada1_fundo` - fundo (GIF animado ou PNG parado; cobre a tela inteira)
2. `camada2_grade` - grade parada por cima do fundo (mesmo tamanho e zoom do fundo)
   `camada2_movimento` - algo que rola na horizontal e repete
3. Arte do personagem (a única que muda): `personagem_multiplayer`, `personagem_local`, `personagem_treino`, `personagem_editar`, `personagem_colecionaveis` e, **por submenu**, `personagem_sub_online`, `personagem_sub_vs`, `personagem_sub_arcade`, `personagem_sub_historia`, `personagem_sub_criar`, `personagem_sub_editar_perso`. Se o submenu não tiver arte, vale a do menu. A arte cabe inteira na tela; ajuste posição e tamanho na ferramenta de debug.
4. `camada4_borda_topo` e `camada4_borda_baixo` - bordas (GIF só se move ao trocar de menu; PNG fica parada)

**Várias artes para o mesmo menu/submenu:** acrescente `-2`, `-3`... ao nome (`personagem_local.png`, `personagem_local-2.png`, `personagem_local-3.png`). O app sorteia uma toda vez que o menu/submenu é aberto. Só sorteia se houver mais de uma. Vale para ícones e para as artes de personagem.

**Ícones:** menus `icone_multiplayer`, `icone_local`, `icone_treino`, `icone_editar`, `icone_colecionaveis`; submenus `icone_sub_online`, `icone_sub_vs`, `icone_sub_arcade`, `icone_sub_historia`, `icone_sub_criar`, `icone_sub_editar_perso`. Aceitam variantes `-2`, `-3`. Sem arte, o app desenha um ícone. Configurações: `icone_config`.

**Disco de música:** `disco.png` (gira enquanto toca) e `disco_nota.png` (a nota que sai dele). Opcionais.

**GIF:** o Godot não lê GIF; vira quadros `nome_1.png`, `nome_2.png`... + `nome.anim.json` (a ação "Converter GIFs" do GitHub faz isso sozinha ao enviar um .gif). Veja `ferramentas/gif_para_frames.py`.

**Ferramenta de debug das camadas** (Configurações > Jogo > Editar camadas do menu): arraste e redimensione cada camada; "Salvar" aplica e grava `Ember/debug/layout_menu.txt`. Para tirar da versão final, apague a pasta `engine/debug/` e cole os valores em `Menu.gd` (`LAYOUT_FIXO`).

## Seleção de personagens
`ui/selecao/fundo.png`, `moldura_card.png`, `cursor_p1.png`, `cursor_p2.png`. As artes de cada personagem ficam na pasta dele: `arte/selecao.png` (grande) e `arte/card.png` (card).

## Ícones de botão do controle
`ui/glifos/xbox_A.png`, `ps_A.png`, ... Tipos: A B X Y START SELECT LB RB DPAD DPAD_LR.

Sprites: alinhados pelo **centro dos pés** (meio da base da imagem), virados para a **direita**.
