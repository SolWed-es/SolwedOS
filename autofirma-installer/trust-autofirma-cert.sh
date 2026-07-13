#!/bin/sh
# Instala el certificado raíz de Autofirma en las bases NSS de Chromium/Brave
# del usuario. Chrome/Chromium no confía en el almacén del sistema
# (/etc/ssl/certs) para esto desde hace varias versiones, usa su propia base
# NSS por usuario -- de ahí que el instalador de Autofirma (que solo sabe de
# Firefox y del almacén de sistema) no sea suficiente por sí solo.
# Idempotente, pensado para correr en cada login vía autostart.

CERT=/usr/lib/Autofirma/Autofirma_ROOT.cer
[ -f "$CERT" ] || exit 0

# Cubre las dos ubicaciones posibles: la clásica (~/.pki/nssdb) y la nueva
# usada por Chromium desde M146 (~/.local/share/pki/nssdb) -- no sabemos de
# antemano cuál usará la versión de Brave instalada, así que se rellenan
# ambas por seguridad.
for DB in "$HOME/.pki/nssdb" "$HOME/.local/share/pki/nssdb"; do
    mkdir -p "$DB"
    [ -f "$DB/cert9.db" ] || certutil -N -d "sql:$DB" --empty-password 2>/dev/null
    certutil -d "sql:$DB" -L -n "AutoFirma" >/dev/null 2>&1 || \
        certutil -d "sql:$DB" -A -t "C,," -n "AutoFirma" -i "$CERT" 2>/dev/null
done
