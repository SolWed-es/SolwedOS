#!/bin/bash
# Touchpad del Latitude 5490 (ALPS DELL0816 044E:121F por I2C): el firmware
# reporta saltos de coordenadas y contactos fantasma, libinput descarta el
# movimiento ("kernel bug: Touch jump detected and discarded" en el journal)
# y el cursor solo se mueve con dos dedos.
#
# Solución: poner i2c_hid_acpi en blacklist para que el touchpad funcione en
# modo PS/2 (driver psmouse/ALPS), y arrancar con i8042.nopnp porque la BIOS
# declara el puerto AUX PS/2 como desactivado cuando espera modo I2C.
#
# Ejecutar como root: pkexec bash demo-machine/touchpad-ps2-fallback.sh
# Requiere reiniciar. Para revertir: --revert (y reiniciar).
set -euo pipefail

BLACKLIST=/etc/modprobe.d/blacklist-i2c-hid-touchpad.conf
# El guardián de branding restaura /etc/default/grub desde esta copia tras
# cada transacción de apt — hay que tocar las dos o el parámetro se revierte.
GUARD_GRUB=/usr/share/solwed/branding-guard/system-files/etc/default/grub

if [[ "${1:-}" == "--revert" ]]; then
    rm -f "$BLACKLIST"
    sed -i 's/ i8042\.nopnp//' /etc/default/grub
    [[ -f "$GUARD_GRUB" ]] && sed -i 's/ i8042\.nopnp//' "$GUARD_GRUB"
    update-initramfs -u
    update-grub
    echo "Revertido. Reinicia para volver al modo I2C."
    exit 0
fi

cat > "$BLACKLIST" <<'EOF'
# Latitude 5490: el touchpad ALPS (DELL0816 044E:121F) por I2C reporta saltos
# de coordenadas y libinput descarta el movimiento de un solo dedo
# ("Touch jump detected and discarded"). Con i2c_hid_acpi en blacklist el
# touchpad cae al modo PS/2 (driver psmouse/ALPS), que es estable.
blacklist i2c_hid_acpi
EOF

for f in /etc/default/grub ${GUARD_GRUB}; do
    [[ -f "$f" ]] || continue
    if ! grep -q 'i8042\.nopnp' "$f"; then
        sed -i 's/^\(GRUB_CMDLINE_LINUX_DEFAULT="[^"]*\)"/\1 i8042.nopnp"/' "$f"
    fi
done
grep CMDLINE_LINUX_DEFAULT /etc/default/grub

update-initramfs -u
update-grub
echo "Aplicado. Reinicia para que el touchpad pase a modo PS/2."
