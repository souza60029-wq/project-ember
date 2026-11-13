#!/usr/bin/env python3
"""Converte GIF em quadros PNG para a Ember Engine (o Godot não lê GIF).

Para cada nome.gif gera nome_1.png, nome_2.png... e nome.anim.json com a duração de cada quadro.
GIF de um quadro só vira nome.png. O menu entende tudo isso sozinho (fundo animado, bordas que
se movem na troca de menu). Se você usar PNG em vez de GIF, nada precisa ser convertido.

Precisa do Pillow:  pip install pillow

Exemplos:
  python3 ferramentas/gif_para_frames.py                       # converte todos os .gif em ui/menu
  python3 ferramentas/gif_para_frames.py ui/menu/camada1_fundo.gif
  python3 ferramentas/gif_para_frames.py --largura 1280 --max-frames 60
  python3 ferramentas/gif_para_frames.py --forcar              # reconverte mesmo que já exista

Dica de memória: cada quadro vira uma textura. Prefira GIF com poucos quadros (até ~60) e largura 960.
"""
import argparse
import json
import sys
from pathlib import Path

try:
    from PIL import Image, ImageSequence
except ImportError:
    print("Falta o Pillow. Instale com: pip install pillow")
    sys.exit(1)


def converter(gif: Path, largura: int, max_frames: int, forcar: bool) -> str:
    saida_json = gif.with_suffix(".anim.json")
    quadros_existentes = sorted(gif.parent.glob(gif.stem + "_*.png")) + ([gif.with_suffix(".png")] if gif.with_suffix(".png").exists() else [])
    if not forcar and quadros_existentes and min(p.stat().st_mtime for p in quadros_existentes) >= gif.stat().st_mtime:
        return f"[pulado] {gif} (já convertido; use --forcar para refazer)"

    im = Image.open(gif)
    quadros = []
    duracoes = []
    for frame in ImageSequence.Iterator(im):
        quadros.append(frame.convert("RGBA"))
        duracoes.append(int(frame.info.get("duration", im.info.get("duration", 80))) or 80)

    # Muitos quadros pesam na memória: mantém 1 a cada k e soma a duração dos pulados.
    if max_frames > 0 and len(quadros) > max_frames:
        k = -(-len(quadros) // max_frames)
        novos_q, novos_d = [], []
        for i in range(0, len(quadros), k):
            novos_q.append(quadros[i])
            novos_d.append(sum(duracoes[i:i + k]))
        quadros, duracoes = novos_q, novos_d

    if largura > 0 and quadros[0].width > largura:
        alt = round(quadros[0].height * largura / quadros[0].width)
        quadros = [q.resize((largura, alt), Image.LANCZOS) for q in quadros]

    # Remove quadros de uma conversão anterior.
    for p in gif.parent.glob(gif.stem + "_*.png"):
        sufixo = p.stem[len(gif.stem) + 1:]
        if sufixo.isdigit():
            p.unlink()
    if gif.with_suffix(".png").exists() and len(quadros) > 1:
        gif.with_suffix(".png").unlink()

    if len(quadros) == 1:
        quadros[0].save(gif.with_suffix(".png"))
        if saida_json.exists():
            saida_json.unlink()
        return f"[ok] {gif} -> {gif.with_suffix('.png').name} (1 quadro, parado)"

    for i, q in enumerate(quadros, 1):
        q.save(gif.parent / f"{gif.stem}_{i}.png", optimize=True)
    saida_json.write_text(json.dumps({"duracoes_ms": duracoes}, indent=2), encoding="utf-8")
    total = sum(duracoes) / 1000.0
    return f"[ok] {gif} -> {len(quadros)} quadros ({total:.1f} s por volta) + {saida_json.name}"


def main() -> int:
    ap = argparse.ArgumentParser(description="Converte GIF em quadros PNG para a Ember Engine.")
    ap.add_argument("alvo", nargs="*", default=["ui/menu"], help="arquivos .gif ou pastas (padrão: ui/menu)")
    ap.add_argument("--largura", type=int, default=960, help="largura máxima em pixels (0 = não redimensionar)")
    ap.add_argument("--max-frames", type=int, default=90, help="máximo de quadros (0 = sem limite)")
    ap.add_argument("--forcar", action="store_true", help="reconverte mesmo que já esteja convertido")
    args = ap.parse_args()

    gifs = []
    for a in args.alvo:
        p = Path(a)
        if p.is_dir():
            gifs += sorted(p.rglob("*.gif"))
        elif p.suffix.lower() == ".gif" and p.exists():
            gifs.append(p)
    if not gifs:
        print("Nenhum .gif encontrado.")
        return 0
    for g in gifs:
        print(converter(g, args.largura, args.max_frames, args.forcar))
    return 0


if __name__ == "__main__":
    sys.exit(main())
