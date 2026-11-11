# Sons e músicas (ogg, wav ou mp3; o nome do arquivo é o nome do evento)

## Efeitos de interface: `sons/interface/`
- `start` - som ao tocar/apertar start na tela de título (se faltar, usa `menu_confirma`)
- `menu_mover` - ao trocar de menu/submenu; `menu_confirma` - ao selecionar; `menu_voltar`
- `selecao_mover`, `selecao_confirma` - seleção de personagens (se faltar, usa os do menu)

## Músicas: `musica/`
- `titulo` - tela de título
- `menu_online`, `menu_local`, `menu_historia`, `menu_editar`, `menu_colecionaveis` - uma por menu (toca ao entrar no menu)
- `menu_configuracoes` - configurações
- `musica/selecao/` - **várias** músicas; a seleção de personagens sorteia uma e, quando acaba, sorteia outra (se a pasta estiver vazia, usa `musica/selecao`)
- `musica/luta/` - sorteio de reserva quando nenhum dos dois personagens tem tema
- Tema de personagem: `personagens/<id>/musica.ogg` (começa a luta com o tema do jogador 1; se ele não tiver, usa o do jogador 2)
- O nome mostrado na bolha do disco vem do nome do arquivo (`minha_musica.ogg` vira "Minha Musica").

## Sons de luta: `sons/comuns/` (ataque_leve, impacto_forte, bloqueio, parry, guarda_quebrada, esquiva...)
Cada personagem pode ter os próprios em `personagens/<id>/sons/<evento>.ogg`, e um som por golpe (campo `sons.uso`, feito no editor pelo botão de nota musical).
