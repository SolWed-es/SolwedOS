#!/bin/bash
# Nivel 2 — Plymouth (splash de arranque)
#
# EJECUTAR DENTRO del terminal chroot que abre Cubic (ya eres root ahí, sin sudo).
# Requisito previo: haber copiado watermark.png y bgrt-fallback.png a
# /root/solwed-branding/ dentro de custom-root ANTES de entrar al chroot
# (ver instrucciones en el mensaje de Claude / README de este script).
#
# Aplica UNA cosa sola: el tema de Plymouth. No mezclar con otros cambios
# en la misma sesión — si algo sale mal en el arranque, así se sabe que
# fue esto. Después de correr esto: Generate en Cubic y boot-test SOLO.

set -e

SRC_ASSETS="/root/solwed-branding"
THEME_DIR="/usr/share/plymouth/themes/solwedos"

if [ ! -f "$SRC_ASSETS/watermark.png" ] || [ ! -f "$SRC_ASSETS/bgrt-fallback.png" ]; then
    echo "Faltan los assets en $SRC_ASSETS — cópialos ahí desde fuera del chroot antes de ejecutar esto." >&2
    exit 1
fi

echo "==> Forkeando tema anduinos -> solwedos"
rm -rf "$THEME_DIR"
cp -r /usr/share/plymouth/themes/anduinos "$THEME_DIR"
mv "$THEME_DIR/anduinos.plymouth" "$THEME_DIR/solwedos.plymouth"

echo "==> Sustituyendo watermark y bgrt-fallback por la marca Solwed"
cp "$SRC_ASSETS/watermark.png" "$THEME_DIR/watermark.png"
cp "$SRC_ASSETS/bgrt-fallback.png" "$THEME_DIR/bgrt-fallback.png"

echo "==> Renombrando identidad del tema"
sed -i \
  -e 's/^Name=AnduinOS$/Name=Solwed OS/' \
  -e "s#^ImageDir=/usr/share/plymouth/themes/anduinos\$#ImageDir=$THEME_DIR#" \
  -e 's/^Description=.*/Description=Tema de arranque de Solwed OS (fork del spinner de AnduinOS)./' \
  "$THEME_DIR/solwedos.plymouth"

echo "==> Registrando como alternativa por defecto (prioridad 160, por encima de anduinos=150)"
update-alternatives --install /usr/share/plymouth/themes/default.plymouth default.plymouth \
  "$THEME_DIR/solwedos.plymouth" 160
update-alternatives --set default.plymouth "$THEME_DIR/solwedos.plymouth"

echo "==> Regenerando initramfs (obligatorio tras cualquier cambio de tema Plymouth)"
update-initramfs -u -k all

echo "==> Hecho. Ahora: Generate en Cubic y boot-test ESTE CAMBIO SOLO antes de tocar nada más."
