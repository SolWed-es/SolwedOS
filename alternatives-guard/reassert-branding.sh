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
# anduinos-dconf-defaults, grub2-common, base-files (os-release/lsb-release
# y el logo "Acerca de" de Ajustes → Sistema).
#
# Disparado por el mismo mecanismo que reassert-alternatives.sh
# (DPkg::Post-Invoke), tras cualquier operación de dpkg/apt.

set -e

SRC="/usr/share/solwed/branding-guard"
needs_icon_cache=0
needs_dconf=0
needs_grub=0
needs_desktop_db=0

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
# IMPORTANTE: muchos "iconos" de este tema son en realidad symlinks a otro
# fichero real (p.ej. org.gnome.Software.svg -> gnome-software.svg, o
# preferences-system-network.svg -> network-workgroup.svg) -- `cp` sigue el
# symlink y escribe en el destino real. Los ficheros de esta carpeta DEBEN
# estar trackeados con el NOMBRE REAL (el que devuelve `readlink`), nunca
# con el nombre del symlink/alias -- si no, un `cp` puede clobbearse en un
# fichero real distinto al que alguien creía estar arreglando (bug real
# encontrado 2026-07-21: el icono de Software/FacturaScripts se revirtió a
# azul porque el repo lo trackeaba como org.gnome.Software.svg en vez de
# gnome-software.svg, su nombre real). Antes de añadir un icono nuevo aquí,
# comprobar con `readlink` si el destino en custom-root es un symlink.
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
#
# MISMO RIESGO que los iconos de arriba: bastantes cursores de este tema son
# symlinks a otro fichero real (p.ej. watch -> wait, nw-resize ->
# top_left_corner) -- auditado 2026-07-21, sin divergencia activa hoy, pero
# si algún cursor se recolorea a mano en el futuro, trackearlo aquí con el
# nombre REAL (`readlink -f`), no con el del symlink/alias.
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
# gnome-shell-extension-simple-weather: is-activated=false (no true) a
# propósito desde 2026-07-21 — con true, la extensión se salta su propia
# autoconfiguración de primer arranque (detecta la ciudad real del cliente
# por IP vía ipapi.co) y el widget del tiempo queda sin ubicación para
# siempre, dando "Error!" tenga o no tenga internet. Con false, el usuario
# ve una única pantalla de bienvenida (un clic) la primera vez y la
# ubicación se detecta sola. Desde 2026-07-23 fija también
# my-loc-provider='ipapi.co' explícitamente (ver el parche de config.js
# justo debajo, sin él este valor se ignora igualmente).
if restore_if_diff "$SRC/system-files/etc/dconf/db/anduinos.d/18-simple-weather.conf" "/etc/dconf/db/anduinos.d/18-simple-weather.conf"; then
    needs_dconf=1
fi
# gnome-shell-extension-simple-weather: parche de bug real en la propia
# extensión (config.js, encontrado 2026-07-23) — su getMyLocationProvider()
# solo aceptaba los valores 1-2 del enum de 4 valores, así que CUALQUIER
# my-loc-provider configurado en dconf (incluido el default del schema,
# ipapi.co=4) caía siempre a ipinfo.io=1, que usa un token compartido por
# todo el mundo que use esta extensión y da "Failed to get My Location."
# de forma consistente (token agotado/revocado). Sin este parche, el
# my-loc-provider='ipapi.co' de arriba no tiene ningún efecto.
restore_if_diff "$SRC/system-files/usr/share/gnome-shell/extensions/simple-weather@romanlefler.com/config.js" "/usr/share/gnome-shell/extensions/simple-weather@romanlefler.com/config.js" || true
if restore_if_diff "$SRC/system-files/usr/share/glib-2.0/schemas/99-anduinos-defaults.gschema.override" "/usr/share/glib-2.0/schemas/99-anduinos-defaults.gschema.override"; then
    glib-compile-schemas /usr/share/glib-2.0/schemas/
