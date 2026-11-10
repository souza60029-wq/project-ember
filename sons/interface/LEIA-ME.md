# Sons e músicas das telas (ogg, wav ou mp3; o nome do arquivo é o nome do evento)

`sons/interface/`
- `start.ogg` - som ao tocar/apertar start na tela de título (se faltar, usa `menu_confirma`)
- `menu_mover`, `menu_confirma`, `menu_voltar` - toques de interface do menu
- `selecao_mover`, `selecao_confirma` - tela de seleção (se faltar, usa os do menu)

`musica/`
- `titulo` - tela de título
- `menu_local`, `menu_multiplayer`, `menu_treino`, `menu_personagem` - uma por aba (troca ao mudar de aba)
- `menu_configuracoes` - configurações
- `selecao` - seleção de personagens

`sons/comuns/` - sons de luta usados por todos (ataque_leve, impacto_forte, bloqueio, parry, guarda_quebrada, esquiva...)
Cada personagem pode ter os próprios em `personagens/<id>/sons/<evento>.ogg`, e um som por golpe (campo `sons.uso`).
