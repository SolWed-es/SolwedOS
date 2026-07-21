#!/bin/bash
# Nivel 3 — El administrador no vuelve a confirmar acciones admin tras el
# login (decision de negocio 2026-07-21, ver polkit/00-solwed-admin-no-prompt.rules
# para el razonamiento completo y por que el prefijo 00- es imprescindible).
#
# EJECUTAR DENTRO del terminal chroot que abre Cubic (ya eres root ahí, sin
# sudo). El fichero fuente hay que copiarlo antes desde una terminal normal
# del host, con sudo, apuntando a custom-root/ — esta terminal chroot no
# tiene montado /home/aruizb (ver nota en scripts/level3-04-support-account.sh
# y CLAUDE.md).
#
# No hace falta alternatives-guard/branding-guard para este fichero: es un
# fichero NUEVO que ningun paquete posee (polkitd nunca lo instala), asi que
# ninguna actualizacion de apt lo va a tocar ni revertir — esa clase de bug
# solo afecta a ficheros que EDITAMOS y que ya pertenecen a un paquete
# anduinos-*.
set -euo pipefail

SRC=/root/00-solwed-admin-no-prompt.rules
DEST=/etc/polkit-1/rules.d/00-solwed-admin-no-prompt.rules

[ -f "$SRC" ] || { echo "Copia antes $SRC desde el repo (polkit/00-solwed-admin-no-prompt.rules)." >&2; exit 1; }

install -m 644 -o root -g root "$SRC" "$DEST"

echo "Regla instalada en $DEST — no hace falta recargar nada, polkitd la recoge sola en el proximo arranque de la ISO."
