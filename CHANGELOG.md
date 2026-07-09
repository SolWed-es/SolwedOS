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

## Alpha 2.6.0 — azul de fábrica en el tema de cursores (en progreso, 2026-07-08)

Pendiente desde el bug #4/aparcado en la 2.2: el circulito de carga (spinner) y varios cursores más se veían azules en vez de con el acento amarillo. La hipótesis del plano de cursor por hardware (VM vs GPU real) quedó **descartada**: eso solo cambia cómo se compone el cursor, nunca su color — no explica una diferencia de tono.

**Causa real, confirmada abriendo los ficheros Xcursor byte a byte:** el tema de cursores `Fluent-cursors`/`Fluent-dark-cursors` es un binario (formato Xcursor, no CSS ni SVG) con el azul de AnduinOS **incrustado directamente como píxeles** en las insignias de ciertos cursores — `progress`/`watch`/`wait` (spinner de carga), los cursores de redimensionar (`size_hor`, `size_ver`, las esquinas, `sb_h_double_arrow`...), `alias`, `link`, `context-menu`, `all-scroll`, etc. El Nivel 1 solo recoloreó el **tema de iconos** (`Fluent-yellow`, escritorio/apps) — el tema de *cursores* es un asset totalmente distinto que nunca se tocó, así que seguía con el azul de fábrica en cualquier build, VM o hardware real (la comparación Proxmox-amarillo/Dell-azul de la 2.2 no era una pista fiable: eran builds distintas, 1.0.0 vs 2.5.0).