fi
restore_if_diff "$SRC/system-files/etc/gdm3/greeter.dconf-defaults" "/etc/gdm3/greeter.dconf-defaults" || true
# El ID de rescate es dinámico por máquina, no algo que la copia estática
# de arriba pueda contener -- reaplicarlo aquí siempre, por si la línea de
# arriba acaba de sobreescribir el fichero y se llevó el banner por delante.
/usr/lib/solwed/set-login-banner.sh || true

# --- Identidad del sistema (base-files) ---
# os-release alimenta GRUB_DISTRIBUTOR en caliente (ver /etc/default/grub:
# `( . /etc/os-release && echo ${NAME} )`, evaluado en cada update-grub) ->
# si se revierte, el grub.cfg ya horneado se queda con "AnduinOS" hasta el
# próximo update-grub por otra vía. needs_grub=1 aquí cierra ese hueco (bug
# real detectado 2026-07-29: un sistema con un par de días de actualizaciones
# mostró "AnduinOS" en el menú de arranque pese a que os-release ya estaba
# bien).
if restore_if_diff "$SRC/system-files/etc/os-release" "/etc/os-release"; then
    needs_grub=1
fi
restore_if_diff "$SRC/system-files/etc/lsb-release" "/etc/lsb-release" || true
# /etc/issue (TTY) y /etc/issue.net (SSH/serial) -- mismo paquete (base-files),
# mismo riesgo, encontrados sin tocar el 2026-07-29 (aún decían "AnduinOS 2.0.0").
restore_if_diff "$SRC/system-files/etc/issue" "/etc/issue" || true
restore_if_diff "$SRC/system-files/etc/issue.net" "/etc/issue.net" || true

# --- Selector de fondos de Ajustes (anduinos-wallpapers) ---
# fluent.xml lista las entradas del selector "Fondo de pantalla" -- traía una
# entrada "AnduinOS" (aos-light.jpg/aos-dark.jpg) que es literalmente el
# logo de capas azul de AnduinOS a tamaño wallpaper. Encontrada sin tocar el
# 2026-07-29. Quitada la entrada entera (no solo renombrada) -- las imágenes
# aos-*.jpg se quedan en disco sin usar, no merece la pena borrarlas del
# paquete solo por esto.
restore_if_diff "$SRC/system-files/usr/share/gnome-background-properties/fluent.xml" "/usr/share/gnome-background-properties/fluent.xml" || true

# --- App "Apariencia" del menú de inicio (anduinos-appearance) ---
# Name=/Name[es_ES]= cambiados a mano el 2026-07-08 a "Solwed OS Appearance"/
# "Apariencia de SolwedOS" -- el paquete anduinos-appearance no declara este
# .desktop como conffile (sin var/lib/dpkg/info/anduinos-appearance.conffiles),
# así que dpkg lo revierte sin avisar en cualquier actualización del paquete.
# Bug real reportado 2026-07-29: una máquina de campo volvió a mostrar
# "Apariencia de AnduinOS" -- este fichero nunca se había añadido al
# guardián (solo su icono, ver sección de iconos más arriba), hueco cerrado
# ahora con la misma mecánica que el resto.
if restore_if_diff "$SRC/system-files/usr/share/applications/anduinos-appearance.desktop" "/usr/share/applications/anduinos-appearance.desktop"; then
    needs_desktop_db=1
fi

# --- Logo de Ajustes -> Sistema -> Acerca de (base-files) ---
# gnome-control-center tiene la ruta escrita a fuego en el propio binario
# (confirmado con `strings`) -- no usa el mecanismo generico distributor-logo
# de los themes de iconos. Sin este fix se ve el wordmark "ANDUINOS" que
# AnduinOS reexportó sobre la plantilla original de Ubuntu.
for f in ubuntu-logo-text.svg ubuntu-logo-text.png ubuntu-logo-text-dark.svg ubuntu-logo-text-dark.png; do
    restore_if_diff "$SRC/system-files/usr/share/pixmaps/$f" "/usr/share/pixmaps/$f" || true
done

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
if [ "$needs_desktop_db" = "1" ] && command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database /usr/share/applications >/dev/null 2>&1 || true
fi
