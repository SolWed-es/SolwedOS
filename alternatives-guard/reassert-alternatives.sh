#!/bin/bash
# Reafirma las alternativas de Solwed OS si un postinst de AnduinOS las ha
# revertido (plymouth-anduinos y anduinos-gdm3-wallpaper hacen
# `update-alternatives --set` incondicional a SU propio tema en cada
# reconfigure, pisando cualquier elección manual, en cada actualización).
#
# Disparado por un hook de APT (DPkg::Post-Invoke) tras cualquier operación
# de dpkg/apt, incluida la que hace GNOME Software por debajo (PackageKit).
# Barato de ejecutar cuando no hace falta: solo un par de `readlink -f`.

set -e

PLYMOUTH_THEME="/usr/share/plymouth/themes/solwedos/solwedos.plymouth"
GDM_THEME="/var/lib/anduinos-gdm3-wallpaper/solwedos-theme.gresource"

needs_initramfs=0

if [ -f "$PLYMOUTH_THEME" ]; then
    current="$(readlink -f /usr/share/plymouth/themes/default.plymouth 2>/dev/null || true)"
    if [ "$current" != "$(readlink -f "$PLYMOUTH_THEME")" ]; then
        update-alternatives --set default.plymouth "$PLYMOUTH_THEME"
        needs_initramfs=1
    fi
fi

if [ -f "$GDM_THEME" ]; then
    current="$(readlink -f /usr/share/gnome-shell/gdm-theme.gresource 2>/dev/null || true)"
    if [ "$current" != "$(readlink -f "$GDM_THEME")" ]; then
        update-alternatives --set gdm-theme.gresource "$GDM_THEME"
    fi
fi

if [ "$needs_initramfs" = "1" ]; then
    update-initramfs -u -k all
fi
