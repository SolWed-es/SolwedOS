#!/bin/sh
# Instala Autofirma 1.9 (Gobierno de España) en el chroot de Cubic.
# Ejecutar desde la terminal del chroot de Cubic (root, sin sudo).
# Requiere que autofirma_1_9.deb ya esté copiado en /root/ (ver instrucciones
# de baking en el repo).

set -e

apt-get update
apt-get install -y openjdk-11-jre libnss3-tools

dpkg -i /root/autofirma_1_9.deb || true
apt-get install -y -f

echo
echo "Autofirma instalado."
echo "IMPORTANTE: version 1.9 tiene fallos conocidos registrando su certificado"
echo "(/usr/lib/AutoFirma/AutoFirma_ROOT.cer) en el almacen NSS en Ubuntu 24.04+."
echo "Verificar en el boot-test que Brave confia en el. Si falla: abrir Autofirma"
echo "-> Herramientas -> Restaurar Instalacion."
