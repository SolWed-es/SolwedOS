# Changelog — Solwed OS

Registro de qué se aplicó en el chroot de Cubic en cada sesión, y por qué. Vive fuera de la ISO, en este repo.

## [Sin publicar]

### Infraestructura del proyecto Cubic
- Proyecto movido de `/mnt/c/Users/Alex Ruiz/Documents/...` (disco Windows, 9p) a `/home/aruizb/cubic-projects/SolwedOS` (ext4 nativo) — el `Extract` fallaba silenciosamente sobre 9p (`is_success_extract = False`), dejando `casper/` sin `filesystem.squashfs` y causando el kernel panic. Confirmado `is_success_extract = True` en el proyecto nuevo.
- Desactivada la opción **"OS Release"** de Cubic (`update_os_release = False`) para que no sobreescriba `PRETTY_NAME`/`DISTRIB_DESCRIPTION` cada vez que se pasa por la Terminal.

### Nivel 1 — Identidad visual
- [x] Identidad del sistema (`/etc/os-release`, `/etc/lsb-release`) — URLs de soporte apuntando a `solwed.es/contacto`. Kernel `vmlinuz-7.0.0-27-generic`/`initrd.img-7.0.0-27-generic`, compresión squashfs `zstd`.
- [x] Fondo de pantalla y bloqueo — `solwed-claro.png`/`solwed-oscuro.png` en `/usr/share/backgrounds/solwed/`, registrados en `gnome-background-properties/solwed.xml` y `dconf/db/anduinos.d/21-solwed-wallpaper.conf`.
- [x] Iconos, cursores y acento de color — tema `Fluent-round-yellow` reescrito a `#F5E70A` (oscuro) / `#F2D040` (claro, ajustado para contraste), `accent-color='yellow'` en `dconf/db/anduinos.d/22-solwed-accent.conf`.

Nivel 1 completo. Pendiente: generar la ISO y probar en VM (identidad + fondo + acento juntos, primera vez sobre el proyecto en `/home/aruizb/cubic-projects/SolwedOS`).

### Bug estructural AnduinOS + Cubic (arranque UEFI) — 2026-07-07
Tras arreglar el `is_success_extract`, la ISO seguía dando el mismo kernel panic (`file '/casper/initrd' not found` → `VFS: Unable to mount root fs`). Causa real, nada que ver con nuestros cambios: la partición EFI (`partition-2.img`, FAT16, ~10MB) trae un `EFI/BOOT/grub.cfg` que busca el disco por **UUID fijo** derivado de la fecha de creación del ISO9660 original (`search.fs_uuid efdc52a6-9723-436f-8473-6aee910fb771`), y si lo encuentra, apunta a una ruta absoluta **del ordenador de build de AnduinOS** (`/home/anduin/Desktop/AnduinOS-2/image/isolinux/boot/grub`). Cualquier ISO regenerada (con Cubic o cualquier otra herramienta) tiene una fecha de creación distinta → UUID distinto → la búsqueda falla → GRUB no encuentra su menú real y cae en un fallback roto. Esto afecta a **cualquier** rebuild de AnduinOS, con o sin personalización.

Arreglado editando ese `grub.cfg` embebido (con `mtools`/`mcopy`, ya que 7z no escribe en imágenes FAT) para que use el mismo mecanismo robusto que ya usa el resto de la ISO — buscar por el archivo marcador `/anduinos` en vez de por UUID:
```
search --set=root --file /anduinos
set prefix=($root)/isolinux/boot/grub
configfile $prefix/grub.cfg
```
Aplicado directamente en `partition-2.img` del proyecto — **corrección**: ese no es el archivo que se empaqueta en el ISO final. El que de verdad importa es `custom-disk/EFI/efiboot.img`; ahí se aplicó el fix definitivo y sobrevivió al Generate.

### Arranque correcto confirmado — 2026-07-07
Primer arranque sin errores. Tras activar EFI en la VM (antes estaba en BIOS) y aplicar el fix del `efiboot.img`, la ISO llegó a GRUB y al kernel sin fallos — la pantalla en negro posterior no era un bug nuestro, sino falta de **Aceleración 3D** en la VM de VirtualBox (GNOME/Wayland moderno la necesita). Solucionado subiendo memoria de vídeo a 128MB y activando "Aceleración 3D" en Configuración → Pantalla. Nivel 1 (identidad, fondo, acento) validado en un arranque real.

