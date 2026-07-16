#!/bin/sh
# Diálogo de bienvenida de Solwed OS.
#
# Solo en sistemas instalados: en modo live, casper regenera el usuario
# desde cero en cada arranque (el marcador de "ya mostrado" nunca
# persistiría), así que ni siquiera tiene sentido intentarlo ahí.
grep -q boot=casper /proc/cmdline && exit 0

# Se muestra una sola vez, en el primer login de cada usuario (idempotente
# vía fichero marcador, mismo patrón que trust-desktop-shortcuts.sh y
# trust-autofirma-cert.sh) — no en cada arranque.

MARKER="$HOME/.config/.solwed-welcome-shown"
[ -f "$MARKER" ] && exit 0

zenity --info \
    --title="Bienvenido a Solwed OS" \
    --width=420 \
    --window-icon=/usr/lib/solwed/solwed-welcome-logo.png \
    --text="<b>¡Bienvenido a Solwed OS!</b>\n\nTu equipo ya viene listo para trabajar, con:\n\n • LibreOffice (Writer, Calc, Impress...)\n • Thunderbird, con WhatsApp integrado\n • FacturaScripts (acceso directo en el escritorio)\n • Autofirma y Okular, para firmar documentos\n • Timeshift, para crear puntos de restauración (como el \"Restaurar sistema\" de Windows)\n\n¿Necesitas ayuda? Abre <b>RustDesk</b> desde el menú de inicio y facilítanos el ID que te muestre, o visita <b>solwed.es/contacto</b>."

mkdir -p "$(dirname "$MARKER")"
touch "$MARKER"
