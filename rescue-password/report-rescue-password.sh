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
# remoto.erpsolwed.es asociada a un ID de recuperación de 9 dígitos propio
# de Solwed (ver generate_support_id() más abajo) — YA NO el ID de RustDesk
# de la cuenta del cliente.
#
# Cambiado 2026-07-21: usar el ID de RustDesk tenía un fallo real detectado
# en producción — si el disco no se borra del todo entre instalaciones (VM
# reutilizada, partición no formateada), tanto la identidad de RustDesk del
# cliente como el propio marcador de este script pueden sobrevivir, y la
# "nueva" instalación termina con el mismo ID/contraseña que la anterior.
# Generarlo nosotros mismos, con entropía real (/dev/urandom) mezclada con
# datos de esta máquina concreta, quita la dependencia de un sistema externo
# (RustDesk) cuya generación de identidad no controlamos ni podemos
# garantizar que sea nueva en cada instalación.
#
# Pensado para lanzarse como servicio systemd (ver
# solwed-rescue-password.service), no como autostart de usuario: no depende
# de que nadie inicie sesión, y systemd reintenta solo si no hay red todavía.
set -euo pipefail

grep -q boot=casper /proc/cmdline && exit 0

STATE_DIR=/var/lib/solwed
MARKER="$STATE_DIR/rescue-password-done"
PW_FILE="$STATE_DIR/.rescue-password"
ID_FILE="$STATE_DIR/.support-id"

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

# ID de recuperación de 9 dígitos, propio de Solwed — no depende de
# RustDesk ni de ninguna cuenta de usuario en concreto.
#
# Mezcla varias fuentes de entropía con SHA-256 en vez de concatenar
# dígitos a pelo: si solo usáramos fecha/hora + MAC tal cual, varias
# máquinas clonadas de la misma plantilla casi en el mismo instante
# (caso real: una tanda de VMs de pruebas) podrían generar IDs muy
# parecidos o incluso iguales — el hash desordena eso por completo
# (efecto avalancha: una diferencia mínima en la entrada cambia el
# hash entero). /dev/urandom sigue siendo la fuente principal de
# aleatoriedad real; el resto son "sal" adicional, no imprescindible
# por sí sola pero barata de añadir.
#
# Nota sobre `head -c 32 /dev/urandom`: a diferencia del bug ya
# conocido en este mismo fichero (tr | head cortando la tubería y
# matando a tr con SIGPIPE bajo pipefail), aquí head lee un FICHERO
# directamente (no una tubería infinita desde otro proceso) y decide
# él mismo cuándo parar — no hay ningún proceso aguas arriba al que
# matar, así que no hace falta el mismo workaround de pipefail.
generate_support_id() {
    local mac entropy hash num
    mac=$(cat /sys/class/net/*/address 2>/dev/null | grep -v '^00:00:00:00:00:00$' | head -n1)
    entropy="$(head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n')|$(date +%s%N)|${mac:-sin-mac}|$(cat /proc/sys/kernel/random/boot_id 2>/dev/null)|$(hostname)"
    hash=$(printf '%s' "$entropy" | sha256sum | cut -d' ' -f1)
    # 15 hex = 60 bits, cabe de sobra en el entero de 64 bits con signo
    # que usa la aritmética de bash sin desbordar.
    num=$((16#${hash:0:15}))
    printf '%d' $(( num % 900000000 + 100000000 ))
}

if [ ! -f "$ID_FILE" ]; then
    umask 077
    generate_support_id > "$ID_FILE"
fi
SUPPORT_ID=$(cat "$ID_FILE")

# Aplicamos ya el banner de login independientemente de si el envío al
# servidor (más abajo) tiene éxito o no -- el cliente debe poder leer su
# ID en pantalla aunque esta máquina no haya tenido internet todavía.
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
    -d "{\"rustdesk_id\":\"${SUPPORT_ID}\",\"password\":\"${PASSWORD}\"}") || HTTP_CODE=000

case "$HTTP_CODE" in
    200|201|409)
        # 409 = ya estaba registrado (p.ej. un intento anterior sí llegó
        # pero el marcador local se perdió) — se trata igual como éxito.
        # Con un ID propio de 9 dígitos generado por hash, una colisión
        # real con OTRA máquina distinta es astronómicamente improbable
        # (espacio de ~900 millones de valores) frente al caso normal de
        # ser un reintento de esta misma máquina.
        touch "$MARKER"
        exit 0
        ;;
    *)
        echo "Fallo registrando la contraseña de rescate (HTTP $HTTP_CODE), se reintentará." >&2
        exit 1
        ;;
esac