### Bug: fondo negro y sin iconos tras instalar (solo en sistema instalado, no en live) — 2026-07-07
Probado en hardware real (Dell Latitude 5490, no VM): el modo live arranca perfecto (fondo, iconos, acento todo bien), pero tras instalar con Ubiquity, GDM entra en una sesión con fondo negro y sin ningún icono (barra/dash/escritorio) — las ventanas de aplicaciones normales (Firefox) sí se ven y funcionan.

**Causa raíz:** `journalctl` mostraba spam de `gnome-shell: Failed to load resource:///org/gnome/shell/theme/background.png: Loader process exited early with status '0'`. Rastreado hasta `/usr/bin/bwrap` (bubblewrap, usado por gdk-pixbuf/glycin para decodificar imágenes en sandbox) — es un wrapper (`#!/bin/sh\n/usr/bin/bwrap.real "$@" 2>/dev/null || true`) que llama al binario real `bwrap.real` y **enmascara cualquier fallo devolviendo siempre 0**. El fallo real, visible en `sudo journalctl -b -k | grep apparmor`: el perfil de AppArmor `bwrap-userns-restrict` (concretamente su sub-perfil `unpriv_bwrap`, que por diseño hace `audit deny capability` para evitar escaladas de privilegio dentro del namespace) estaba denegando `CAP_SYS_ADMIN` a `bwrap.real`, rompiendo cualquier decodificación de imagen que pasara por ahí (fondo, iconos del shell) mientras apps con su propio decodificador (Firefox) seguían intactas.

Confirmado con la ISO de referencia limpia (`reference/anduinos-clean-iso/`) que el wrapper y el perfil AppArmor son **estrictamete de fábrica de AnduinOS/Ubuntu** (idénticos byte a byte a nuestro `custom-root`) — no es una regresión de nuestra personalización. Es un caso límite conocido de la función de Ubuntu de restricción de user namespaces sin privilegios, que el propio comentario del perfil admite como imperfecto ("bwrap will still have to be fairly loose until a transition at namespacing in general is available").

Por qué solo falla instalado y no en live: pendiente de entender del todo (probablemente diferencias de carga/caché de AppArmor entre el overlay de casper y el disco real), pero no bloquea el fix.

**Fix aplicado (probado en caliente primero con `sudo apparmor_parser -R .../bwrap-userns-restrict`, confirmado que soluciona fondo+iconos):** en vez de editar el perfil de Ubuntu, se añadió un symlink en el mecanismo estándar de AppArmor para que el perfil arranque en modo *complain* (audita pero no bloquea) — igual que ya hace AnduinOS con `usr.sbin.sssd`:
```
ln -s /etc/apparmor.d/bwrap-userns-restrict /etc/apparmor.d/force-complain/bwrap-userns-restrict
```
Aplicado en `custom-root/etc/apparmor.d/force-complain/`. Reversible sin tocar el perfil original; sobrevive a actualizaciones del paquete `apparmor`.

**Confirmado end-to-end — 2026-07-07:** ISO regenerada en Cubic con el symlink ya horneado en `custom-root`, instalada de cero en el Dell Latitude 5490 (no en caliente sobre una instalación previa). Fondo, iconos y acento correctos desde el primer arranque tras instalar. Bug cerrado.

## Nivel 2 — Arranque y login (en progreso, 2026-07-08)

Investigación de los 4 puntos del manual antes de tocar nada:

