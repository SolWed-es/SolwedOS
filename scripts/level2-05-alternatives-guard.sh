#!/bin/bash
# Nivel 2 — Guardián de alternativas (Plymouth + fondo de login GDM)
#
# EJECUTAR DENTRO del terminal chroot que abre Cubic (ya eres root ahí, sin sudo).
# Requisito previo: haber copiado alternatives-guard/ a /root/ dentro de
# custom-root ANTES de entrar al chroot (mismo mecanismo que los demás
# scripts de Nivel 2).
#
# plymouth-anduinos y anduinos-gdm3-wallpaper hacen `update-alternatives
# --set` incondicional a SU propio tema en cada reconfigure (instalación,
# reinstalación, o cualquier actualización futura — vía apt, GNOME
# Software/PackageKit, unattended-upgrades, lo que sea), pisando cualquier
# elección manual. Confirmado el 2026-07-14 tras una actualización real
# desde Software que revirtió el splash de Plymouth a "AnduinOS".
#
# Este script instala un hook de APT que reafirma nuestras alternativas
# tras cualquier operación de dpkg/apt — se dispara también cuando la
# actualización viene de GNOME Software, porque PackageKit usa apt/dpkg
# por debajo.

set -e

SRC_DIR="/root/alternatives-guard"
SCRIPT_DEST="/usr/lib/solwed/reassert-alternatives.sh"
HOOK_DEST="/etc/apt/apt.conf.d/99-solwedos-alternatives-guard"

if [ ! -f "$SRC_DIR/reassert-alternatives.sh" ] || [ ! -f "$SRC_DIR/99-solwedos-alternatives-guard" ]; then
    echo "Faltan los archivos en $SRC_DIR — cópialos ahí desde fuera del chroot antes de ejecutar esto." >&2
    exit 1
fi

echo "==> Instalando el script guardián en $SCRIPT_DEST"
mkdir -p "$(dirname "$SCRIPT_DEST")"
cp "$SRC_DIR/reassert-alternatives.sh" "$SCRIPT_DEST"
chmod +x "$SCRIPT_DEST"

echo "==> Instalando el hook de APT en $HOOK_DEST"
cp "$SRC_DIR/99-solwedos-alternatives-guard" "$HOOK_DEST"

echo "==> Ejecutando una vez ahora, para confirmar que no falla y que el estado actual queda correcto"
"$SCRIPT_DEST"

echo "==> Hecho. A partir de ahora, cualquier actualización de plymouth-anduinos o"
echo "    anduinos-gdm3-wallpaper (por apt o por GNOME Software) se corregirá sola."
