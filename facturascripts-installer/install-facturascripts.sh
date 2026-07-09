#!/bin/bash
# Lanzador GUI de FacturaScripts para Solwed OS.
# Corre como el usuario normal (necesita la sesión Wayland para mostrar zenity).
# Solo la instalación real (apt/mysql/systemctl) se eleva con pkexec, vía
# install-facturascripts-worker.sh — un proceso root no puede abrir ventanas
# en la sesión Wayland del usuario, así que zenity nunca puede correr como root aquí.
set -euo pipefail

WEBROOT=/var/www/html/facturas
LOG=/var/log/solwed-facturascripts-install.log

error_exit() {
    zenity --error --title="Instalación de FacturaScripts" --text="Ha fallado la instalación:\n\n$1\n\nRevisa el log en $LOG" --width=400
    exit 1
}

# Ya instalado: solo ofrecer abrir el navegador.
if [ -d "$WEBROOT" ]; then
    if zenity --question --title="FacturaScripts" --text="FacturaScripts ya está instalado.\n\n¿Quieres abrirlo en el navegador?" --width=350; then
        xdg-open "http://localhost/facturas" >/dev/null 2>&1 &
    fi
    exit 0
fi

pkexec /opt/solwed/install-facturascripts-worker.sh | zenity --progress --title="Instalando FacturaScripts" \
    --text="Preparando instalación..." --width=480 --auto-close --no-cancel

PIPE_STATUS=${PIPESTATUS[0]}
if [ "$PIPE_STATUS" -ne 0 ]; then
    error_exit "El proceso de instalación falló. Revisa $LOG para más detalles."
fi

DESKTOP_DIR=$(xdg-user-dir DESKTOP 2>/dev/null || echo "$HOME/Desktop")
CREDS_FILE="$DESKTOP_DIR/FacturaScripts-datos-acceso.txt"

zenity --info --title="FacturaScripts instalado" --width=420 --text="FacturaScripts se ha instalado correctamente.\n\nLos datos de acceso a la base de datos se han guardado en:\n$CREDS_FILE\n\nAhora se abrirá el navegador para completar la configuración inicial."

xdg-open "http://localhost/facturas" >/dev/null 2>&1 &
