#!/bin/bash
# Worker sin GUI de la instalación de FacturaScripts para Solwed OS.
# Corre como root vía pkexec, invocado por install-facturascripts.sh (que sí tiene GUI).
# Protocolo de salida: líneas "N" (porcentaje) y "# mensaje" para zenity --progress;
# el resto de la salida de cada comando se manda al log, nunca al pipe de zenity.
set -uo pipefail

LOG=/var/log/solwed-facturascripts-install.log
WEBROOT=/var/www/html/facturas
DB_NAME=facturascripts_db
DB_USER=facturascripts
ORIG_USER=$(getent passwd "${PKEXEC_UID:-$(id -u)}" | cut -d: -f1)
ORIG_HOME=$(getent passwd "${PKEXEC_UID:-$(id -u)}" | cut -d: -f6)

: > "$LOG"

echo "5"; echo "# Actualizando repositorios..."
DEBIAN_FRONTEND=noninteractive apt-get update -y >>"$LOG" 2>&1 || { echo "100"; echo "APT_FAIL_UPDATE"; exit 1; }

echo "20"; echo "# Instalando Apache, PHP y MySQL (esto puede tardar unos minutos)..."
DEBIAN_FRONTEND=noninteractive apt-get install -y \
    apache2 php php-bcmath php-cli php-curl php-gd php-gmp php-mbstring \
    php-mysql php-soap php-xml php-zip mysql-server unzip wget \
    >>"$LOG" 2>&1 || { echo "100"; echo "APT_FAIL_INSTALL"; exit 1; }

echo "50"; echo "# Configurando Apache..."
a2enmod rewrite >>"$LOG" 2>&1
sed -i '/<Directory \/var\/www\/>/,/<\/Directory>/ s/AllowOverride None/AllowOverride All/' /etc/apache2/apache2.conf
# apache2 ya arranca solo al instalarse (postinst del paquete), antes de este
# punto, así que "enable --now" es un no-op si ya está activo y no recarga
# los módulos recién habilitados con a2enmod. "restart" fuerza la recarga
# siempre, esté o no ya corriendo.
systemctl enable apache2 >>"$LOG" 2>&1
systemctl restart apache2 >>"$LOG" 2>&1

echo "60"; echo "# Configurando MySQL..."
systemctl enable --now mysql >>"$LOG" 2>&1
for i in $(seq 1 15); do
    mysqladmin ping >/dev/null 2>&1 && break
    sleep 1
done

DB_PASS=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 20)
mysql -u root >>"$LOG" 2>&1 <<SQL
CREATE DATABASE IF NOT EXISTS ${DB_NAME} CHARACTER SET utf8mb4;
CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
SQL
if [ $? -ne 0 ]; then echo "100"; echo "MYSQL_FAIL"; exit 1; fi

echo "75"; echo "# Descargando FacturaScripts..."
cd /var/www/html || { echo "100"; echo "WEBROOT_MISSING"; exit 1; }
wget -q https://facturascripts.com/DownloadBuild/1/stable -O facturascripts.zip || { echo "100"; echo "DOWNLOAD_FAIL"; exit 1; }

echo "90"; echo "# Descomprimiendo e instalando..."
unzip -q facturascripts.zip >>"$LOG" 2>&1 || { echo "100"; echo "UNZIP_FAIL"; exit 1; }
rm -f facturascripts.zip
mv facturascripts facturas
chown -R www-data:www-data facturas

DESKTOP_DIR=$(runuser -u "$ORIG_USER" -- xdg-user-dir DESKTOP 2>/dev/null || echo "$ORIG_HOME/Desktop")
CREDS_FILE="$DESKTOP_DIR/FacturaScripts-datos-acceso.txt"
cat > "$CREDS_FILE" <<EOF
FacturaScripts — datos de acceso a la base de datos
=====================================================
Estos datos los pedirá el asistente de configuración de FacturaScripts
la primera vez que lo abras en el navegador.

Tipo de base de datos: MySQL
Servidor:  localhost
Puerto:    3306
Base de datos: ${DB_NAME}
Usuario:   ${DB_USER}
Contraseña: ${DB_PASS}

Guarda este fichero en un lugar seguro y bórralo del escritorio
cuando ya no lo necesites.
EOF
chown "$ORIG_USER:$ORIG_USER" "$CREDS_FILE"
chmod 600 "$CREDS_FILE"

# Instalación completada -- ya no tiene sentido ofrecer "Instalar FacturaScripts"
# en el menú (es una instalación única de todo el sistema, no por usuario). Se
# quita el lanzador del menú (compartido) y del Escritorio de quien lo ejecutó
# (personal). El script real (/opt/solwed/install-facturascripts.sh) se deja
# intacto -- sigue sirviendo de red de seguridad para cualquier copia de
# /etc/skel/Desktop que llegue a una cuenta nueva después de este punto: al
# encontrar "$WEBROOT" ya creado, ofrece abrir el navegador en vez de
# reinstalar.
rm -f /usr/share/applications/solwed-facturascripts-instalar.desktop
rm -f "$DESKTOP_DIR/solwed-facturascripts-instalar.desktop"

# ...y en su lugar, un acceso directo real a FacturaScripts (abre
# directamente la URL ya instalada, sin que el usuario tenga que teclearla).
# En el menú (compartido, para todas las cuentas) y en el Escritorio de quien
# instaló. Mismo Exec que ya usa install-facturascripts.sh para abrir el
# navegador tras instalar, para no tener dos formas distintas de hacer lo mismo.
cat > /usr/share/applications/solwed-facturascripts.desktop <<'EOF'
[Desktop Entry]
Type=Application
Version=1.0
Name=FacturaScripts
Name[es]=FacturaScripts
Comment=Abrir FacturaScripts (facturación y contabilidad) en el navegador
Comment[es]=Abrir FacturaScripts (facturación y contabilidad) en el navegador
Exec=xdg-open http://localhost/facturas
Icon=web-browser
Terminal=false
Categories=Office;Finance;
EOF
cp /usr/share/applications/solwed-facturascripts.desktop "$DESKTOP_DIR/solwed-facturascripts.desktop"
chown "$ORIG_USER:$ORIG_USER" "$DESKTOP_DIR/solwed-facturascripts.desktop"
chmod +x "$DESKTOP_DIR/solwed-facturascripts.desktop"
update-desktop-database /usr/share/applications >/dev/null 2>&1 || true

echo "100"; echo "# Listo."
