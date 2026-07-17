#!/bin/bash
# Nivel 3 — Cuenta de rescate soporte-solwed (para clientes que olvidan su contraseña)
#
# EJECUTAR DENTRO del terminal chroot que abre Cubic (ya eres root ahí, sin sudo).
#
# La cuenta nace SIN contraseña utilizable (--disabled-password) — nunca hay
# una contraseña "de fábrica" igual en todo el parque, ni siquiera hasta el
# primer arranque. Quien fija la contraseña real, distinta por máquina, es
# rescue-password/report-rescue-password.sh en el primer arranque real (ver
# ese directorio), que además la registra en remoto.erpsolwed.es asociada al
# ID de RustDesk de esa máquina para que soporte pueda consultarla en la
# llamada. No documentar ninguna contraseña de esta cuenta a mano en ningún
# sitio: a partir de ahora es siempre generada y por máquina.
set -euo pipefail

USERNAME="soporte-solwed"

if id "$USERNAME" &>/dev/null; then
  echo "El usuario $USERNAME ya existe, no se recrea."
else
  adduser --disabled-password --gecos "Soporte Solwed" "$USERNAME"
  usermod -aG sudo "$USERNAME"
fi

# Ocultar de la lista de usuarios de GDM (sigue funcionando si alguien
# escribe el nombre a mano en la pantalla de login) — mismo mecanismo que
# AccountsService usa para cuentas de sistema.
mkdir -p /var/lib/AccountsService/users
cat > "/var/lib/AccountsService/users/$USERNAME" << 'EOF'
[User]
SystemAccount=true
EOF

echo "Cuenta $USERNAME creada, con sudo, y oculta de la lista de GDM."
echo "Pendiente de boot-test real: confirmar que queda oculta y que el login manual sigue funcionando."