**Fix:** escrito un parser/editor de Xcursor en Python (formato simple: TOC + chunks de imagen ARGB32 crudo) que recorre cada fichero, detecta píxeles con matiz azul (170°-250°) y un rango de color apreciable (para no disparar en el ruido de antialiasing casi-negro de los cursores normales — ese fue el primer intento, con falsos positivos en `default`/`left_ptr`/`text` de unos pocos píxeles cada uno, descartados con un umbral mínimo de 80 píxeles por fichero) y rota el matiz a nuestro amarillo (#F5E70A) conservando saturación/brillo/alpha originales — así se respeta el sombreado y el antialiasing de cada insignia, no es un tinte plano. 56 de los 111 ficheros de cada tema llevaban esta insignia azul; el resto (cursor básico, texto, manita, etc.) no se tocan. Assets en `branding/cursors/{Fluent-cursors,Fluent-dark-cursors}/cursors/`.

**Confirmada en el Dell — 2026-07-08.** Spinner de carga y cursor de redimensionar en amarillo Solwed, sin efectos secundarios en el resto de cursores. Bug del acento en cursores (aparcado desde el bug #4/2.2.0) cerrado del todo.

## Auditoría de Ubiquity (instalador) — 2026-07-08

Petición: revisar qué de AnduinOS se cuela en el instalador (Ubiquity). Resultado de la auditoría:

**Sin riesgo, no hace falta tocar nada:**
- `99anduinos-rime-setup` y `anduinos-clean-wrapper` (hooks de `target-config` de Ubiquity): funcionales, no cosméticos (setup de Rime solo si detecta locale chino; limpieza de un binario tras instalar). Sin texto ni imágenes.
- No hay slideshow de Ubuntu (`ubiquity-slideshow-ubuntu` no está instalado) — pero **sí hay uno propio de AnduinOS**, ver más abajo.
- Ningún texto "AnduinOS" hardcodeado en el propio Ubiquity (`.ui`/Python) — los títulos como "Install RELEASE" se sustituyen dinámicamente desde `.disk/info`, ya en "Solwed OS".
- Iconos/mapas del paquete `ubiquity-ubuntu-artwork` (zonas horarias, particionador): artwork genérico de Ubuntu, sin logos ni texto.
- El icono de la ventana de Ubiquity usa el mecanismo estándar `distributor-logo` (mismo que el badge de GDM) — no hay `distributor-logo-anduinos`, así que se ve el genérico de fábrica del tema Fluent (un engranaje gris). No es AnduinOS, pero tampoco es Solwed — pendiente de decidir si merece la pena rebrandearlo (mismo truco que el icono de ArcMenu).

**Causa raíz de los botones/enlaces en azul dentro de Ubiquity (y potencialmente en cualquier app GTK3) — encontrada:**
`/usr/share/glib-2.0/schemas/99-anduinos-defaults.gschema.override` fija los defaults de sistema para toda sesión nueva: `gtk-theme='Fluent-round-Dark'` e `icon-theme='Fluent-dark'` — las variantes **neutras**, no las `-yellow`. La variante `Fluent-round-yellow-Dark` ya lleva nuestro `#F5E70A` incrustado (87 veces — sí se recoloreó en el Nivel 1), pero nunca se activó como default real. Lo que sí se ve amarillo en el escritorio (fondo, iconos, spinner) funciona porque las extensiones `accent-gtk-theme@brgvos`/`accent-icons-theme@brgvos`/`accent-user-theme@brgvos` (ya habilitadas en el mismo override) parchean esto en caliente dentro de GNOME Shell — pero Ubiquity corre como proceso aparte (`sudo ubiquity gtk_ui`, ver `anduinos-installer`), fuera de esa magia, y hereda el default estático neutro/azul.

**Fix (pendiente de aplicar):** cambiar en el override `gtk-theme='Fluent-round-yellow-Dark'` e `icon-theme='Fluent-yellow-dark'` — más fiable que depender de que la extensión llegue a tiempo, mismo criterio que ya seguimos con los cursores. Requiere recompilar el caché de esquemas (`glib-compile-schemas /usr/share/glib-2.0/schemas/` dentro del chroot) para que surta efecto — mismo tipo de trampa que initramfs/casper.conf, si no se recompila el cambio no se nota.

**El slideshow propio de AnduinOS (paquete `anduinos-installer-config`, por eso no salió en la primera búsqueda por nombre de paquete) — pendiente, aplazado a la sesión de mañana:**
`usr/share/ubiquity-slideshow/slides/l10n/es/` tiene 7 diapositivas (bienvenida, apps, desarrollo, gaming, privacidad, open-source, soporte) con texto real sobre AnduinOS y enlaces a `anduinos.com`, `docs.anduinos.com`, `github.com/Anduin2017/AnduinOS`. Las capturas de pantalla (`screenshots/*.png`) llevan la marca horneada como píxeles — `sc.png` es literalmente un pantallazo del repositorio de GitHub de AnduinOS con su logo y nombre visibles. `welcome.png`/usada de fondo en 2 diapositivas es un fondo abstracto azul genérico (sin texto, pero muy "de marca AnduinOS" en tono).

Decisión pendiente para mañana: qué hacer con las menciones a infraestructura propia de AnduinOS que Solwed no tiene (Apkg como "nuestra" herramienta de paquetes, docs/soporte en dominios de AnduinOS) y para qué idiomas actualizarlo (solo `es`, o también el fallback sin carpeta de idioma). El resto de idiomas (en, fr, de...) no se tocarán salvo que se pida explícitamente — no los verá ningún cliente de un despliegue en español.

## Alpha 2.7.0 / 2.8.0 — cierre de los últimos pulidos del Nivel 2 (2026-07-09)

Tres pegas menores que quedaban abiertas del Nivel 2, más el fix del azul en Ubiquity de la auditoría anterior:

1. **"Mostrar clima" no venía activado por defecto.** Rastreado el checkbox real (app `anduinos-appearance`, Panel derecho → Apariencia → Widgets) hasta que solo lee/escribe `org.gnome.shell enabled-extensions` para `simple-weather@romanlefler.com` — la extensión ya estaba instalada y preconfigurada (`/etc/dconf/db/anduinos.d/18-simple-weather.conf` con `is-activated=true`), pero nunca en la lista de extensiones activadas por defecto. Añadida al override de `99-anduinos-defaults.gschema.override` + `glib-compile-schemas`. **Confirmado.**
2. **Teclado por defecto en inglés (`us`).** `/etc/default/keyboard` heredado de AnduinOS sin tocar. Corregido a `XKBLAYOUT="es"` / `XKBVARIANT="winkeys"` (Español (Windows)), más un bloque explícito `[org.gnome.desktop.input-sources] sources=[('xkb', 'es+winkeys')]` en el override para que la sesión GNOME en sí (no solo consola/GDM) también arranque en español. **Confirmado.**
3. **Mismo bug de fondo que el azul de Ubiquity, pero en la barra superior de GNOME Shell.** `/etc/dconf/db/anduinos.d/03-system-extensions.conf` tenía `[org/gnome/shell/extensions/user-theme] name='Fluent-round-Dark'` — el tema de **Shell** (barra superior/overview) seguía en la variante neutra, tema distinto del GTK de apps y de iconos. Corregido a `Fluent-round-yellow-Dark`, aplicado con `dconf update` (no `glib-compile-schemas`, es un override de dconf puro, no de gschema).
4. **Aplicado por fin el fix de la auditoría anterior:** `gtk-theme='Fluent-round-yellow-Dark'` / `icon-theme='Fluent-yellow-dark'` en `99-anduinos-defaults.gschema.override`, con `glib-compile-schemas` re-ejecutado después (confirmado por la fecha del `gschemas.compiled` posterior a la del override).

**Investigación aparte, cerrada sin encontrar bug — "flash" del Plymouth de AnduinOS:** el usuario vio una vez el spinner viejo de AnduinOS (pequeño, esquina superior izquierda, texto "Anduin...OS") en un arranque del Dell. Extraído `casper/initrd.gz` directamente de la ISO construida (`7z e` + `unmkinitramfs`) para comprobar sin especular: `default.plymouth` apunta correctamente a `solwedos/solwedos.plymouth` en el initrd real, y el tema gráfico `anduinos` ni siquiera va empaquetado (solo sobrevive `anduinos-text`, el fallback de consola). El contenido real de la ISO no puede producir ese splash — se descarta como artefacto puntual de hardware/pantalla, no reproducible, no se investiga más sin una repetición.

## Slideshow de Ubiquity reescrito en los 27 idiomas soportados (2026-07-09)

Continuación de la auditoría anterior. Dos decisiones de alcance confirmadas por el usuario: (a) quitar las menciones a infraestructura exclusiva de AnduinOS (Apkg, docs.anduinos.com, enlaces al repo/discusiones de GitHub) pero conservar el resto del contenido técnico, redirigiendo el soporte a `solwed.es/contacto`; (b) hacerlo en las **27 carpetas de idioma** bajo `l10n/`, no solo `es`, más el fallback en inglés sin prefijo de carpeta (`slides/` raíz) — reescritura multilingüe completa.

Ejecutado con 26 subagentes en paralelo (uno por idioma, salvo español e inglés hechos a mano como referencia), cada uno con el mismo patrón de edición: brand swap AnduinOS→Solwed OS en todos los ficheros; `welcome.html` sin la mención a repositorio propio de paquetes/Apkg; `apps.html` sin el párrafo de Apkg, retitulado "tres capas"→"dos capas"; `build.html`/`gaming.html`/`privacy.html` solo brand swap; `root.html` sin el enlace al código fuente en GitHub, reescrito como "software libre con licencia GPL" genérico; `support.html` reescrito para quitar docs.anduinos.com y el enlace a discusiones de GitHub, con redirección a `solwed.es/contacto`. Las 189 páginas (27 idiomas × 7 diapositivas) verificadas limpias (`grep -ri "anduin|aiursoft"` sin resultados).

El usuario decidió no corregir una lista de erratas/gramática preexistentes de las propias traducciones de AnduinOS (heredadas, no introducidas por este rebrand) detectadas en ~10 idiomas durante la revisión — fuera de alcance, explícitamente aparcado.

**Capturas de pantalla del slideshow — aparte, aplazadas a propósito:** 5 de las 6 capturas (`usr/share/ubiquity-slideshow/slides/screenshots/`) llevan marca de AnduinOS incrustada en los propios píxeles, no como overlay de texto — revisadas una a una. `sc.png` es directamente un pantallazo del repo de GitHub "AnduinOS 2"; `jb.png` y `pv.png` muestran salidas de `neofetch` con "AnduinOS X.X.X"; `st.png` y `gaming.png` tienen detalles menores (usuario "anduin" visible). Decisión: esperar a tener un sistema arrancable/instalado con el Nivel 3 más avanzado para tomar capturas reales de Solwed OS, en vez de retocar píxeles o usar placeholders genéricos.

Horneado en `custom-root/usr/share/ubiquity-slideshow/slides/` (staging en `slideshow-fix/` de este repo) — confirmado sin ningún resto de "anduin" en el árbol final.

## Alpha 3.0.0 — Nivel 3: LibreOffice y Thunderbird preinstalados (2026-07-09)

Primer paso del Nivel 3 (comportamiento y apps).

- **LibreOffice:** `apt-get install libreoffice` sin sorpresas — suite completa (Writer/Calc/Impress/Draw/Base/Math) más integración GNOME/GTK3.
- **Bug de `add-apt-repository` con cualquier PPA (no solo el de Thunderbird) — causa raíz encontrada:** el rebrand del Nivel 1 (`ID=solwedos` en `/etc/os-release`) rompió en silencio un mecanismo propio que AnduinOS trae para sí mismo. Dos ficheros en cadena:
  1. `NoDistroTemplateException: could not find a distribution template for solwedos/resolute` — `add-apt-repository` resuelve las reglas de un PPA desde `/usr/share/python-apt/templates/<ID>.info`. AnduinOS trae el suyo propio (`anduinos.info`, del paquete `anduinos-software-properties-common`, su fork sin publicidad de Ubuntu Pro de `software-properties-common`) — pero `custom-root` tenía instalado el paquete genérico de Ubuntu en su lugar (con toda probabilidad sustituido por una resolución de dependencias de un `apt-get install` anterior, no un purgado deliberado), que no trae ese fichero.
  2. `FileNotFoundError: /usr/share/distro-info/solwedos.csv` — el `.info` rellena sus placeholders `{series}`/`{codename}` desde un CSV al estilo `distro-info-data`, buscado igual por ID.

  Arreglo en los dos casos: copiar el fichero correspondiente (`anduinos.info` → `solwedos.info`, `anduinos.csv` → `solwedos.csv`) desde la ISO limpia de referencia ya extraída — son recursos estáticos genéricos (`{series}`/`{codename}`, sin texto "anduinos" dentro), una copia con el nombre nuevo basta, sin editar contenido.
- **Thunderbird real, no snap:** instalado vía `ppa:mozillateam/ppa` con un pin agresivo (`/etc/apt/preferences.d/mozillateam-thunderbird.pref`, `Pin: release o=LP-PPA-mozillateam` / `Pin-Priority: 1001`) para que gane siempre sobre el paquete transicional de Ubuntu (que solo tira del snap) — necesario porque AnduinOS ya tiene `snapd` des-priorizado (`no-snap.pref`, prioridad -10), así que el paquete transicional fallaría directamente.
- **Plugin de WhatsApp Web en Thunderbird preinstalado:** comparadas 4 extensiones de addons.thunderbird.net, elegida "WhatsApp Web in Thunderbird" (GUID `wa-in-th@ftassy.github.io`, v1.4.2) por ser la de mayor adopción (3189 usuarios) con buena nota (4/5), frente a alternativas con muchos menos usuarios o peor valoradas. Instalada por sideload global: `custom-root/usr/lib/thunderbird/distribution/extensions` es un symlink (del propio paquete) a `../../thunderbird-addons/distribution/extensions/`, y `extensions.autoDisableScopes=3` (perfil+usuario, no aplicación) confirma que cualquier `.xpi` ahí se activa solo. `.xpi` versionado en `thunderbird-addons/` de este repo.

**Confirmado en el Dell — 2026-07-09.** LibreOffice y Thunderbird "funcionan a la perfección".

## Alpha 3.1.0 — carpeta LibreOffice y Thunderbird en el menú de inicio, acceso directo de FacturaScripts (2026-07-09)

- **Carpeta "LibreOffice" en ArcMenu con las 7 apps reales** (excluido `libreoffice-xsltfilter.desktop`, filtro interno con `NoDisplay=true`) y **Thunderbird anclado directo**. Mecanismo de ArcMenu, sin documentación oficial, encontrado leyendo su propio JS: una carpeta es una entrada más en `pinned-apps` con forma `{'id': '<uuid>', 'name': '<nombre>', 'isFolder': 'true'}`, cuya lista de apps real vive en una instancia de esquema reubicable en `pinned-apps-folders/<uuid>/` (clave `pinned-apps`, mismo formato). Como dconf no distingue esquemas reubicables de fijos, es simplemente una segunda sección `[org/gnome/shell/extensions/arcmenu/pinned-apps-folders/<uuid>]` más en `10-arcmenu.conf`.
- **Instalador gráfico de FacturaScripts bajo demanda** (`facturascripts-installer/`): icono de escritorio → `zenity` de progreso → instala Apache+PHP+MySQL+FacturaScripts vía `pkexec`, genera credenciales de BD aleatorias y las deja en un `.txt` en el escritorio. Deliberadamente **no preinstalado** en la ISO (mantiene la base ligera) — patrón distinto al de LibreOffice/Thunderbird, instala solo si el cliente lo pide.
- **Gotcha de "acceso directo no confiable" en el escritorio, resuelto de forma reutilizable.** Un `.desktop` suelto en `/etc/skel/Desktop/` aparece como "no confiable" hasta que la extensión `ding@rastersoft.com` (Desktop Icons NG) ve el atributo GVFS `metadata::trusted`, que es metadata de sesión por usuario, no algo horneable en la imagen. Fix: `/usr/lib/solwed/trust-desktop-shortcuts.sh` (confía + da permiso de ejecución a todo `.desktop` en `$HOME/Desktop`) enganchado vía `/etc/xdg/autostart/solwed-trust-desktop-shortcuts.desktop`, corre en cada login, barato e idempotente — mecanismo permanente para cualquier acceso directo futuro, no solo este.

## Alpha 3.1.1 — arregla el instalador de FacturaScripts: no hacía nada, y mod_rewrite no cargaba (2026-07-09)

1. **El instalador parecía "no hacer nada" al ejecutarlo.** Causa arquitectónica, no un typo: el `.desktop` original hacía `Exec=pkexec /opt/solwed/install-facturascripts.sh`, elevando **todo el script a root, incluido cada `zenity`**. Esta ISO es Wayland puro (`custom-root/usr/share/wayland-sessions/gnome.desktop`, sin ninguna sesión Xorg disponible) — un proceso root no puede abrir ventanas en la sesión Wayland de un usuario normal (al contrario que en X11, donde `pkexec` sí preserva `DISPLAY`/`XAUTHORITY` para esto). Cada `zenity` fallaba en silencio (su error iba al log, invisible) y la instalación moría casi al instante, sin hacer trabajo real.

   **Fix — patrón general para cualquier instalador `pkexec`+GUI en esta ISO:** separar en dos scripts. `install-facturascripts.sh` (el `Exec=` del `.desktop`, sin `pkexec`) corre como el usuario normal y es dueño de todos los `zenity`; solo eleva el trabajo real con `pkexec /opt/solwed/install-facturascripts-worker.sh | zenity --progress ...` — en una tubería, solo el comando de la izquierda se eleva, el `zenity` de la derecha sigue siendo un proceso normal de la sesión del usuario. El worker no llama a ningún GUI, solo emite el protocolo de `zenity --progress` (`echo "N"` / `echo "# mensaje"`) y manda la salida ruidosa de cada comando (`apt-get`, `mysql`...) a un log aparte. **Confirmado en la Dell — 2026-07-09**, ya se ve la barra de progreso y termina la instalación.

2. **Aviso "Módulo de Apache no encontrado: mod_rewrite" al abrir FacturaScripts.** Real, no cosmético — rompe las URLs limpias de FacturaScripts. Causa: el propio paquete `apache2` arranca el servicio solo nada más instalarse (comportamiento estándar de Debian), antes de que el worker llegue a `a2enmod rewrite` — que solo crea un symlink en disco, no recarga Apache. El `systemctl enable --now apache2` posterior no hacía nada porque el servicio ya estaba activo (`--now` no reinicia un servicio ya en marcha). Fix: `systemctl enable apache2` + `systemctl restart apache2` incondicional justo después de `a2enmod`. Aplicado al worker y confirmado con un `systemctl restart apache2` manual en la instalación ya existente — **pendiente de confirmar con una instalación limpia desde cero** en la próxima ISO generada.
