#!/bin/bash
# Nivel 2 — Tema gráfico de GRUB (sistema instalado)
#
# EJECUTAR DENTRO del terminal chroot que abre Cubic (ya eres root ahí, sin sudo).
#
# Copia el tema de scripts/../grub-theme/ (ya debe estar dentro de custom-root,
# el host lo copia con `sudo cp -r` antes de abrir el terminal chroot, igual
# que el resto de scripts de Nivel 2) a /usr/share/grub/themes/solwedos/ y
# activa GRUB_THEME + timeout + resolución en /etc/default/grub.
#
# No hace falta correr update-grub aquí: este chroot no tiene un disco real
# de destino, así que no existe un grub.cfg de sistema instalado que regenerar.
# El grub.cfg real lo genera Ubiquity (update-grub) durante la instalación,
# leyendo /etc/default/grub de este mismo rootfs — este cambio solo se ve
# tras una instalación real, no en modo live.

set -e

SRC_DIR="/root/grub-theme"
DEST_DIR="/usr/share/grub/themes/solwedos"
DEFAULT_GRUB="/etc/default/grub"

if [ ! -f "$SRC_DIR/theme.txt" ]; then
    echo "No se encuentra $SRC_DIR/theme.txt — copia grub-theme/ a /root/ antes de ejecutar esto." >&2
    exit 1
fi

echo "==> Instalando el tema en $DEST_DIR"
mkdir -p "$DEST_DIR"
cp "$SRC_DIR/theme.txt" "$DEST_DIR/theme.txt"
cp "$SRC_DIR/background.png" "$DEST_DIR/background.png"
cp "$SRC_DIR/solwed-grub-title.pf2" "$DEST_DIR/solwed-grub-title.pf2"
cp "$SRC_DIR/solwed-grub-menu.pf2" "$DEST_DIR/solwed-grub-menu.pf2"
cp "$SRC_DIR/solwed-grub-small.pf2" "$DEST_DIR/solwed-grub-small.pf2"

echo "==> Actualizando $DEFAULT_GRUB (timeout=5s, menú visible, entrada por defecto, tema)"

set_grub_key() {
    local key="$1" value="$2"
    if grep -q "^${key}=" "$DEFAULT_GRUB"; then
        sed -i "s|^${key}=.*|${key}=${value}|" "$DEFAULT_GRUB"
    else
        echo "${key}=${value}" >> "$DEFAULT_GRUB"
    fi
}

set_grub_key "GRUB_DEFAULT" "0"
set_grub_key "GRUB_TIMEOUT_STYLE" "menu"
set_grub_key "GRUB_TIMEOUT" "5"
set_grub_key "GRUB_GFXMODE" "1920x1080,auto"
set_grub_key "GRUB_THEME" "\"${DEST_DIR}/theme.txt\""

echo "==> Hecho. Contenido final de $DEFAULT_GRUB:"
cat "$DEFAULT_GRUB"
echo
echo "==> Verificación solo posible tras una instalación real (Ubiquity genera el grub.cfg real con update-grub)."
