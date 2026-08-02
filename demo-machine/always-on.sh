#!/bin/bash
# Modo "siempre encendido" para la máquina de demo de Solwed OS.
# Idempotente: se puede ejecutar varias veces sin efectos secundarios.
# Requiere root (sudo o pkexec). La parte de GNOME (gsettings) se aplica
# al usuario que lo ejecuta, así que lanzarlo desde la sesión del usuario:
#   pkexec bash demo-machine/always-on.sh && bash demo-machine/always-on.sh --user
set -euo pipefail

if [[ "${1:-}" == "--user" ]]; then
    # Sin auto-suspensión por inactividad, ni enchufado ni en batería.
    gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing'
    gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type 'nothing'
    echo "GNOME: auto-suspensión desactivada para $USER"
    exit 0
fi

[[ $EUID -eq 0 ]] || { echo "Ejecutar como root (o con --user para la parte de GNOME)"; exit 1; }

# Nadie puede suspender/hibernar el equipo, ni GNOME ni ninguna app.
systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target

# Cerrar la tapa no suspende (portátil funcionando como mini-servidor).
mkdir -p /etc/systemd/logind.conf.d
cat > /etc/systemd/logind.conf.d/99-solwed-always-on.conf <<'EOF'
[Login]
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore
EOF
systemctl restart systemd-logind

echo "Suspensión bloqueada y tapa ignorada. Falta el paso de BIOS: ver demo-machine/README.md"
