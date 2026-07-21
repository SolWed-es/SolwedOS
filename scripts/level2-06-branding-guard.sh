#!/bin/bash
# Nivel 2 — Guardián de marca (iconos, cursores, dconf, GRUB, identidad)
#
# EJECUTAR DENTRO del terminal chroot que abre Cubic (ya eres root ahí, sin sudo).
# Requisito previo: haber copiado, desde fuera del chroot, TODO esto a /root/:
#   branding/icons/            -> /root/branding-guard-src/icons/
#   branding/cursors/          -> /root/branding-guard-src/cursors/
#   branding/panel/            -> /root/branding-guard-src/panel/
#   branding/system-files/     -> /root/branding-guard-src/system-files/
#   alternatives-guard/reassert-branding.sh       -> /root/branding-guard-src/
#   alternatives-guard/99-solwedos-branding-guard  -> /root/branding-guard-src/
# (un solo `sudo cp -r` de cada carpeta de origen basta, ver instrucciones
# del mensaje de Claude para el comando exacto).
#
# Complementa a level2-05-alternatives-guard.sh (Plymouth/GDM). Este cubre
# el resto de lo que hemos personalizado y que un paquete de AnduinOS puede
# revertir en cualquier actualización futura: iconos de apps, cursores, el
# icono del botón de inicio, los overrides de dconf/gschema, /etc/default/grub
# y la identidad del sistema (os-release/lsb-release).

set -e

SRC="/root/branding-guard-src"
DEST_ROOT="/usr/share/solwed/branding-guard"
SCRIPT_DEST="/usr/lib/solwed/reassert-branding.sh"
HOOK_DEST="/etc/apt/apt.conf.d/99-solwedos-branding-guard"

for d in icons cursors panel system-files; do
    if [ ! -d "$SRC/$d" ]; then
        echo "Falta $SRC/$d — cópialo ahí desde fuera del chroot antes de ejecutar esto." >&2
        exit 1
    fi
done
if [ ! -f "$SRC/reassert-branding.sh" ] || [ ! -f "$SRC/99-solwedos-branding-guard" ]; then
    echo "Faltan reassert-branding.sh / 99-solwedos-branding-guard en $SRC." >&2
    exit 1
fi

echo "==> Copiando las fuentes de restauración a $DEST_ROOT"
# `cp -r` sobre un directorio que ya existe MEZCLA, no sustituye — un
# fichero borrado del repo (p.ej. al renombrar un icono a su nombre real)
# se queda huérfano para siempre en $DEST_ROOT de una ejecución a la
# siguiente. Bug real encontrado 2026-07-21: ese sobrante volvía a
# clobbear el icono de Software/FacturaScripts justo después de que este
# mismo script lo arreglara, en la misma pasada, por procesarse después
# alfabéticamente. Por eso se borra $DEST_ROOT entero antes de copiar —
# así siempre queda un espejo exacto del repo, nunca acumula basura.
rm -rf "$DEST_ROOT"
mkdir -p "$DEST_ROOT"
cp -r "$SRC/icons" "$DEST_ROOT/"
cp -r "$SRC/cursors" "$DEST_ROOT/"
cp -r "$SRC/panel" "$DEST_ROOT/"
cp -r "$SRC/system-files" "$DEST_ROOT/"

echo "==> Instalando el script guardián en $SCRIPT_DEST"
mkdir -p "$(dirname "$SCRIPT_DEST")"
cp "$SRC/reassert-branding.sh" "$SCRIPT_DEST"
chmod +x "$SCRIPT_DEST"

echo "==> Instalando el hook de APT en $HOOK_DEST"
cp "$SRC/99-solwedos-branding-guard" "$HOOK_DEST"

echo "==> Ejecutando una vez ahora, para confirmar que no falla y que el estado actual queda correcto"
"$SCRIPT_DEST"

echo "==> Hecho. A partir de ahora, cualquier actualización de anduinos-fluent-icon-theme,"
echo "    anduinos-appearance, gnome-shell-extension-arcmenu, anduinos-dconf-defaults,"
echo "    grub2-common o base-files (por apt o por GNOME Software) se corregirá sola."
