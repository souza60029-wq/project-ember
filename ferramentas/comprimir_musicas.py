#!/usr/bin/env python3
"""Comprime as músicas do jogo economizando espaço sem perder muita qualidade.

Usa o ffmpeg (https://ffmpeg.org). Por padrão recodifica MP3 em VBR (qualidade 4, ~165 kbps,
praticamente indistinguível para a maioria dos ouvidos) e só troca o arquivo se o novo ficar menor.
Os originais vão para a pasta _originais/ ao lado (use --sem-backup para não guardar).

Exemplos:
  python3 ferramentas/comprimir_musicas.py                    # comprime tudo em musica/
  python3 ferramentas/comprimir_musicas.py --dry-run          # só mostra o que faria
  python3 ferramentas/comprimir_musicas.py --qualidade 5      # menor (~130 kbps)
  python3 ferramentas/comprimir_musicas.py --formato ogg      # converte para OGG Vorbis (menor ainda)
  python3 ferramentas/comprimir_musicas.py minha_pasta --manter-capa
"""
import argparse
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

EXTENSOES = {".mp3", ".wav", ".flac", ".m4a", ".ogg"}


def tamanho(n: int) -> str:
    for u in ("B", "KB", "MB", "GB"):
        if n < 1024 or u == "GB":
            return f"{n:.1f} {u}" if u != "B" else f"{n} B"
        n /= 1024.0
    return str(n)


def comando(entrada: Path, saida: Path, formato: str, qualidade: int, manter_capa: bool) -> list:
    cmd = ["ffmpeg", "-y", "-loglevel", "error", "-i", str(entrada)]
    if not manter_capa:
        cmd += ["-vn"]
    cmd += ["-map_metadata", "0"]
    if formato == "mp3":
        # -q:a 0 (melhor) a 9 (menor). 4 = ~165 kbps VBR.
        cmd += ["-codec:a", "libmp3lame", "-q:a", str(qualidade), "-joint_stereo", "1"]
    else:
        # Vorbis -q:a 0 a 10. Equivalente aproximado: 5 ~ 160 kbps.
        cmd += ["-codec:a", "libvorbis", "-q:a", str(min(10, max(0, 9 - qualidade)))]
    cmd += [str(saida)]
    return cmd


def main() -> int:
    ap = argparse.ArgumentParser(description="Comprime músicas (MP3/OGG) com pouca perda de qualidade.")
    ap.add_argument("pasta", nargs="?", default="musica", help="pasta de músicas (padrão: musica)")
    ap.add_argument("--formato", choices=["mp3", "ogg"], default="mp3", help="formato de saída (padrão: mp3)")
    ap.add_argument("--qualidade", type=int, default=4, choices=range(0, 10), metavar="0-9",
                    help="0 = melhor/maior, 9 = menor. Padrão 4 (~165 kbps)")
    ap.add_argument("--manter-capa", action="store_true", help="mantém a capa do álbum (ocupa espaço)")
    ap.add_argument("--sem-backup", action="store_true", help="não guarda os originais em _originais/")
    ap.add_argument("--dry-run", action="store_true", help="só lista o que seria feito")
    args = ap.parse_args()

    raiz = Path(args.pasta)
    if not raiz.is_dir():
        print(f"Pasta não encontrada: {raiz}")
        return 1
    if not args.dry_run and shutil.which("ffmpeg") is None:
        print("ffmpeg não encontrado. Instale em https://ffmpeg.org (ou: brew install ffmpeg / apt install ffmpeg).")
        return 1

    arquivos = [p for p in sorted(raiz.rglob("*")) if p.is_file() and p.suffix.lower() in EXTENSOES and "_originais" not in p.parts]
    if not arquivos:
        print("Nenhuma música encontrada.")
        return 0

    antes_total = depois_total = 0
    for p in arquivos:
        antes = p.stat().st_size
        if args.dry_run:
            print(f"[simulação] {p} ({tamanho(antes)})")
            antes_total += antes
            depois_total += antes
            continue
        with tempfile.TemporaryDirectory() as tmp:
            temp = Path(tmp) / ("saida." + args.formato)
            r = subprocess.run(comando(p, temp, args.formato, args.qualidade, args.manter_capa), capture_output=True, text=True)
            if r.returncode != 0 or not temp.exists():
                print(f"[erro] {p}: {r.stderr.strip() or 'falha ao converter'}")
                antes_total += antes
                depois_total += antes
                continue
            depois = temp.stat().st_size
            if depois >= antes and p.suffix.lower() == "." + args.formato:
                print(f"[mantido] {p} (novo {tamanho(depois)} não é menor que {tamanho(antes)})")
                antes_total += antes
                depois_total += antes
                continue
            if not args.sem_backup:
                destino = p.parent / "_originais" / p.name
                destino.parent.mkdir(exist_ok=True)
                # .gdignore: o Godot ignora a pasta (os originais não entram no projeto nem na exportação).
                (destino.parent / ".gdignore").touch()
                if not destino.exists():
                    shutil.copy2(p, destino)
            novo = p.with_suffix("." + args.formato)
            shutil.move(str(temp), str(novo))
            if novo != p:
                p.unlink()
            print(f"[ok] {novo} {tamanho(antes)} -> {tamanho(depois)}")
            antes_total += antes
            depois_total += depois

    if antes_total:
        eco = 100.0 * (1 - depois_total / antes_total)
        print(f"\nTotal: {tamanho(antes_total)} -> {tamanho(depois_total)} (economia de {eco:.0f}%)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
