#!/bin/bash
# Escribe el ID de recuperación de esta máquina como aviso en la pantalla
# de login de GDM, para que el cliente pueda leerlo SIN necesidad de
# iniciar sesión (el caso real: cliente bloqueado fuera de su cuenta,
# llama a soporte, lee este ID por teléfono, soporte le dicta de vuelta
# usuario "soporte-solwed" + la contraseña de rescate de esa máquina).
#
# Cambiado 2026-07-21: este ID ya NO es el ID de RustDesk de la cuenta del
# cliente (ver report-rescue-password.sh para el porqué) — es un ID propio
# de Solwed, generado localmente, que solo sirve para esto. El texto del
# banner se aclara a "ID de recuperación" en vez de "ID de soporte" para
# que nadie (cliente o técnico) lo confunda con el ID real de RustDesk que
# se usa en una llamada de soporte atendido normal.
#
# Idempotente y sin dependencia de red: solo necesita que el ID ya se haya
# resuelto localmente (ver report-rescue-password.sh). Pensado para
# ejecutarse tanto ahí como desde alternatives-guard/reassert-branding.sh,
# ya que greeter.dconf-defaults no es un conffile protegido y una
# actualización de anduinos-dconf-defaults puede revertirlo sin avisar.
set -euo pipefail

ID_FILE=/var/lib/solwed/.support-id
GREETER_CONF=/etc/gdm3/greeter.dconf-defaults
SECTION='[org/gnome/login-screen]'

[ -f "$ID_FILE" ] || exit 0
[ -f "$GREETER_CONF" ] || exit 0

SUPPORT_ID=$(cat "$ID_FILE")
[ -n "$SUPPORT_ID" ] || exit 0

# Quita cualquier banner-message-* previo (de una pasada anterior, quizá
# con un ID viejo si el fichero se regeneró) antes de volver a escribirlo.
sed -i '/^banner-message-enable=/d; /^banner-message-text=/d' "$GREETER_CONF"

grep -qxF "$SECTION" "$GREETER_CONF" || printf '\n%s\n' "$SECTION" >> "$GREETER_CONF"

TMP_BANNER=$(mktemp)
trap 'rm -f "$TMP_BANNER"' EXIT
printf "banner-message-enable=true\nbanner-message-text='ID de recuperación: %s'\n" "$SUPPORT_ID" > "$TMP_BANNER"

sed -i "/^\[org\/gnome\/login-screen\]\$/r $TMP_BANNER" "$GREETER_CONF"
