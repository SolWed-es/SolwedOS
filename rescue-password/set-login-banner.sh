#!/bin/bash
# Escribe el ID de RustDesk de esta máquina como aviso en la pantalla de
# login de GDM, para que el cliente pueda leerlo SIN necesidad de iniciar
# sesión (el caso real: cliente bloqueado fuera de su cuenta, llama a
# soporte, lee este ID por teléfono, soporte le dicta de vuelta usuario
# "soporte-solwed" + la contraseña de rescate de esa máquina).
#
# Idempotente y sin dependencia de red: solo necesita que el ID ya se haya
# resuelto localmente (ver report-rescue-password.sh). Pensado para
# ejecutarse tanto ahí como desde alternatives-guard/reassert-branding.sh,
# ya que greeter.dconf-defaults no es un conffile protegido y una
# actualización de anduinos-dconf-defaults puede revertirlo sin avisar.
set -euo pipefail

ID_FILE=/var/lib/solwed/.rustdesk-id
GREETER_CONF=/etc/gdm3/greeter.dconf-defaults
SECTION='[org/gnome/login-screen]'

[ -f "$ID_FILE" ] || exit 0
[ -f "$GREETER_CONF" ] || exit 0

RUSTDESK_ID=$(cat "$ID_FILE")
[ -n "$RUSTDESK_ID" ] || exit 0

# Quita cualquier banner-message-* previo (de una pasada anterior, quizá
# con un ID viejo si el fichero se regeneró) antes de volver a escribirlo.
sed -i '/^banner-message-enable=/d; /^banner-message-text=/d' "$GREETER_CONF"

grep -qxF "$SECTION" "$GREETER_CONF" || printf '\n%s\n' "$SECTION" >> "$GREETER_CONF"

TMP_BANNER=$(mktemp)
trap 'rm -f "$TMP_BANNER"' EXIT
printf "banner-message-enable=true\nbanner-message-text='ID de soporte: %s'\n" "$RUSTDESK_ID" > "$TMP_BANNER"

sed -i "/^\[org\/gnome\/login-screen\]\$/r $TMP_BANNER" "$GREETER_CONF"
