#!/usr/bin/env bash
# Relaja MemoryDenyWriteExecute en el Apache endurecido de Solwed OS.
#
# La unidad apache2.service del paquete trae MemoryDenyWriteExecute=yes, que
# prohíbe memoria escribible+ejecutable a todo el árbol de procesos. Eso:
#   - desactiva el JIT de PCRE en PHP (avisos "Allocation of JIT memory failed"
#     en error.log y regex más lentos en todo FacturaScripts), y
#   - impide lanzar Chromium/Brave headless desde PHP (JIT de V8), que el
#     plugin SolwedAI usa para generar los PDF de informes.
#
# Este drop-in cambia SOLO esa directiva; el resto del sandboxing de la unidad
# (ProtectSystem, PrivateDevices, RestrictNamespaces, etc.) sigue activo.
#
# Uso:      pkexec bash demo-machine/apache-pdf-jit.sh
# Revertir: pkexec bash demo-machine/apache-pdf-jit.sh --revert
set -euo pipefail

DROPIN_DIR=/etc/systemd/system/apache2.service.d
DROPIN=$DROPIN_DIR/99-solwed-pdf.conf

if [[ "${1:-}" == "--revert" ]]; then
    rm -f "$DROPIN"
    rmdir --ignore-fail-on-non-empty "$DROPIN_DIR" 2>/dev/null || true
    systemctl daemon-reload
    systemctl restart apache2
    echo "Drop-in eliminado; Apache vuelve al endurecimiento original."
    exit 0
fi

mkdir -p "$DROPIN_DIR"
cat > "$DROPIN" <<'EOF'
# Solwed OS: permitir memoria W+X dentro de apache2 para el JIT de PCRE (PHP)
# y para Chromium headless (PDFs del plugin SolwedAI). Ver apache-pdf-jit.sh.
[Service]
MemoryDenyWriteExecute=no
EOF

systemctl daemon-reload
systemctl restart apache2
echo "Aplicado: $(systemctl show apache2 -p MemoryDenyWriteExecute)"
