#!/bin/bash
# Reafirma el resto de la personalización de Solwed OS (más allá de las
# alternativas de Plymouth/GDM, ver reassert-alternatives.sh) si un paquete
# de AnduinOS la ha revertido en una reconfiguración/actualización.
#
# Ninguno de estos archivos está declarado como conffile por su paquete
# propietario (verificado contra var/lib/dpkg/info/*.conffiles de la ISO de
# referencia limpia) -> dpkg los sobreescribe sin avisar ni preguntar en
# cualquier actualización relevante, venga de apt, GNOME Software
# (PackageKit) o unattended-upgrades. Paquetes con al menos un archivo aquí:
# anduinos-fluent-icon-theme, anduinos-appearance, gnome-shell-extension-arcmenu,
# anduinos-dconf-defaults, grub2-common, base-files.
#
# Disparado por el mismo mecanismo que reassert-alternatives.sh
# (DPkg::Post-Invoke), tras cualquier operación de dpkg/apt.

set -e

SRC="/usr/share/solwed/branding-guard"
needs_icon_cache=0
needs_dconf=0
needs_grub=0

restore_if_diff() {
    local src="$1" dst="$2"
    if [ -f "$src" ] && ! cmp -s "$src" "$dst" 2>/dev/null; then
        mkdir -p "$(dirname "$dst")"
        cp "$src" "$dst"
        return 0
    fi
    return 1
}

# --- Iconos de apps (anduinos-fluent-icon-theme, anduinos-appearance) ---
if [ -d "$SRC/icons/Fluent-yellow/scalable/apps" ]; then
    for f in "$SRC/icons/Fluent-yellow/scalable/apps/"*.svg; do
        name="$(basename "$f")"
        if restore_if_diff "$f" "/usr/share/icons/Fluent-yellow/scalable/apps/$name"; then
            needs_icon_cache=1
        fi
    done
fi
if restore_if_diff "$SRC/icons/hicolor/scalable/apps/anduinos-appearance.svg" "/usr/share/icons/hicolor/scalable/apps/anduinos-appearance.svg"; then
    needs_icon_cache=1
fi

# --- Cursores (mismo paquete que los iconos) ---
# Solo se trackean los ficheros que de verdad se recolorearon en su día (los
# básicos como default/text/sus alias nunca llevaron azul que corregir, así
# que no están aquí a propósito) -> comparar archivo a archivo, no todo el
# directorio, para no reportar diferencia en cada ejecución por su ausencia.
for theme in Fluent-cursors Fluent-dark-cursors; do
    [ -d "$SRC/cursors/$theme/cursors" ] || continue
    for f in "$SRC/cursors/$theme/cursors/"*; do
        restore_if_diff "$f" "/usr/share/icons/$theme/cursors/$(basename "$f")" || true
    done
done

# --- Icono del botón de inicio de ArcMenu (gnome-shell-extension-arcmenu) ---
restore_if_diff "$SRC/panel/anduinos-logo.svg" "/usr/share/gnome-shell/extensions/arcmenu@arcmenu.com/icons/anduinos-logo.svg" || true

# --- dconf/gschema (anduinos-dconf-defaults, gnome-shell-extension-arcmenu) ---
if restore_if_diff "$SRC/system-files/etc/dconf/db/anduinos.d/03-system-extensions.conf" "/etc/dconf/db/anduinos.d/03-system-extensions.conf"; then
    needs_dconf=1
fi
if restore_if_diff "$SRC/system-files/etc/dconf/db/anduinos.d/10-arcmenu.conf" "/etc/dconf/db/anduinos.d/10-arcmenu.conf"; then
    needs_dconf=1
fi
if restore_if_diff "$SRC/system-files/usr/share/glib-2.0/schemas/99-anduinos-defaults.gschema.override" "/usr/share/glib-2.0/schemas/99-anduinos-defaults.gschema.override"; then
    glib-compile-schemas /usr/share/glib-2.0/schemas/
fi
restore_if_diff "$SRC/system-files/etc/gdm3/greeter.dconf-defaults" "/etc/gdm3/greeter.dconf-defaults" || true
# El ID de rescate es dinámico por máquina, no algo que la copia estática
# de arriba pueda contener -- reaplicarlo aquí siempre, por si la línea de
# arriba acaba de sobreescribir el fichero y se llevó el banner por delante.
/usr/lib/solwed/set-login-banner.sh || true

# --- Identidad del sistema (base-files) ---
restore_if_diff "$SRC/system-files/etc/os-release" "/etc/os-release" || true
restore_if_diff "$SRC/system-files/etc/lsb-release" "/etc/lsb-release" || true

# --- GRUB (grub2-common) ---
if restore_if_diff "$SRC/system-files/etc/default/grub" "/etc/default/grub"; then
    needs_grub=1
fi

# --- Aplicar lo que haga falta ---
if [ "$needs_icon_cache" = "1" ]; then
    gtk-update-icon-cache -f -t /usr/share/icons/Fluent-yellow >/dev/null 2>&1 || true
    gtk-update-icon-cache -f -t /usr/share/icons/hicolor >/dev/null 2>&1 || true
fi
if [ "$needs_dconf" = "1" ]; then
    dconf update
fi
if [ "$needs_grub" = "1" ] && command -v update-grub >/dev/null 2>&1; then
    update-grub || true
fi
