#!/bin/bash
# Nivel 2 — Fondo de pantalla de login (GDM3)
#
# EJECUTAR DENTRO del terminal chroot que abre Cubic (ya eres root ahí, sin sudo).
# Aplicar DESPUÉS de haber probado Plymouth por separado (level2-01-plymouth.sh).
# Este cambio no toca initramfs/kernel — no puede causar un kernel panic,
# en el peor caso la pantalla de login queda fea o vuelve al fondo de AnduinOS.
#
# Reutiliza el mecanismo nativo de AnduinOS (paquete anduinos-gdm3-wallpaper):
# genera un gdm-theme.gresource nuevo a partir de un wallpaper y lo registra
# vía update-alternatives, igual que hace el postinst del paquete original.

set -e

WALLPAPER="/usr/share/backgrounds/solwed/solwed-oscuro.png"
OUT_DIR="/var/lib/anduinos-gdm3-wallpaper"
OUT_FILE="$OUT_DIR/solwedos-theme.gresource"

if [ ! -f "$WALLPAPER" ]; then
    echo "No se encuentra $WALLPAPER (debería existir desde el Nivel 1)." >&2
    exit 1
fi

echo "==> Generando gdm-theme.gresource con el fondo oscuro de Solwed"
mkdir -p "$OUT_DIR"
anduinos-gdm-set-wallpaper --wallpaper "$WALLPAPER" --output "$OUT_FILE"

echo "==> Registrando como alternativa (prioridad 160, por encima del default de AnduinOS=150)"
update-alternatives --install /usr/share/gnome-shell/gdm-theme.gresource gdm-theme.gresource \
  "$OUT_FILE" 160
update-alternatives --set gdm-theme.gresource "$OUT_FILE"

echo "==> Hecho. Generate en Cubic y boot-test: pantalla de login debe mostrar el fondo oscuro Solwed."