- **GRUB: sin trabajo pendiente.** `GRUB_DISTRIBUTOR` ya resuelve a `NAME="Solwed OS"` (viene de `/etc/os-release`, Nivel 1), y `GRUB_TIMEOUT=0` + `GRUB_TIMEOUT_STYLE=hidden` significa que el menú nunca se renderiza — no hay texto visible que rebrandear. Se descarta tocar el fondo de GRUB por ahora: vive en el mismo `EFI/efiboot.img` que causó el bug estructural de arranque UEFI, y no aporta valor visible con el menú oculto.
- **Plymouth (splash de arranque):** usa el módulo `two-step` (no un `.script` custom), lo cual reduce el riesgo de una pantalla negra silenciosa por script mal escrito. El watermark (`watermark.png`, 300×61, alineado abajo-centro) y el fallback de firmware (`bgrt-fallback.png`, 96×96) son los dos assets a sustituir. Generados a partir de `imagenes_Solwed/LogoSolwed.svg` — el SVG es en realidad un cuadrado negro con la marca "W." recortada en negativo (fill-rule nonzero), así que se extrajo la marca sola invirtiendo el canal alfa para tener un glifo blanco sobre transparente, apto para el fondo negro de Plymouth. Assets finales en `branding/plymouth/`. Script preparado: `scripts/level2-01-plymouth.sh` (fork del tema `anduinos` → `solwedos`, registro vía `update-alternatives`, `update-initramfs -u`). **Pendiente de ejecutar y boot-test en aislamiento** (sin mezclar con el cambio de GDM, es el único de los 4 puntos que puede causar un kernel panic si algo va mal).
- **GDM3 (fondo de login):** encontrado el mecanismo nativo de AnduinOS — el paquete `anduinos-gdm3-wallpaper` trae `/usr/bin/anduinos-gdm-set-wallpaper`, que genera un `gdm-theme.gresource` a partir de cualquier imagen y lo registra vía `update-alternatives` sobre `/usr/share/gnome-shell/gdm-theme.gresource`. No hace falta tocar dconf ni gresources a mano. Reutiliza `solwed-oscuro.png` (ya baqueado en Nivel 1). Script preparado: `scripts/level2-02-gdm-login.sh`. No toca initramfs/kernel — no puede causar panic, solo un login feo en el peor caso. **Pendiente de ejecutar**, después de validar Plymouth por separado.
- **MOTD:** descartado por ahora — solo se ve por TTY/SSH, ningún cliente en escritorio gráfico lo verá. Baja prioridad.

**Plymouth confirmado — 2026-07-08:** `level2-01-plymouth.sh` ejecutado y probado en el Dell Latitude 5490. Arranca perfecto con el tema `solwedos`.

**GDM confirmado, con 3 pegas — 2026-07-08:** `level2-02-gdm-login.sh` ejecutado (sin `--darken`, ver más abajo). Funciona, pero:

1. **El panel de login (usuario/contraseña) se superpone al logo "SOLWED.es".** Causa: `solwed-oscuro.png`/`solwed-claro.png` (en `imagenes_Solwed`/`custom-root/usr/share/backgrounds/solwed/`) llevan el logo centrado en el lienzo — justo donde GDM centra su panel. Arreglado: logo reposicionado al 90% de la altura (abajo, centrado horizontalmente) en ambas imágenes, clonando y difuminando el fondo sobre la posición antigua para no dejar costura visible. Nuevas versiones en `branding/wallpapers/solwed-{oscuro,claro}.png`. Como estas mismas imágenes se usan para fondo de escritorio (Nivel 1) y fondo de bloqueo, el reposicionado corrige los tres sitios a la vez — pendiente de copiar al chroot y volver a correr `level2-02-gdm-login.sh` para regenerar el gresource con la posición nueva.
2. **El menú de arranque live dice "Try or Install AnduinOS".** Es texto plano en `custom-disk/boot/grub/grub.cfg` e `custom-disk/isolinux/grub.cfg` (fuera del chroot, son los archivos reales que carga el `grub.cfg` embebido vía el fix del bug estructural EFI — no una plantilla intermedia). Corregido directamente ahí mismo (soy dueño del archivo, sin sudo) a "Try or Install Solwed OS" / "Try or Install Solwed OS (Safe Graphics)" / "Solwed OS To Go (Persistent on USB)". **Pendiente de verificar tras el próximo Generate** — por precaución, igual que con el `efiboot.img`, comprobar que Cubic no lo regenera desde otra plantilla.
3. **Con tema claro, el fondo de bloqueo (Súper+L) apenas tiene contraste** — `solwed-claro.png` era casi blanco puro y el panel de desbloqueo se leía mal encima. **Confirmado en caliente en el Dell (2026-07-08):** forzar `org/gnome/desktop/screensaver picture-uri` al wallpaper oscuro no cambia nada al bloquear con tema claro — este gnome-shell (Ubuntu/AnduinOS resolute) ignora esa clave y reutiliza directamente `org/gnome/desktop/background` (picture-uri/picture-uri-dark, según el tema activo). Revisados los esquemas glib disponibles: no existe ninguna clave independiente para el fondo de bloqueo — usa la misma imagen que el escritorio, sin excepción.

   Sin una clave de config que lo resuelva, la única vía es la propia imagen. Decisión: oscurecer `solwed-claro.png` de forma global y moderada (factor ×0.80 sobre RGB, de ~248 a ~198 de media) en vez de limitarlo a la franja donde cae el panel — sigue leyéndose como tema claro pero da margen suficiente al desenfoque/oscurecido que ya aplica GNOME por defecto en el bloqueo. Aplicado en `branding/wallpapers/solwed-claro.png` (ya incluye también el reposicionado del logo del punto 1).

