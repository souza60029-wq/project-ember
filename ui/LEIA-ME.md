# Onde colocar as artes (engine Ember)

Tudo é opcional: sem arte, a engine desenha formas simples no lugar.

| Tela | Arquivo | Para quê |
|---|---|---|
| 1. Logo | `ui/logo.png` | Tela de abertura (logo do jogo/engine) |
| 2. Título | `ui/fundo_titulo.png` | Tela "toque na tela" / "aperte start" |
| 3. Menu | `ui/menu/fundo_local.png`, `fundo_multiplayer.png`, `fundo_treino.png`, `fundo_personagem.png` | Um fundo por aba; troca ao mudar de aba |
| 3. Menu | `ui/menu/icone_local.png`, `icone_multiplayer.png`, `icone_treino.png`, `icone_personagem.png` | Ícone de cada aba |
| 3. Menu | `ui/menu/icone_arcade.png`, `icone_classico.png`, `icone_historia.png`, `icone_coop.png`, `icone_mp_online.png`, `icone_criar.png`, `icone_editar.png` | Ícones dos submenus (submenus não têm fundo próprio) |
| 3. Menu | `ui/menu/icone_config.png` | Botão de configurações (canto superior esquerdo) |
| Seleção | `ui/selecao/fundo.png` | Fundo da tela de seleção de personagens |
| Seleção | `ui/selecao/moldura_card.png` | Moldura sobre cada card (opcional) |
| Seleção | `ui/selecao/cursor_p1.png`, `cursor_p2.png` | Cursores dos jogadores (opcional) |
| Dicas de controle | `ui/glifos/xbox_A.png`, `ps_A.png`, ... | Ícones de botão. Tipos: A B X Y START LB RB DPAD DPAD_LR |

## Artes de cada personagem (na pasta do personagem)
`personagens/<id>/arte/selecao.png` (arte grande) e `personagens/<id>/arte/card.png` (card da grade).
No JSON: `"arte_selecao"` e `"arte_card"`. O editor de personagem faz isso por você.
Sprites alinhados pelo **centro dos pés** (meio da base da imagem), virados para a **direita**.
