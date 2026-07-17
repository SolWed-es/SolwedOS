#!/bin/bash
# Nivel 4 — Registro automático de la contraseña de rescate de soporte-solwed.
#
# Se ejecuta una sola vez, en el primer arranque REAL de cada instalación
# (nunca en modo live: casper regenera el sistema de cero en cada arranque,
# así que ni siquiera tiene sentido intentarlo ahí — mismo guardián que
# welcome-wizard/solwed-welcome.sh).
#
# Qué hace: genera una contraseña única para soporte-solwed en ESTA máquina
# (en vez de la compartida entre todo el parque), y la registra en
# remoto.erpsolwed.es asociada al ID de RustDesk de esta máquina — el mismo
# ID que el cliente ya nos lee por teléfono para conectarnos, así que no
# hace falta ningún dato nuevo para el cliente ni saber de antemano quién
# es, aunque se haya instalado él mismo la ISO en casa.
#
# Pensado para lanzarse como servicio systemd (ver
# solwed-rescue-password.service), no como autostart de usuario: no depende
# de que nadie inicie sesión, y systemd reintenta solo si no hay red todavía.
set -euo pipefail

grep -q boot=casper /proc/cmdline && exit 0

STATE_DIR=/var/lib/solwed
MARKER="$STATE_DIR/rescue-password-done"
PW_FILE="$STATE_DIR/.rescue-password"

[ -f "$MARKER" ] && exit 0

mkdir -p "$STATE_DIR"
chmod 700 "$STATE_DIR"

# Genera la contraseña una sola vez y la persiste localmente: si el envío
# de más abajo falla por falta de red, el siguiente reintento debe usar la
# MISMA contraseña (ya aplicada a soporte-solwed), no generar otra.
if [ ! -f "$PW_FILE" ]; then
    NEW_PASSWORD=$(set +o pipefail; tr -dc 'A-Za-z0-9' </dev/urandom | head -c 20)
    echo "soporte-solwed:${NEW_PASSWORD}" | chpasswd
    umask 077
    printf '%s' "$NEW_PASSWORD" > "$PW_FILE"
fi
PASSWORD=$(cat "$PW_FILE")

# El ID de RustDesk que el cliente lee en pantalla es el de SU PROPIA
# cuenta (cada HOME tiene su propia identidad RustDesk local) — este
# servicio corre como root, así que "rustdesk --get-id" a secas devuelve
# la identidad de root, no la del cliente. Hay que ejecutarlo como la
# cuenta real del cliente. Se busca la primera cuenta de usuario "real"
# (UID de rango normal, con HOME propio), excluyendo explícitamente
# soporte-solwed (que se crea en el build de la imagen y por eso suele
# quedarse con el primer UID libre, antes de que exista la cuenta real).
TARGET_USER=""
while IFS=: read -r uname _ uid _ _ home _; do
    if [ "$uid" -ge 1000 ] && [ "$uid" -lt 60000 ] \
        && [ "$uname" != "soporte-solwed" ] && [ -d "$home" ]; then
        TARGET_USER="$uname"
        break
    fi
done < <(getent passwd)

RUSTDESK_ID=""
if [ -n "$TARGET_USER" ]; then
    for _ in $(seq 1 30); do
        ID_ATTEMPT=$(runuser -l "$TARGET_USER" -c 'rustdesk --get-id' 2>/dev/null || true)
        if [ -n "$ID_ATTEMPT" ] && [ "$ID_ATTEMPT" != "0" ]; then
            RUSTDESK_ID="$ID_ATTEMPT"
            break
        fi
        sleep 2
    done
fi

if [ -z "$RUSTDESK_ID" ]; then
    echo "RustDesk todavía no tiene ID asignado, se reintentará en el próximo arranque." >&2
    exit 1
fi

# Persistimos el ID y lo aplicamos ya al banner de la pantalla de login,
# independientemente de si el envío al servidor (más abajo) tiene éxito o
# no -- el cliente debe poder leer su ID en pantalla aunque esta máquina
# no haya tenido internet todavía.
printf '%s' "$RUSTDESK_ID" > "$STATE_DIR/.rustdesk-id"
/usr/lib/solwed/set-login-banner.sh || true

# DEVICE_TOKEN se inyecta vía EnvironmentFile del .service (no hornear el
# valor real aquí ni pegarlo nunca en un chat/commit — ver
# solwed-rescue-password.service y la nota de despliegue del servidor).
: "${DEVICE_TOKEN:?falta DEVICE_TOKEN, revisa el EnvironmentFile del servicio}"

HTTP_CODE=$(curl -s -o /dev/null -w '%{http_code}' \
    --max-time 15 \
    -X POST "https://remoto.erpsolwed.es/rescue-credentials" \
    -H "Authorization: Bearer ${DEVICE_TOKEN}" \
    -H 'Content-Type: application/json' \
    -d "{\"rustdesk_id\":\"${RUSTDESK_ID}\",\"password\":\"${PASSWORD}\"}") || HTTP_CODE=000

case "$HTTP_CODE" in
    200|201|409)
        # 409 = ya estaba registrado (p.ej. un intento anterior sí llegó
        # pero el marcador local se perdió) — se trata igual como éxito.
        touch "$MARKER"
        exit 0
        ;;
    *)
        echo "Fallo registrando la contraseña de rescate (HTTP $HTTP_CODE), se reintentará." >&2
        exit 1
        ;;
esac