## Alpha 2.2.0 — confirmada en el Dell (2026-07-08)

Nivel 2 funcionando de punta a punta: Plymouth, GDM, menú de arranque y las 3 pegas de arriba, todo probado en hardware real.

## Alpha 2.3.0 — pulido visual del splash y reposicionado del logo (en progreso, 2026-07-08)

Dos pegas de acabado sobre la 2.2.0:

1. **Watermark de Plymouth: de icono suelto a wordmark.** Antes solo mostraba la marca "W." (el icono de `LogoSolwed.svg`). Ahora dice "Solwed OS" + el icono, imitando el lockup de `solwed.es`. El texto se renderiza con la fuente **Ubuntu Bold** (variable font ya instalada en el host, coincide con la base Ubuntu de AnduinOS; Cantarell —la que declara el tema Plymouth— no está instalada como paquete en el chroot, así que no había garantía de que se viera en el arranque real).

   El icono "W." también lleva ahora el acento amarillo de Solwed en la 1ª y 3ª de sus 4 líneas diagonales, igual que la V amarilla del wordmark `solwed.es`. Como el SVG fuente es un único `<path>` (cuadrado negro con la marca recortada en negativo vía fill-rule), no hay una forma directa de aislar "la línea 1" o "la línea 3" — se resolvió calculando, fila a fila, los 4 tramos horizontales que forman el trazo en zigzag (contando "runs" de píxeles activos por fila) y recoloreando por posición dentro de esos 4 tramos, no por sub-trazo del SVG. Aplicado también en `bgrt-fallback.png` (mismo icono, sin texto, por consistencia). Nuevos assets en `branding/plymouth/`, script de aplicación: `scripts/level2-03-plymouth-v2.sh` (solo sustituye los dos PNG dentro del tema `solwedos` ya forkeado y regenera initramfs, no vuelve a registrar la alternativa).

2. **El logo se solapaba con la barra de tareas del escritorio.** El reposicionado de la 2.2.0 (90% de la altura) evitaba el panel de GDM pero quedaba demasiado bajo para el escritorio real, donde la barra de tareas (dash-to-panel, abajo) tapaba el texto. Subido al **80% de la altura** en ambos wallpapers — compromiso entre no chocar con el panel de login (centro) y no chocar con la barra de tareas (borde inferior). Reaplicado también el oscurecido de contraste (×0.80) sobre la versión clara tras el reposicionado. Assets actualizados en `branding/wallpapers/`.

**Confirmada en el Dell — 2026-07-08.** Wordmark "Solwed OS" + W. con acento amarillo en el splash, y logo del wallpaper ya sin chocar con la barra de tareas ni con el panel de login. Nivel 2 cerrado.

**Observación sin resolver — cursor de carga (circulito animado junto al puntero):** en Proxmox se ve del amarillo-naranja de acento de Solwed; en el Dell se mantiene azul (color por defecto). El tema de cursores `Fluent-cursors` es único y neutro — no hay variantes de color por accent-color como sí las hay para los iconos (`Fluent-yellow`, `Fluent-orange`, etc.), así que ese circulito no es un cursor XCursor estático sino que lo pinta GNOME Shell/Mutter en tiempo real leyendo `accent-color`.

