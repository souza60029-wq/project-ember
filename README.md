# Ember Engine

Engine 2D para criar jogos de luta, feita em **Godot 4.2** (GDScript). Roda em Android, iOS e desktop.

**Versão: 0.3.0** (pré-lançamento)

Você traz os sprites, sons e músicas; a engine cuida do combate, dos menus, da seleção de personagens e do editor de personagens.

## O que ela faz

**Combate (60 FPS)**
- Golpes por quadros: startup, active e recovery. Os sprites do golpe são distribuídos automaticamente nesses frames.
- Hitbox e corpo em pixels; a altura do personagem define a escala do corpo e dos golpes.
- Defesa, *just defense* (parry), barra de defesa com guarda quebrada, esquiva de distância fixa, Blow Off (BO), combos e KO.
- Reação de dano por altura do golpe (alto, meio, baixo, rasteira) e fila de eventos de som.
- Modo debug: mostra hitboxes, hurtboxes e dados de combate.

**Telas e menus**
- Abertura, título, menu em carrossel de ícones (esquerda/direita troca de menu, cima/baixo de submenu), seleção de personagens em trios (estilo KOF) e luta.
- Música por menu, músicas sorteadas na seleção, tema por personagem e disco de música com nome da faixa e mute.
- Toque e controle: o modo é detectado sozinho. Ícones de botão de Xbox e PlayStation.

**Editor de personagem (dentro do app)**
- Golpes fixos (LP, LK, HP, HK, BO) e golpes personalizados, com prioridade por ordem na lista.
- Timeline de sprites por golpe e por animação, importação de vários sprites de uma vez, sons por golpe e por evento, artes de seleção e card.
- Backup do personagem em texto (copiar e colar).

**Configurações**
- Idioma, modo debug, rotação da tela, HUD do sistema (aparelho, GPU, FPS, CPU, GPU, RAM e bateria, arrastável), modo de entrada e mapeamento de botões do controle para o Jogador 1 e o Jogador 2.

## Estrutura

| Pasta | Conteúdo |
|---|---|
| `engine/` | Código da engine (núcleo, luta, menus, editor, formato, sons, configurações) |
| `testes/` | Testes automáticos (rodam no GitHub Actions) |
| `personagens/` | Pasta onde ficam os personagens. A engine traz dois bonecos de treino de exemplo |
| `ui/`, `musica/`, `sons/` | Pastas onde você coloca as artes, músicas e sons. Veja `ui/LEIA-ME.md` e `sons/interface/LEIA-ME.md` |

## Como começar

1. Abra o projeto no Godot 4.2 (ou mais novo). A cena principal é `engine/inicio/Abertura.tscn`.
2. Coloque suas artes e sons nas pastas indicadas nos `LEIA-ME.md`. Tudo é opcional: sem arte, a engine desenha formas simples.
3. Crie personagens pelo editor do app (Editar > Criar personagem) ou copie `personagens/_modelo`.
4. Exporte para Android ou iOS pelos presets do projeto.

## Personagem

Cada personagem é uma pasta com `personagem.json`, mais `sprites/`, `golpes/`, `arte/` e `sons/` (opcionais). Os sprites ficam alinhados pelo centro dos pés e virados para a direita.

## Testes

```
godot --headless --script testes/teste_nucleo.gd
godot --headless --script testes/teste_pacote.gd
```
