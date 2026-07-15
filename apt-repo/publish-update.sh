#!/bin/bash
# Publica un .deb nuevo en el repo APT de Solwed sin downtime.
# Ejecutar en erpsolwed, como root (sudo). Requiere el .deb ya copiado al servidor.
#
# Uso: sudo ./publish-update.sh /ruta/al/paquete.deb
set -euo pipefail

DEB="${1:?Uso: publish-update.sh /ruta/al/paquete.deb}"
GPG_KEY="1F2DA3270E5FCCF8"
SNAPSHOT_NAME="solwed-$(date +%Y%m%d-%H%M%S)"

aptly repo add solwed "$DEB"
aptly snapshot create "$SNAPSHOT_NAME" from repo solwed
aptly publish switch -gpg-key="$GPG_KEY" resolute "$SNAPSHOT_NAME"

echo "Publicado: $SNAPSHOT_NAME"
echo "Snapshots antiguos (borra los que ya no necesites con 'aptly snapshot drop <nombre>'):"
aptly snapshot list
