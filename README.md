# project-ember

# Ember (engine de jogos de luta)

Duas partes separadas: **engine** (`engine/`: combate, menus, editor) e **seu jogo** (`ui/`, `musica/`, `sons/`, `personagens/`).
Veja `ui/LEIA-ME.md` e `sons/interface/LEIA-ME.md` para saber onde colocar cada arte, música e som.

## Fluxo
Abertura (logo) > Título (toque/start) > Menu > **Seleção de personagens** > Luta. Todo modo que leva a uma luta passa pela seleção.

## Combate (resumo)
- **Just defense (parry):** apertar para trás nos 5 frames antes do golpe encostar. Sem dano e sem gastar a barra de defesa. Segurar para trás é defesa normal.
- **Barra de defesa:** cada golpe defendido gasta uma parte (mais nos fortes). Zerou: guarda quebrada (1,25 s sem atacar nem defender) e a barra volta cheia. Sem quebrar, regenera devagar após 1 s sem defender golpe.
- **Esquiva (ESQ):** distância fixa para todos, sem custo. Neutro ou para frente atravessa o oponente; com trás, rola para trás.
- **BO (Blow Off)** (antes "CD"): golpe que joga o oponente longe. Golpes fortes (força 2 e 3) causam 30% menos dano.
- **Tamanho e alcance em pixels:** `altura_px` do personagem define o corpo e a escala dos golpes; a hitbox de cada golpe é em px.
- **Modo debug:** Configurações > Luta > Modo debug. Mostra corpo, hitbox, janela de parry e dados. Desligado por padrão.

## Sprites e frames (60 FPS)
Cada golpe tem frames fixos (startup + active + recovery). Os sprites que você coloca são distribuídos automaticamente nesses frames; marque o "sprite de impacto" para alinhar com o active.

## Testes
`godot --headless --script testes/teste_nucleo.gd` e `testes/teste_pacote.gd` (rodam no GitHub Actions a cada push).
