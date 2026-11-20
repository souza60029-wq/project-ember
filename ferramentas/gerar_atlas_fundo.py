#!/usr/bin/env python3
"""Converte a pasta fundo_historia (quadros PNG) em folhas de sprites WebP para a engine.
Uso: python3 ferramentas/gerar_atlas_fundo.py <pasta fundo_historia> [saida=ui/fundo_historia]
Tamanho final: tela de 960x540 (a arte original é 1672x941).
"""
import sys, os, glob, math
from PIL import Image

ORIGEM = sys.argv[1]
SAIDA = sys.argv[2] if len(sys.argv) > 2 else "ui/fundo_historia"
K = 960.0 / 1672.0   # escala da arte original para a tela da engine

# nome, pasta, tamanho final do quadro, quadros a manter (passo), colunas
CAMADAS = [
    ("nuvens", "02_nuvens_META_RESOLUCAO", (320, 180), 1),
    ("raios", "03_raios_luz_META_RESOLUCAO", (160, 90), 1),
    ("neblina_fundo", "04_neblina_fundo_META_RESOLUCAO", (320, 180), 1),
    ("bandeira", "05_bandeira", (round(292 * K), round(660 * K)), 1),
    ("corrente", "07_corrente", (round(580 * K), round(650 * K)), 2),
    ("particulas", "08_particulas", (480, 270), 2),
    ("neblina_frente", "09_neblina_frente_META_RESOLUCAO", (320, 180), 1),
]


def reduzir(img, tam):
    # redimensiona com alfa pré-multiplicado (sem franjas escuras)
    return img.convert("RGBa").resize(tam, Image.LANCZOS).convert("RGBA")


def main():
    os.makedirs(SAIDA, exist_ok=True)
    base = Image.open(os.path.join(ORIGEM, "01_fundo_base_sem_nuvens.png")).convert("RGB")
    base.resize((960, 540), Image.LANCZOS).save(os.path.join(SAIDA, "base.webp"), quality=92, method=6)
    poste = Image.open(os.path.join(ORIGEM, "06_poste_frente.png"))
    reduzir(poste, (960, 540)).save(os.path.join(SAIDA, "poste.webp"), quality=92, method=6)
    info = {}
    for nome, pasta, tam, passo in CAMADAS:
        arqs = sorted(glob.glob(os.path.join(ORIGEM, pasta, "*.png")))[::passo]
        n = len(arqs)
        cols = max(1, min(n, 4096 // tam[0]))
        linhas = math.ceil(n / cols)
        folha = Image.new("RGBA", (cols * tam[0], linhas * tam[1]), (0, 0, 0, 0))
        for i, a in enumerate(arqs):
            q = reduzir(Image.open(a), tam)
            folha.paste(q, ((i % cols) * tam[0], (i // cols) * tam[1]))
        destino = os.path.join(SAIDA, nome + ".webp")
        folha.save(destino, quality=82, method=6, alpha_quality=90)
        info[nome] = (cols, n, tam)
        print("%-15s %2d quadros  %dx%d  folha %dx%d  %.1f MB" % (nome, n, tam[0], tam[1], folha.size[0], folha.size[1], os.path.getsize(destino) / 1e6))
    print(info)


main()