Hipótesis de sesión Xorg/XWayland **descartada**: `echo $XDG_SESSION_TYPE` da `wayland` en ambos (Dell y Proxmox), 2026-07-08. Nueva hipótesis, sin confirmar: Mutter puede delegar el cursor a un plano de hardware (KMS cursor plane) en GPUs reales (Intel UHD 620 del Latitude) por rendimiento, mientras que en la VM de Proxmox (virtio-gpu/QXL) no hay ese plano y compone el cursor por software — si el indicador de carga se genera como parte de esa imagen compuesta, la ruta por hardware podría no llevar el recoloreado por acento. Sin confirmar sin logs en vivo del Dell (`journalctl -b | grep -i cursor` mientras se abre una app, misma metodología que el bug #4). **Aparcado por baja prioridad/cosmético** — el acento en sí ya funciona correctamente en fondo e iconos.

## Alpha 2.4.0 — usuario live, hostname y logo del panel de login (en progreso, 2026-07-08)

Dos pegas más detectadas tras confirmar la 2.3.0:

1. **Usuario de la sesión live y hostname seguían con marca AnduinOS.** `/etc/casper.conf` tenía `USERNAME="live"` con `USERFULLNAME="AnduinOS Live session user"` y `HOST="anduinos"`/`FLAVOUR="AnduinOS"`. Comprobado en `/usr/share/initramfs-tools/scripts/casper` que el mecanismo de fallback que deriva usuario/host de `.disk/info` solo se activa si `FLAVOUR` está vacío — como aquí siempre está seteado, nuestros valores explícitos si se respetan, así que basta con editarlos directamente. De paso se encontró que el hostname del **sistema instalado** (`/etc/hostname`) también seguía en `anduinos`, un descuido separado del live. Corregido: `USERNAME="solwed"`, `USERFULLNAME="Solwed OS Live session user"`, `HOST="solwedos"`, `FLAVOUR="SolwedOS"`, y `/etc/hostname` → `solwedos`. Son ficheros de texto plano — no hace falta el terminal chroot de Cubic, un `sudo` normal desde el host basta.

2. **El logo "Anduin + ANDUINOS" abajo del panel de login/bloqueo.** No tenía nada que ver con nuestro wallpaper (que ya se ve bien, con "SOLWED.es" arriba) — es un elemento CSS separado (`.login-dialog-logo-bin`) que gnome-shell dibuja usando la clave `org/gnome/login-screen logo`. Encontrada en `/etc/gdm3/greeter.dconf-defaults` (fichero ini simple de Debian/Ubuntu para defaults del greeter, no pasa por el mecanismo de perfiles dconf — no existe `/etc/dconf/profile/gdm` en este sistema):
   ```
   [org/gnome/login-screen]
   logo='/usr/share/pixmaps/anduinos_text_smaller.png'
   ```
   `anduinos_text_smaller.png` es 300×61, el mismo tamaño que el watermark original de Plymouth (mismo asset reutilizado en dos sitios). Sustituido por el wordmark "Solwed OS" + W. con acento amarillo de la 2.3.0 (`branding/gdm/solwedos-login-logo.png`), y la clave `logo=` actualizada para apuntar ahí. Mismo mecanismo de texto plano, sin chroot necesario.

**Confirmado — el logo del panel de login/bloqueo ya sale bien (2026-07-08). El usuario/hostname del live seguía en AnduinOS pese a haber editado `casper.conf`** — causa encontrada: `/usr/share/initramfs-tools/hooks/casper` copia `/etc/casper.conf` DENTRO del `initrd.gz` en el momento de compilarlo (`cp /etc/casper.conf ${DESTDIR}/etc`); editar el fichero en `custom-root` no sirve de nada si no se regenera el initramfs después — el initrd de la ISO seguía llevando la copia vieja. Mismo tipo de trampa que ya nos pasó con Plymouth. Fix: `update-initramfs -u -k all` dentro del chroot tras el edit (sin volver a tocar `casper.conf`, ya estaba bien).

## Alpha 2.5.0 — apariencia y menú de inicio (en progreso, 2026-07-08)

Tres pegas más:

1. **Live/hostname seguían en anduinos** — ver el bug del initrd de arriba, resuelto con `update-initramfs -u -k all`.
2. **App "Apariencia de AnduinOS" en el menú de inicio.** Es `anduinos-appearance.desktop` (paquete `anduinos-appearance`, cambia entre layout de barra de tareas estilo 11 y clásico). Cambiado `Name=` y `Name[es_ES]=` a "Solwed OS Appearance"/"Apariencia de SolwedOS" — el `Icon=`, `Exec=` y `StartupWMClass=` internos se dejan intactos (son identificadores del binario, no texto de marca).
3. **Icono del botón de inicio en la barra de tareas** (el que despliega el menú ArcMenu). En `/etc/dconf/db/anduinos.d/10-arcmenu.conf` las claves `custom-menu-button-icon` y `menu-button-icon` ya apuntan a un fichero configurable: `/usr/share/gnome-shell/extensions/arcmenu@arcmenu.com/icons/anduinos-logo.svg` (96×96). No hace falta tocar dconf — basta con sustituir ese fichero. Construido `branding/panel/anduinos-logo.svg`: un SVG mínimo que envuelve el mismo icono "W." con acento amarillo (el `bgrt-fallback.png` de la 2.3.0) como imagen embebida en base64, para conservar el nombre/formato de archivo que ArcMenu espera sin tener que reconstruir el trazado como vector puro.

**Confirmada en el Dell — 2026-07-08.** Live arranca como `solwed@solwedos`, app "Apariencia de SolwedOS" y el botón de inicio con la W. de acento amarillo, todo correcto. Con esto se cierra del todo el rebranding de identidad/arranque/login (Niveles 1-2 y sus pulidos posteriores).
