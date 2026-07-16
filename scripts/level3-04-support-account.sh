#!/bin/bash
# Nivel 3 — Cuenta de rescate soporte-solwed (para clientes que olvidan su contraseña)
#
# EJECUTAR DENTRO del terminal chroot que abre Cubic (ya eres root ahí, sin sudo).
#
# IMPORTANTE: este script pide la contraseña de forma interactiva (adduser
# la pide dos veces, tecleada, nunca como argumento) — no la pases nunca
# como variable de entorno ni la pegues en ningún chat. Documenta la
# contraseña elegida solo en el gestor de contraseñas interno de Solwed,
# nunca en este repo ni en ningún sitio visible por el cliente.
set -euo pipefail

USERNAME="soporte-solwed"

if id "$USERNAME" &>/dev/null; then
  echo "El usuario $USERNAME ya existe, no se recrea."
else
  adduser --gecos "Soporte Solwed" "$USERNAME"
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
