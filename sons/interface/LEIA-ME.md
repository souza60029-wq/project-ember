# Sons e músicas (ogg, wav ou mp3; o nome do arquivo é o nome do evento)

## Efeitos de interface: `sons/interface/`
- `start` - som ao tocar/apertar start na tela de título (se faltar, usa `menu_confirma`)
- `menu_mover` - ao trocar de menu/submenu; `menu_confirma` - ao selecionar; `menu_voltar`
- `selecao_mover`, `selecao_confirma` - seleção de personagens (se faltar, usa os do menu)

## Músicas: `musica/`
Todas as músicas do jogo são sorteadas (aleatórias); quando uma acaba, sorteia outra.
```
musica/
  titulo.ogg        tela de título (faixa reservada, não entra no sorteio)
  selecao.ogg       seleção de personagens (reservada; ou use a pasta musica/selecao/ com várias)
  menu/             músicas que tocam só no MENU
  (raiz)            músicas que tocam só na LUTA
  luta/             opcional, também só na luta
```
- **Menu:** toca só `musica/menu/`. Não muda ao trocar de menu.
- **Luta:** toca **todas** (raiz + `menu/` + `luta/`), sorteadas.
- **Seleção de personagens:** sorteia de `musica/selecao/`; se estiver vazia, usa `musica/selecao.ogg`.
- **Tema de personagem:** `personagens/<id>/musica.ogg`. Se o jogador 1 tiver tema, ele toca na luta (senão o do jogador 2, senão o sorteio).
- O nome mostrado na bolha do disco vem do nome do arquivo (`minha_musica.ogg` vira "Minha Musica").
- **No aparelho:** o app cria `user://musica/` e `user://musica/menu/` (no iOS: app Arquivos > No meu iPhone > Ember). Faixas colocadas lá entram no sorteio com a mesma regra.
- Para economizar espaço: `python3 ferramentas/comprimir_musicas.py` (veja o README).

## Sons de luta: `sons/comuns/` (ataque_leve, impacto_forte, bloqueio, parry, guarda_quebrada, esquiva...)
Cada personagem pode ter os próprios em `personagens/<id>/sons/<evento>.ogg`, e um som por golpe (campo `sons.uso`, feito no editor pelo botão de nota musical).
