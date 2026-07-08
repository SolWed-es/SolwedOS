#!/bin/bash
# Nivel 2 — Plymouth v2 (Alpha 2.3.0)
#
# EJECUTAR DENTRO del terminal chroot que abre Cubic (ya eres root ahí, sin sudo).
# Requisito previo: haber copiado el watermark.png y bgrt-fallback.png NUEVOS
# a /root/solwed-branding/ dentro de custom-root ANTES de entrar al chroot
# (mismo mecanismo que level2-01-plymouth.sh).
#
# Solo sustituye los dos assets del tema solwedos ya existente (creado por
# level2-01-plymouth.sh) y regenera initramfs — no vuelve a forkear el tema
# ni a tocar update-alternatives, eso ya quedó hecho.

set -e

SRC_ASSETS="/root/solwed-branding"
THEME_DIR="/usr/share/plymouth/themes/solwedos"

if [ ! -d "$THEME_DIR" ]; then
    echo "No existe $THEME_DIR — hace falta correr level2-01-plymouth.sh primero." >&2
    exit 1
fi

if [ ! -f "$SRC_ASSETS/watermark.png" ] || [ ! -f "$SRC_ASSETS/bgrt-fallback.png" ]; then
    echo "Faltan los assets en $SRC_ASSETS — cópialos ahí desde fuera del chroot antes de ejecutar esto." >&2
    exit 1
fi

echo "==> Sustituyendo watermark y bgrt-fallback (v2: 'Solwed OS' + marca W. con acento amarillo)"
cp "$SRC_ASSETS/watermark.png" "$THEME_DIR/watermark.png"
cp "$SRC_ASSETS/bgrt-fallback.png" "$THEME_DIR/bgrt-fallback.png"

echo "==> Regenerando initramfs"
update-initramfs -u -k all

echo "==> Hecho. Generate en Cubic y boot-test."
