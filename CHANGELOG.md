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

## Alpha 3.1.2 — LibreOffice se cerraba solo al segundo de abrir, instalado (2026-07-10)

Bug #5, misma clase que el de Alpha 2.2.0 (bwrap) pero causa distinta. Solo en sistema instalado, no en live. LibreOffice Writer mostraba el splash y se cerraba solo ~1s después, sin ventana, sin error.

Descartado en orden: el perfil AppArmor propio de `libreoffice-soffice.bin` (desactivado del todo, sin cambio); el tema de iconos `Fluent-yellow-dark` (probado con Adwaita, mismo fallo); el plugin VCL de GTK4 (forzado `SAL_USE_VCLPLUGIN=gtk3`, mismo fallo — prueba de que el fallo está por debajo de la capa de toolkit, en el pipeline de decodificación de imagen en sandbox de glycin que usa cualquier app GTK); versiones/librerías de `glycin-loaders` (todo resuelto limpio con `ldd`).

**Causa real:** `/usr/bin/bwrap` (el mismo wrapper del bug de Alpha 2.2.0, del paquete `anduinos-bwrap-hack`) es un script de shell, no un `exec` directo del binario real. El cargador de SVG en sandbox de glycin se invoca con file descriptors concretos (`--seccomp <fd>`, `--dbus-fd <fd>`) que el proceso llamador espera que lleguen intactos al hijo — la capa extra de `fork+wait` del wrapper no los conserva, así que el cargador muere en ~10ms sin llegar a su propio código, y el wrapper enmascara el fallo real (`2>/dev/null || true`). Confirmado con `RUST_LOG=debug soffice --writer` (glycin trae logging real) y ejecutando `bwrap.real` directamente sin el wrapper, que sí dio un error específico y correcto.

**Fix:** sustituir el cuerpo del wrapper por un `exec` directo, sin fork intermedio:
```
#!/bin/sh
exec /usr/bin/bwrap.real "$@"
```
Script en `scripts/fix-bwrap-wrapper.sh`. **Confirmado en live y en instalado** — a diferencia del bug de AppArmor (que solo se manifestaba instalado), aquí se verificó explícitamente en los dos casos antes de cerrar, por precaución.

**Incidente durante el diagnóstico, aparte:** una edición en caliente escribió por error sobre `/usr/bin/bwrap` real (en vez de `bwrap.real`) un script que se auto-referenciaba, causando un bucle infinito de `exec` que colgaba toda la sesión gráfica tras reiniciar (parecía "no arranca", en realidad GDM/glycin colgado, no un fallo de kernel/arranque). Sin backup del binario ELF real a mano, se optó por reinstalar la ISO limpia en el Dell en vez de perseguir una recuperación in-situ — la máquina de pruebas no guarda nada único y el build en sí nunca se vio afectado (la corrupción fue en el sistema instalado, no en el chroot). Lección: al editar scripts críticos del sistema en caliente, escribir siempre a un archivo temporal + `mv` atómico, y verificar la ruta destino dos veces antes de ejecutar.

## Locale, teclado y navegador — confirmado sin diagnosticar en sesión (2026-07-10)

El usuario confirma que locale/teclado/zona horaria ya funcionan bien (aplicado en una sesión anterior no capturada aquí en detalle). El plan de navegador cambia respecto al manual original: en vez de mantener el Firefox propio de AnduinOS con `policies.json`, **se desinstala Firefox por completo y se instala Brave**. Sin detalles capturados todavía de configuración de Brave (homepage/marcadores) — pendiente si se retoma.

## ArcMenu — pin de Firefox obsoleto tras pasar a Brave (2026-07-10)

El cambio de navegador dejó la barra de tareas actualizada (`favorite-apps` en `99-anduinos-defaults.gschema.override` ya tenía `brave-browser.desktop`), pero el **pin del menú de inicio** (`pinned-apps` en `10-arcmenu.conf`) seguía apuntando a `firefox.desktop`, que ya no existe. Confirmado que el id correcto es `brave-browser.desktop` (no `com.brave.Browser.desktop`, que tiene `NoDisplay=true`, un duplicado de emparejamiento de portal). Corregido con `sed` + `dconf update`.

**Lección general:** cualquier app sustituida/quitada necesita un `grep` sobre **todos** los `.conf` de `anduinos.d/` — los pines pueden vivir en más de un sitio (favoritos de barra, pines de menú, carpetas de ArcMenu) y solo se actualiza el que alguien recuerda tocar.

## FacturaScripts — confirmado extremo a extremo, incluida la entrega de credenciales (2026-07-10)

El worker (`facturascripts-installer/install-facturascripts-worker.sh`) crea una base de datos MySQL (`facturascripts_db`, usuario `facturascripts`, contraseña aleatoria de 20 caracteres) y la deja en `~/Desktop/FacturaScripts-datos-acceso.txt` (permisos 600) para pegar en el asistente de primer arranque de FacturaScripts. El asistente pide además unas credenciales de "Administrador" separadas (el login de la propia app) que el script no genera — las elige el cliente libremente en ese paso.

## Nivel 3 — Autofirma, Okular, Remmina (2026-07-10)

- **Remmina** ya estaba instalado de fábrica (`remmina`, `remmina-plugin-rdp`, `remmina-plugin-vnc`...) — solo verificado, sin acción. *(Nota: se probó y se retiró más adelante, ver la entrada de Alpha 4.0.0 más abajo.)*
- **Okular** — `apt-get install okular`, elegido sobre Xournal++ (solo anotación) y Master PDF Editor (de pago) por su soporte nativo de firma digital, buen acompañamiento de Autofirma.
- **Autofirma 1.9** (firma electrónica española, `.deb` en `autofirma-installer/`) — instalado con `dpkg -i` + `apt-get install -f` (deps `openjdk-11-jre`, `libnss3-tools`).
  - **Bug encontrado — confianza de certificado no llega a Chromium/Brave.** El instalador de Autofirma solo registra su certificado raíz en el almacén de confianza del **sistema** (`/etc/ssl/certs`) y en el perfil NSS de Firefox (que ni siquiera existe en build). Chromium/Brave usa su propio Chrome Root Store, no el almacén del sistema — la confianza local debe ir a la base NSS por usuario. Fix: script de primer login `trust-autofirma-cert.sh` (mismo patrón que `trust-desktop-shortcuts.sh`) que puebla el certificado en las dos rutas NSS posibles por usuario (`~/.pki/nssdb` y `~/.local/share/pki/nssdb`, según versión de Brave), idempotente vía `certutil -L` antes de `-A`.

## Curación de paneles, ronda 2 (2026-07-10)

Thunderbird movido del pin de menú de inicio al favorito de la barra de tareas (a la izquierda de Brave); Remmina/Okular/Autofirma añadidos al menú de inicio. IDs `.desktop` reales verificados uno a uno contra variantes decoy (`org.remmina.Remmina.desktop`, no `org.remmina.Remmina-file.desktop`; `org.kde.okular.desktop`, no los `okularApplication_*` por tipo de archivo; `afirma.desktop`, todo en minúsculas pese a que la app se llama "Autofirma"). Favoritos de barra vía gschema override (`glib-compile-schemas`); pines de menú vía dconf (`dconf update`) — dos mecanismos distintos, no confundir.

## Recoloreo de iconos de apps, azul→amarillo (2026-07-10)

El tema `Fluent-yellow`/`Fluent-yellow-dark` solo recolorea un subconjunto genérico (carpetas/chrome) — varios iconos de apps individuales traen su azul fijo dentro del propio SVG. Script `scripts/recolor_svg_icons.py` (sustitución de hex por regex + rotación de matiz) aplicado a Software, Loupe, Text Editor, Geary, Calendar, Amberol, Apariencia (Solwed), Characters, config de red, e icono del instalador de FacturaScripts. Requiere `gtk-update-icon-cache -f -t <tema>` después — la caché binaria del tema no se invalida sola.

**Ronda 2 — gap real encontrado (2026-07-10, tras boot-test de Alpha 3.2.0):** el icono de Software/FacturaScripts (mismo archivo, `org.gnome.Software.svg` == `system-software-install.svg`) quedó "medio arreglado" — asa amarilla, cuerpo de la bolsa azul. Causa: ese SVG no es vector puro, embebe un **PNG en base64** para el cuerpo de la bolsa; el script de sustitución de hex solo tocó los trazos vectoriales. Terminal Ptyxis tampoco estaba en el lote original (no un bug, solo fuera de alcance la primera vez). Ambos corregidos: Ptyxis con el mismo script; el icono de Software/FacturaScripts con uno nuevo (`scripts/fix_software_bag_icon.py`) que revierte los 3 trazos vectoriales a su azul original (era un intercambio de dos tonos deliberado, no "todo amarillo") y recolorea el PNG embebido por separado. **Lección: comprobar `base64` en cualquier SVG de este set antes de fiarse de un fix por sustitución de hex.**

## Alpha 3.2.0 — confirmada en el Dell (2026-07-10)

Primer build que agrupa todo lo de arriba desde 3.1.2: fix del pin de Brave, Autofirma+cert-trust, Okular, Remmina, Thunderbird movido a favorito, recoloreo de 10 iconos. Usuario: "funciona a la perfección".

## Logo "W." de dos tonos mal coloreado + wallpapers nuevos — encontrado, parcialmente aplicado (2026-07-10)

Wallpapers nuevos de mayor resolución (`Fondo_SolwedOS_Claro/Oscuro.png`, artwork más profesional aportada por el usuario) sustituidos sin tocar configuración (mismos nombres de archivo fijos) — **aplicado y confirmado**.

La marca "W." (dos V superpuestas — izquierda amarilla sólida, derecha blanca sólida, más un punto) estaba mal en el watermark de Plymouth y el icono del ArcMenu: las dos piernas "internas" (las más cercanas al cruce) tenían el color de la V contraria. Script `scripts/fix_w_logo_colors.py` (primera versión, heurística por tamaño de mancha conectada) escrito y validado sobre copias — **el primer intento de aplicarlo al chroot no surtió efecto** (mtimes sin cambiar), aparcado para la sesión siguiente. *(La causa real de por qué no aplicó nunca se determinó; y cuando sí se aplicó más tarde, resultó que el propio algoritmo también tenía un fallo — ver la entrada de Alpha 4.0.0 más abajo para el arreglo definitivo.)*

## Alpha 3.2.1 — confirmada en el Dell (2026-07-10)

Corrige lo que a 3.2.0 le faltó del recoloreo de iconos: Ptyxis y el icono de Software/FacturaScripts (bug del PNG embebido). Usuario: "está genial". Baseline vigente hasta el commit del repo del 13 de julio.

## Repo committed — 2026-07-13, commit `c79877d`

Puesta al día del repositorio de Git tras varias sesiones de trabajo sin comittear: Autofirma/Okular/Remmina, curación de paneles ronda 2, recoloreo de iconos (rondas 1 y 2), el intento fallido del logo W., y los wallpapers nuevos. Excluido `autofirma-installer/Autofirma_Linux_Debian.zip` (64MB) del control de versiones — es el mismo `.deb` ya versionado sin extraer del zip, duplicarlo no aporta nada.

## Logo "W." — arreglado de verdad, commit `9dec73a` (2026-07-13)

El intento de Alpha 3.2.0 se reintentó y esta vez sí se aplicó a los archivos reales — pero comparando contra una captura de referencia real aportada por el usuario (`imagenes_Solwed/Logo_Solwed.PNG`), resultó que el propio algoritmo de la primera versión del script tenía un fallo estructural: dejaba 3 de los 4 trazos en amarillo cuando debían alternar Y-W-Y-W entre las dos V. La heurística de "mancha más grande = ancla, manchas de color contrario que la tocan cambian de color" no era lo bastante fiable para separar las dos V.

**Reescrito `fix_w_logo_colors.py` de raíz** para usar la captura de referencia como fuente de verdad en vez de adivinar estructura: clasifica la referencia en un campo continuo de amarillez, recorta el sub-área de la marca en el asset roto (saltándose cualquier texto tipo "Solwed OS" a su izquierda, detectando el hueco de columnas vacías **más a la derecha**, no el más ancho — el espaciado entre palabras del propio texto puede ser más ancho que el hueco real texto→marca), y remapea cada píxel del asset roto por posición normalizada contra la referencia.

Verificación completa antes de cerrar: mtimes/tamaños de archivo, comparación de secuencia de color fila a fila contra la referencia (alternancia Y-W-Y-W confirmada, no solo conteo de manchas — el primer intento fallido había "pasado" esa comprobación más superficial), render visual lado a lado, y tras que el usuario ejecutara `update-initramfs -u -k all`, extracción del `initrd.img` regenerado y comparación byte a byte del `watermark.png` embebido contra el del chroot.

## Timeshift añadido y anclado al menú (2026-07-13)

`apt-get install -y timeshift`, sin configuración adicional. Anclado al menú de inicio (`pinned-apps` en `10-arcmenu.conf`), verificado por timestamp de recompilación de dconf y `strings` sobre la base binaria compilada.

## Remmina instalado y retirado — corrección de alcance (2026-07-13)

Al plantear mover "software RDP" del Nivel 4 al Nivel 3 porque "ya teníamos Remmina instalado", se aclaró que son dos cosas distintas: Remmina es un cliente para que el **usuario** se conecte él mismo hacia fuera por RDP/VNC; el punto de Nivel 4 "Soporte remoto preconfigurado" es la dirección contraria — un agente para que **Solwed** entre al equipo del cliente (tipo TeamViewer/AnyDesk). Una vez aclarado, se decidió que Remmina no aportaba valor por sí solo y se retiró por completo: `apt-get purge -y remmina remmina-common remmina-plugin-rdp remmina-plugin-secret remmina-plugin-vnc`, desanclado de `10-arcmenu.conf`, verificado sin rastro ni en `dpkg` ni en la base dconf compilada.

## Manual reescrito al estado real del proyecto — commit `df52a43` (2026-07-13)

`solwed-os-manual.html` seguía siendo el plan especulativo original, con varios datos ya superados por `ANDUIN-BASELINE.md` (LightDM mencionado pero solo existe GDM3, dconf en `local.d` en vez de `anduinos.d`, `VERSION_CODENAME=noble` en vez de `resolute`, `ID_LIKE=ubuntu` en vez de `debian`, base de Plymouth `spinner` en vez de `anduinos`) y sin documentar nada de lo realmente aplicado. Reescrito nivel a nivel con insignias de estado (✓ Hecho / ↻ Cambiado / ○ Pendiente), tarjetas nuevas para trabajo no contemplado en el plan original (caso de estudio del logo W., patrón pkexec+Wayland para instaladores propios, mecanismo real de ArcMenu, confianza de iconos de escritorio), y una sección nueva "Bugs conocidos de la plataforma" documentando los tres bugs recurrentes con causa raíz y fix (EFI grub.cfg, AppArmor bwrap-userns-restrict, wrapper de bwrap). Verificado con un chequeo de balance de etiquetas HTML y auditoría de enlaces internos rotos antes de comittear, no solo una vista previa visual.

## Alpha 4.0.0 — arranca el Nivel 4: soporte remoto con RustDesk — commit `9527cb3` (2026-07-13)

Primer punto del Nivel 4, elegido por ser el de más impacto de cara al cliente y menos dependiente de los otros dos (repo APT propio, asistente de bienvenida). Decisión: **RustDesk autoalojado** en vez de un agente 100% propio (open source, cliente ya hecho y rebrandeable, sin coste de licencia). Alcance de esta ronda: **solo el lado cliente** — sin servidor (`hbbs`/`hbbr`) todavía, explícitamente aplazado.

- Instalado el `.deb` oficial de RustDesk 1.4.9 (`rustdesk-installer/`), sin recompilar nada.
- **Mecanismo de preconfiguración verificado contra el código fuente real** (`hbb_common`, no la especulación de la GUI): `~/.config/RustDesk/RustDesk2.toml`, con `rendezvous_server` como string de nivel superior más una tabla `[options]` con `custom-rendezvous-server`, `relay-server`, `api-server`, `key` — nombres de constante confirmados en el propio código (`OPTION_CUSTOM_RENDEZVOUS_SERVER` etc.), `custom-rendezvous-server` con prioridad sobre `rendezvous_server` en la resolución. Plantilla en `rustdesk-installer/RustDesk2.toml`, apuntando a un dominio placeholder (`remoto.solwed.es`, no existe todavía) hasta desplegar el servidor real. Depositada en `/etc/skel/.config/RustDesk/` — cubre tanto el usuario live (casper regenera su home desde `skel` en cada arranque) como cualquier cuenta futura tras instalar, sin script adicional.
- **Bug real del propio paquete, neutralizado:** el `postinst` de RustDesk hace `systemctl enable rustdesk; systemctl start rustdesk` incondicionalmente — el servicio de **acceso desatendido** (`rustdesk --service`, root, sin presencia del usuario, contraseña permanente), justo lo que el manual pide no activar por defecto. Verificado (no solo asumido) que ese bloque nunca se ejecutó en el chroot de Cubic: no existe `rustdesk.service` en ningún árbol de `systemd/` salvo la plantilla original del paquete — si el `postinst` lo hubiera copiado alguna vez, `systemctl disable` no habría borrado el archivo de la unidad, solo el enlace de activación. Su ausencia total demuestra que el bloque entero se saltó, no que se ejecutó y se deshizo.
- **Confirmado también en real** (no solo en el chroot): tras generar la ISO y arrancar en el Dell, `systemctl status rustdesk` devuelve "could not be found" — cierra el ciclo de verificación en real que quedó pendiente.
- **Probado el flujo de consentimiento con el servidor público de RustDesk** (temporalmente, restaurado el placeholder después): funciona bien, con latencia alta esperable — el servidor gratuito compartido (`rs-ny.rustdesk.com`, Nueva York) está congestionado y lejos de España; exactamente el caso de negocio real para tener servidor propio.

## Nivel 4 — arranca el repositorio APT propio — commit `f75de66` (2026-07-13)

Mismo patrón de alcance que RustDesk: preparación del lado cliente, servidor pendiente. Herramienta elegida para cuando se monte: **aptly**, sobre `reprepro`.

- Generada una clave GPG dedicada (RSA 4096, caduca a 2 años — fuerza rotación por diseño). Solo la parte **pública** se versiona en el repo (`apt-repo/solwed-repo-signing-key.asc` armored, `apt-repo/solwed.gpg` binario) y se preinstala en `/etc/apt/trusted.gpg.d/` — segura de dejar activa sin repo real, una clave de confianza sin ningún `sources.list` que la use no hace nada.
- **El `sources.list` se deja sin activar a propósito** — a diferencia de la clave, un fichero en `/etc/apt/sources.list.d/` se consulta en cada `apt update`, y fallaría visiblemente contra un dominio que no existe. Queda como plantilla (`apt-repo/solwed.list.template`, dominio placeholder `repo.solwed.es`) hasta tener servidor real.
- **Incidente de seguridad, autocorregido en la misma sesión:** la clave privada se imprimió por accidente en el chat antes de entregarse solo como ruta de archivo. Como no había firmado nada real todavía, se optó por revocarla y regenerar una nueva desde cero en vez de arriesgarse — la segunda generación se entregó exclusivamente como ruta de archivo en la propia máquina del usuario, nunca impresa. Nueva regla general adoptada: cualquier secreto se entrega como ruta de archivo, nunca pegado en el chat.
- Despliegue del servidor (`aptly repo create/add`, `snapshot create`, `publish snapshot`, patrón de publicación sin downtime con `publish switch`) documentado en el manual, sin ejecutar — no hay servidor todavía.

**Infraestructura para el servidor — en discusión con el jefe, sin decidir (2026-07-13):** valorados un portátil de oficina (descartado para producción por falta de IP pública estable y fiabilidad de hardware no pensado para 24/7) y CloudPanel (viable — no de forma nativa, sino usándolo para el subdominio/TLS sobre un VPS Debian/Ubuntu real, con `aptly` instalado y gestionado aparte por SSH). Dado lo ligero de los requisitos (1 vCPU, ~1GB RAM, pocos GB de disco), la recomendación es reutilizar infraestructura ya existente antes que dedicar una máquina nueva.

## Fondo del login (GDM) desincronizado — encontrado y preparado, sin ejecutar (2026-07-14)

Usuario reportó que la pantalla de login (Alpha 4.0.0 recién generada) seguía mostrando el wallpaper "antiguo". Investigado sin asumir nada: la pantalla de bloqueo de sesión (Super+L) no tenía el problema, solo el login GDM previo a entrar — pista de que no es el mismo mecanismo.

Causa confirmada por mtime: `anduinos-gdm-set-wallpaper` no lee el PNG en cada arranque, lo compila **una vez** en `/var/lib/anduinos-gdm3-wallpaper/solwedos-theme.gresource` (registrado vía `update-alternatives`). Ese binario se generó el 8 de julio con el wallpaper original; cuando se sustituyó `solwed-oscuro.png` por la versión de mayor resolución (10-13 de julio, mismo nombre de archivo), nadie volvió a compilar el `.gresource` — se quedó con el contenido antiguo horneado dentro. Mismo patrón que otros bugs de este proyecto (`icon-theme.cache`, `gschemas.compiled`, initramfs): un binario derivado de un fuente, sin recordatorio de regenerarlo cuando el fuente cambia.

**Fix ya preparado, no ejecutado todavía (a petición del usuario, para el próximo lote antes de un Generate):** `scripts/level2-02-gdm-login.sh` ya existía y hace exactamente lo necesario (recompila + reactiva vía `update-alternatives`), es idempotente, no requirió cambios. Documentado como bug nuevo en el manual (`solwed-os-manual.html`, tarjeta `#bug-gdm-stale-cache` en "Bugs conocidos de la plataforma", más un aviso en la tarjeta `#item-login`) para que la regla ("recompilar el login cada vez que cambie el wallpaper fuente") no se pierda la próxima vez que se toquen los wallpapers.

**Confirmado que sí se aplicó** (verificación pedida por el usuario en la misma sesión): el `.gresource` tenía mtime posterior al PNG fuente (recompilado ese mismo día), la cadena de `update-alternatives` resolvía al archivo correcto con prioridad 160, y el `background.png` extraído del `.gresource` con `gresource extract` coincidía píxel a píxel (dimensiones + muestreo) con el wallpaper actual — no solo "el comando no dio error".

## GRUB — tema gráfico, timeout, e idioma por defecto del ISO (2026-07-14)

Petición del usuario tras cerrar el fix del login: tema de marca Solwed para el GRUB del sistema instalado, timeout de 5s con Solwed OS como entrada por defecto, y que el menú de selección de idioma del propio ISO (al arrancar el USB) resalte "Spanish" por defecto en vez de inglés.

**Tema gráfico — sintaxis verificada contra el manual oficial de GRUB (`Theme file format`) vía fetch real, no adivinada.** Nuevos assets en `grub-theme/`: `theme.txt`, `background.png` (mismo wallpaper oscuro ya usado en todo el proyecto), y 3 fuentes `.pf2` (título 30px, ítems de menú 18px, contador de cuenta atrás 13px). Menú sin iconos ni cajas de pixmap (estilo minimalista, texto con resaltado amarillo Solwed `#F5E70A` en el ítem seleccionado), fondo con `desktop-image-scale-method: stretch` (el wallpaper, 1672×941, ya tiene casi el mismo aspect ratio que 16:9).

**Gotcha de fuentes, mismo patrón que el caso del logo "W.":** `Ubuntu-B.ttf` en este sistema es un symlink al font variable `Ubuntu[wdth,wght].ttf`, sin instancia "Bold" real y separada. Resuelto el índice de instancia correcto con `fc-match -f '%{file}:%{index}' "Ubuntu:bold"` (fontconfig sabe seleccionar instancias con nombre en fonts variables) y verificado contra la tabla `fvar` del propio archivo con `fontTools` en Python que ese índice (327680 = instancia 5, 1-indexed) corresponde de verdad a peso 700 ("Bold") antes de pasarlo a `grub-mkfont -i`. `grub-mkfont` mismo resultó ejecutable directamente desde el host (mismo binario ELF de `custom-root`, sin necesitar el chroot) — es una herramienta de conversión de fuentes sin dependencias del sistema objetivo, no del tipo que necesita correr dentro del chroot.

Comportamiento en `/etc/default/grub`: `GRUB_TIMEOUT_STYLE=menu` (antes oculto), `GRUB_TIMEOUT=5`, `GRUB_DEFAULT=0` (ya era Solwed OS, sin cambios reales), `GRUB_GFXMODE=1920x1080,auto`. Aplicado por `scripts/level2-04-grub-theme.sh` (nuevo, sigue el mismo patrón de los demás scripts de Nivel 2 — copiar a `/root/` y ejecutar dentro del terminal chroot). Probado el `sed` idempotente de reemplazo de claves contra una copia real del `/etc/default/grub` del chroot antes de dar el script por bueno. **Preparado, no ejecutado** — igual que el fix del login GDM de este mismo día, queda para el próximo lote antes de Generate. Solo verificable tras una instalación real (Ubiquity genera el `grub.cfg` real con `update-grub`, no existe uno en el chroot para probar en live).

**Idioma por defecto del ISO — mecanismo totalmente distinto, ya aplicado directamente (no necesitó chroot).** El menú de idiomas del ISO en vivo no sale de `/etc/default/grub`: es un `grub.cfg` de texto plano escrito a mano, duplicado byte a byte en `custom-disk/boot/grub/grub.cfg` (EFI) y `custom-disk/isolinux/grub.cfg` (BIOS). A diferencia de `custom-root/`, `custom-disk/` no es de root — editado directamente con este mismo Bash tool, sin sudo. Cambiado `set default="0"` → `set default="0>11"` (sintaxis de índice compuesto de GRUB: elemento 0 del menú raíz = el submenú "Try or Install Solwed OS", elemento 11 dentro de él, contando desde 0, = "Spanish"/`es_ES.UTF-8`) en ambos archivos. Verificado que siguen siendo idénticos entre sí tras el cambio y que el conteo de `menuentry` confirma que la entrada 11 es realmente Spanish, no otro idioma por error de conteo.

## Bug en pantalla de login: botones azules + toggle de "Estilo" roto (2026-07-14)

Usuario generó Alpha 4.1.0 e instaló — todo lo anterior funcionó, pero reportó dos problemas nuevos en la pantalla de login (GDM, sin sesión iniciada): los botones de WiFi/Accesibilidad/Teclado están en azul (no amarillo Solwed), y el interruptor de modo claro/oscuro no hace nada visible.

**Causa raíz — no es una regresión nuestra, es un defecto heredado de la propia herramienta de AnduinOS que llevaba ahí desde el primer día (2026-07-08), nadie lo había notado hasta ahora:** `anduinos-gdm-set-wallpaper` tiene un paso ("Inject Fluent Theme") que sobreescribe **todos** los CSS extraídos del tema base con un único archivo estático (`/usr/share/anduinos-gdm3-wallpaper/fluent-gnome-shell/gnome-shell.css`) — confirmado idéntico byte a byte a la ISO de referencia limpia de AnduinOS, nunca tocado por ninguna personalización de Solwed. Ese CSS tiene el azul de acento de AnduinOS horneado dentro. Al no notarse antes: en Alpha 2.x-3.x todo el sistema seguía siendo azul, así que no destacaba; ahora que el resto está recoloreado a amarillo, sí.

**Recoloreado (azul → amarillo Solwed), mismo script ya existente (`scripts/recolor_svg_icons.py`, funciona sobre cualquier texto con hex, no solo SVG):** probado primero sobre una copia de scratch antes de tocar el chroot — 11 tonos de azul (hue ~213-215°, la rampa de acento hover/focus/activo) recoloreados, los grises y rojos/naranjas de estado de error (`#DD2C00`, `#FF5252`, `#440e00`, etc.) confirmados intactos, CSS sigue siendo válido (llaves balanceadas 856/856). Aplicar en dos pasos: recolorear el CSS fuente (host, `sudo python3`, no necesita chroot — es solo E/S de archivo) y volver a ejecutar `scripts/level2-02-gdm-login.sh` en el chroot para recompilar `solwedos-theme.gresource` con el CSS ya corregido (el fix del fuente no alcanza al `.gresource` ya compilado hoy).

**Toggle de "Estilo" (modo claro/oscuro) — investigado a fondo, resulta más profundo de lo esperado.** Verificado contra el código fuente real de GNOME Shell (`js/ui/status/darkMode.js`, GitLab de GNOME): el interruptor se registra **incondicionalmente** dentro del propio binario compilado de `gnome-shell` — no depende en absoluto del CSS que tocamos, ni de qué archivos `.gresource` existan. Solo lee/escribe la clave GSettings `org.gnome.desktop.interface color-scheme`. Ocultarlo de verdad requeriría parchear el binario de `gnome-shell` (no se reconstruye ningún paquete en este proyecto) o una extensión propia que corra en la pantalla de login — bastante más invasivo que cualquier cambio hecho hasta ahora, mismo tipo de riesgo que causó el incidente de "sesión gráfica colgada" al tocar `bwrap` a mano. **Decisión del usuario: documentar como limitación conocida** (heredada de AnduinOS, ni el sistema stock lo soporta realmente) — nuevas tarjetas en el manual (`#bug-gdm-fluent-css` en "Bugs conocidos", aviso en `#item-login`).

**RustDesk anclado al menú de inicio (2026-07-14):** estaba instalado desde Alpha 4.0.0 pero nunca se ancló a ArcMenu. `.desktop` correcto verificado (`rustdesk.desktop`, no `rustdesk-link.desktop` — ese es un ayudante oculto `NoDisplay=true` para enlaces `rustdesk://`, mismo tipo de decoy ya visto con Remmina/Okular/Autofirma). Añadido al final de `pinned-apps` en `10-arcmenu.conf`, tras `timeshift-gtk.desktop`. Probado el `sed` contra una copia antes de dárselo al usuario — cambia solo esa línea.

**Fondo del tema de GRUB sustituido por un asset dedicado (2026-07-14):** el usuario aportó `imagenes_Solwed/Fondo_Grub_Solwed.png` (1672×941) — patrón de hexágonos oscuro con el logo "W." disperso en dos tonos, sin el wordmark "SOLWED.es" que sí lleva el wallpaper normal de escritorio. Mejor opción que reutilizar `solwed-oscuro.png`: sin riesgo de que el wordmark choque con la caja del `boot_menu`. Sustituido en `grub-theme/background.png` (mismo nombre de archivo, `theme.txt` no necesitó cambios). Como el paso de copiarlo al chroot (`sudo cp -r grub-theme /root/`) todavía no se había ejecutado, no hizo falta ninguna re-sincronización — el usuario recibirá ya la versión nueva en cuanto ejecute los pasos pendientes.

**Pendiente de ejecutar, todo junto (checklist consolidado 2026-07-14):**
1. Host: `sudo python3 scripts/recolor_svg_icons.py .../fluent-gnome-shell/gnome-shell.css`
2. Host: `sudo cp -r grub-theme/ .../custom-root/root/`
3. Chroot: `bash scripts/level2-02-gdm-login.sh` (recompila fondo+CSS del login)
4. Chroot: `bash scripts/level2-04-grub-theme.sh` (instala el tema de GRUB, ya con el fondo nuevo)
5. Chroot: `sed` de `pinned-apps` en `10-arcmenu.conf` + `dconf update` (ancla RustDesk)

## Alpha 4.1.1 — confirmada en real (2026-07-14)

Todo lo de este día (fondo+CSS del login recompilados, tema de GRUB con el fondo de hexágonos, RustDesk anclado) generado y probado por el usuario: "todo funciona sin problema". Cierra el lote completo abierto tras el fix del fondo de login desincronizado — manual actualizado (`#item-grub`, `#item-login`, `#bug-gdm-stale-cache`, `#bug-gdm-fluent-css` con sus insignias/avisos de cierre).

## Plymouth y login vuelven a AnduinOS tras actualizar por Software (2026-07-14)

Usuario reportó, en la Alpha 4.1.1 ya instalada y funcionando, que tras actualizar el sistema desde GNOME Software el splash de arranque volvió a mostrar "ANDUINOS" en vez de la marca "W." de Solwed.

**Causa raíz confirmada contra el `postinst` real de los paquetes de AnduinOS (no supuesta):** tanto `plymouth-anduinos` como `anduinos-gdm3-wallpaper` hacen `update-alternatives --set` **incondicional** a su propio tema cada vez que se reconfiguran — no un `--install` pasivo que respetaría una elección manual, sino un `--set` forzado sin comprobar nada, disparado en cada instalación, reinstalación o actualización. Confirmado en ambos paquetes de la ISO de referencia limpia — comportamiento de fábrica de AnduinOS, no una regresión de Solwed, y se repetirá en cualquier actualización futura de esos dos paquetes, venga de `apt`, GNOME Software o `unattended-upgrades`. Esto es exactamente el tipo de riesgo que se planteó al decidir aplazar el `apt upgrade` general del proyecto (ver entrada anterior) — solo que aquí ocurrió sin que nadie ejecutara nada manualmente, por una actualización normal desde la tienda de software.

**Arreglo inmediato dado para la máquina ya afectada:** `sudo update-alternatives --set default.plymouth .../solwedos.plymouth` + `sudo update-initramfs -u -k all`.

**Prevención permanente — primer hook de APT de este proyecto.** Nuevo `alternatives-guard/` (`reassert-alternatives.sh` + `99-solwedos-alternatives-guard`, instalados por `scripts/level2-05-alternatives-guard.sh`): un `DPkg::Post-Invoke` que se dispara tras cualquier operación de `dpkg`/`apt` — incluida la que hace GNOME Software por debajo (PackageKit sobre `apt`) — y comprueba con un par de `readlink -f` baratos si `default.plymouth` o `gdm-theme.gresource` han vuelto a apuntar a AnduinOS; si es así, los reasigna a Solwed y regenera el initramfs. `|| true` en el propio hook para que un fallo del guardián nunca bloquee una actualización real. Sintaxis comprobada con `bash -n` antes de dar el script por bueno. **Preparado, no ejecutado** — pendiente del próximo lote antes de Generate, y solo verificable con una actualización real posterior (no hay nada que actualizar dentro del chroot para probarlo ahí).

## Auditoría completa de qué más puede revertir AnduinOS + guardián general (2026-07-14)

Usuario preguntó si había más cosas de AnduinOS que pudieran romper el sistema del mismo modo. Cruzada **cada** ruta personalizada en todo el proyecto contra `var/lib/dpkg/info/*.list` y `*.conffiles` de la ISO de referencia limpia, no por sospecha. Resultado: de todo lo tocado en este proyecto, **solo `/etc/casper.conf` está protegido como conffile de verdad** — todo lo demás son archivos de paquete normales, sobreescritos sin negociar en cualquier actualización relevante.

**Paquetes con superficie de riesgo real:** `anduinos-fluent-icon-theme` (13 iconos de apps + los dos temas de cursor completos — el de mayor alcance, deshace varias sesiones de recoloreo de golpe), `anduinos-appearance` (su propio icono), `gnome-shell-extension-arcmenu` (icono del botón de inicio *y* el menú entero curado en `10-arcmenu.conf`), `anduinos-dconf-defaults` (tema de GNOME Shell, logo del login, tema GTK/iconos, favoritos, teclado, widget del tiempo), `grub2-common` (todo `/etc/default/grub`, el trabajo de hoy), `base-files` (`/etc/os-release`/`/etc/lsb-release` — la identidad entera del sistema, el más peligroso, del que dependen GRUB y las plantillas de PPA de python-apt).

**Verificación con una falsa alarma real durante la auditoría, vale la pena dejarla anotada:** varios de los iconos ya recoloreados tenían mtime `1970-01-01` (época Unix), lo que en un primer momento pareció indicar que ya habían sido revertidos en silencio sin que nadie se diera cuenta. Comprobado con el método correcto (comparación de contenido hex contra la ISO de referencia, no mtime) que **seguían correctamente en amarillo** — el mtime en época resultó ser un artefacto de cómo se escribieron esos archivos concretos, no evidencia de nada. **Lección reforzada: mtime no es fiable como única prueba en este proyecto — ya lo era para detectar cambios "no aplicados", pero aquí además dio un falso positivo de "revertido". Comparar contenido real siempre que el mtime sugiera algo sospechoso.**

**Fix — mismo patrón del guardián de Plymouth/GDM, generalizado a todo lo anterior.** Copias conocidas-buenas extraídas del chroot ya verificado correcto (no re-derivadas de los scripts de recoloreo) en `branding/icons/`, `branding/cursors/` (reutiliza los cursores ya trackeados), `branding/panel/` (reutiliza el icono de ArcMenu ya trackeado), y un `branding/system-files/` nuevo que mapea `etc/`/`usr/share/glib-2.0/schemas/` tal cual. Nuevo `alternatives-guard/reassert-branding.sh`: compara cada archivo/directorio contra el sistema en vivo (`cmp`/`diff -rq`) y solo restaura y dispara lo necesario (`gtk-update-icon-cache`, `dconf update`, `glib-compile-schemas`, `update-grub`, cada uno condicionado a si realmente hubo cambio). Segundo hook de APT independiente (`99-solwedos-branding-guard`), separado del de alternativas para poder desactivar uno sin el otro. Lógica de `restore_if_diff` y de comparación de directorios probada de forma aislada (caso distinto/igual/fuente-ausente) antes de integrarla en el script real. Instalador: `scripts/level2-06-branding-guard.sh`.

**Deliberadamente fuera de alcance:** las diapositivas de Ubiquity (`anduinos-installer-config`) — solo importan en el medio de instalación en vivo, no en un sistema ya instalado recibiendo actualizaciones, que es el escenario real de este bug.

**Preparado, no ejecutado** — para el próximo lote antes de Generate, junto con el guardián de alternativas. Solo verificable con una actualización real de alguno de los paquetes listados.

**Corrección tras instalarlo y verificarlo (misma sesión):** la sección de cursores comparaba el directorio `cursors/` completo con `diff -rq` en vez de archivo a archivo — los cursores básicos (`default`, `text`, sus alias `arrow`/`left_ptr`/`xterm`) nunca llevaron azul que corregir (ver la entrada de recoloreo de cursores: excluidos a propósito por el filtro de ruido de antialiasing) así que nunca se trackearon en el repo, y esa ausencia se reportaba como "diferencia" en cada ejecución — no rompía nada (`cp -r` de origen no borra lo que no está en destino) pero copiaba de más innecesariamente. Cambiado a comparar archivo a archivo igual que el resto del script (`restore_if_diff`), coherente y sin falsos positivos. Confirmado con `readlink`/`ls -la` que esos archivos excluidos son legítimamente symlinks/ficheros nunca tocados, no un hueco real de cobertura.

## Alpha 4.2.0 — confirmada en real (2026-07-14)

Generada e instalada con todo lo de este día (login GDM azul→amarillo, tema de GRUB con el fondo de hexágonos, RustDesk anclado, ambos guardianes de APT instalados). Usuario: "parece que todo está en orden". Cierra el lote abierto tras el bug de reversión de Plymouth — pendiente de una actualización real futura para confirmar que los guardianes actúan cuando de verdad hace falta.

## Nivel 4 — servidor de RustDesk (`hbbs`/`hbbr`) desplegado (2026-07-14)

Primer despliegue de infraestructura de servidor del proyecto. Reutilizado el servidor de producción ya existente (`erpsolwed`, Debian 13 trixie, gestionado con CloudPanel) en vez de dedicar una máquina nueva, según lo ya valorado — 12 vCPU/32GB RAM/434GB libres, de sobra para lo que pide RustDesk. Puertos 21115-21119 no chocaban con nada de lo que ya corre ahí (nginx solo usa 80/443).

Desplegado con Docker (script oficial `get.docker.com`) + Docker Compose, `network_mode: host` (recomendación oficial de RustDesk, evita líos de NAT del contenedor) — puertos verificados contra la documentación real de `rustdesk.com/docs`, no adivinados: `21115/tcp` (test de NAT), `21116/tcp+udp` (registro de ID/latido, el único que necesita ambos protocolos), `21117/tcp` (relay de `hbbr`), `21118`/`21119` tcp (soporte de cliente web, opcional, incluidos igualmente). Abiertos en `ufw`. Confirmado con `docker compose ps` (ambos contenedores `Up`) y `ss -tulpn` (los 5 puertos escuchando).

**Sin dominio todavía** — `remoto.solwed.es` no tiene DNS configurado, fuera del alcance inmediato del usuario ahora mismo. Se usa la IP pública directa del servidor (`51.89.21.128`) en la plantilla del cliente mientras tanto. Descartado un reverse proxy de CloudPanel para esto: `hbbs`/`hbbr` hablan TCP/UDP crudo en sus puertos principales, no HTTP, así que el módulo `http` de nginx (lo que expone la UI de CloudPanel) no puede hacerles de proxy — ni falta que hace, el cliente se conecta directo a esos puertos.

**Plantilla de cliente actualizada** (`rustdesk-installer/RustDesk2.toml`): `custom-rendezvous-server`/`relay-server` = la IP, `key` = la clave pública real que generó `hbbs` en su primer arranque (dato público, pensado para repartir a los clientes — no es sensible como la clave privada del incidente del repo APT). Quitado `api-server` de la plantilla: apunta al servidor web de la versión Pro, que no se ha desplegado; dejarlo puesto solo añadiría una llamada fallida más al arrancar el cliente sin aportar nada en la versión OSS.

**Pendiente:** DNS de `remoto.solwed.es` (cuando el usuario pueda) — cambio trivial en la plantilla, no requiere tocar el servidor. Hornear la plantilla actualizada en `/etc/skel/.config/RustDesk/RustDesk2.toml` del chroot para el próximo lote. Repetir la prueba de conexión ya contra este servidor propio (la prueba anterior, exitosa pero con latencia alta, fue contra el servidor público de RustDesk).

## Conexión real confirmada contra el servidor propio + gap de preconfiguración encontrado (2026-07-14)

Con el sistema ya instalado (plantilla horneada en `/etc/skel/`), primera prueba real de RustDesk contra el servidor propio. Primer intento: "la ID no existe" al conectar desde Windows.

**Diagnóstico con evidencia, sin adivinar en ningún paso:**
- Confirmado que ambos IDs (Solwed OS y Windows) estaban registrados de verdad: `sqlite3 ~/rustdesk-server/data/db_v2.sqlite3 "SELECT id FROM peer;"` los devolvió a los dos. Descartado que fuera un problema de registro.
- El botón "Exportar configuración" de Windows produjo una cadena que no era base64 estándar. Encontrado el algoritmo real en el propio repo de RustDesk (`flutter/lib/common.dart`, clase `ServerConfig`, vía `gh api search/code` — no adivinado): cadena invertida + base64url de un JSON `{"host","relay","api","key"}`. Decodificada, confirmó que Windows sí tenía el servidor propio correctamente configurado — descartado también eso.
- Con ambos extremos aparentemente bien configurados y registrados, pero el intento de conexión sin dejar ningún rastro nuevo en el log del servidor (verificado con `docker compose logs --since` para no confundir con log de arranque antiguo), la petición de conexión no estaba llegando a usar el servidor propio en absoluto.

**Resuelto reintroduciendo la configuración a mano** en Configuración de red dentro de la propia app de RustDesk en el Solwed OS (los mismos 3 valores que ya tenía el archivo en disco) — tras eso, nuevo registro en el log y **conexión funcionando**, confirmada por el usuario.

**Causa raíz exacta sin determinar** — el archivo `RustDesk2.toml` heredado de `/etc/skel/` estaba bien escrito y la app sí se registraba con el servidor propio desde el arranque, pero algo no terminaba de aplicarse hasta pasar por la pantalla de ajustes a mano. **Consecuencia práctica documentada en el manual:** cada instalación nueva probablemente necesite ese paso manual una vez, hasta investigarlo a fondo — no bloquea el uso, pero rebaja la promesa de "preconfigurado sin tocar nada". Anotado como pendiente de investigación, no resuelto del todo.

## RustDesk zero-touch — bug cerrado, Alpha 4.3.1 (2026-07-15)

Causa raíz del gap dejado abierto el día anterior, encontrada leyendo el código fuente exacto de la librería que usa `hbb_common` para resolver rutas de configuración (`directories-next`/`xdg-rs/dirs`, función `project_dirs_from` en `src/lin.rs`): en Linux, el nombre de la app se normaliza a minúsculas antes de formar la ruta (`trim_and_lowercase_then_replace_spaces("RustDesk")` → `"rustdesk"`) — solo macOS/Windows respetan el casing original. Nuestra plantilla llevaba desde Alpha 4.0.0 sembrándose en `/etc/skel/.config/RustDesk/RustDesk2.toml` (mayúsculas, calcado del nombre del programa), una ruta que el binario en Linux **nunca lee**. Confirmado con logs de una instalación nueva sin tocar nada: la app arrancaba con config vacía y se conectaba de fábrica al servidor público (`rs-ny.rustdesk.com`), no al propio. El paso manual que "arreglaba" cada instalación no reescribía nada distinto de nuestra plantilla — simplemente la GUI escribe en la ruta real (minúsculas), la única que el binario usa.

**Fix:** sembrar la plantilla en `/etc/skel/.config/rustdesk/RustDesk2.toml` (minúsculas). Aplicado en el chroot y en el repo (`rustdesk-installer/skel-config/rustdesk/RustDesk2.toml`).

**Confirmado en real en Alpha 4.3.1:** instalación nueva, RustDesk abierto directamente sin tocar nada — Configuración de Red ya mostraba el servidor propio de fábrica. El objetivo "zero-touch" de este punto del Nivel 4 queda cerrado.

**Verificación adicional pedida por el usuario — ¿la sesión de control pasa realmente por el servidor propio, no solo el registro?** Confirmado subiendo `hbbs` a `RUST_LOG=debug` temporalmente y repitiendo una conexión real: el log mostró `Fetch local addr "437737703" ... request from ...` (la petición de conexión real, función `handle_punch_hole_request`), no solo el `update_pk` de heartbeat que ya se veía en `info`. Con el nivel de log por defecto este evento de conexión no se ve — solo el registro queda a nivel `info`.

**Consulta del usuario — ¿se pueden atender varias conexiones simultáneas a distintos clientes con Solwed OS?** Revisado el código de `rustdesk-server`: cada conexión corre en su propia tarea async (`tokio::spawn`), sin límite de sesiones concurrentes en la versión OSS (ese límite solo existe en la versión Pro, como restricción de licencia). Confirmado que sí, sin tope técnico — el único límite real sería de recursos del servidor si varias sesiones acaban usando relay en vez de P2P directo.

**Único pendiente real de este punto:** DNS de `remoto.solwed.es` → IP del servidor, cuando el usuario pueda — cambio trivial en la plantilla, no toca el servidor.

## Repositorio APT propio — servidor desplegado, Nivel 4 (2026-07-15)

Segundo punto de Nivel 4 (tras RustDesk) llevado a servidor real, sobre `erpsolwed` (mismo servidor que RustDesk). Clave GPG dedicada (generada el 2026-07-13, ver la entrada de aquel día) importada al keyring de `root` **copiándola directamente desde el escritorio de Windows del usuario al servidor por SCP**, sin leerla ni imprimirla en ningún momento — misma norma aplicada tras el incidente de exposición de aquel día.

**aptly 1.6.3** instalado desde su repo oficial (`repo.aptly.info`, `trixie`). Repo `solwed` creado (`distribution=resolute`, `component=main`) y publicado firmado (`aptly publish snapshot -gpg-key=... -architectures=amd64`), verificado con `gpg --verify` contra el fingerprint real antes de darlo por bueno.

**Bug de permisos encontrado y corregido durante el despliegue:** el `root_dir` por defecto de aptly (`~/.aptly`) cae bajo `/root` para el usuario `root`, con permisos `700` — el usuario que corre nginx en este servidor (`clp`, vía CloudPanel) nunca podría atravesarlo para servir los ficheros. Movido a `/srv/solwed-apt` (permisos normales, fuera de `/home` y `/root`) con un symlink desde `/root/.aptly` para que los comandos de `aptly` sigan funcionando sin flags extra.

**Sitio publicado vía CloudPanel** (`clpctl site:add:static --domainName=repo.solwed.es`), repuntando el `root` del vhost de nginx directamente a `/srv/solwed-apt/public` (con `autoindex on`) en vez de copiar ficheros al `htdocs` por defecto — cada publicación futura se sirve sola.

**Gotcha real encontrado al probar:** este servidor corre dos instancias de nginx en paralelo (la de CloudPanel y la del sistema, en `/etc/nginx/nginx.conf`) — la segunda es la que de verdad tiene los certificados/vhosts de todos los sitios. Recargar la instancia de CloudPanel no aplicaba el cambio del vhost; hizo falta `sudo nginx -s reload` sin `-c` (la instancia por defecto). Probado sirviendo con `curl --resolve repo.solwed.es:443:127.0.0.1 ...` para forzar SNI/Host correctos sin depender del DNS, que aún no existe.

**Certificado actual: autofirmado por CloudPanel**, no Let's Encrypt — esperado sin DNS real. No compromete la integridad del repo (la garantiza la firma GPG del `Release`, no el TLS). Cuando haya DNS, un solo comando (`clpctl lets-encrypt:install:certificate`) lo resuelve.

**Corregida también la plantilla del cliente** (`apt-repo/solwed.list.template`): tenía un prefijo `/apt` que no existe — `aptly publish snapshot` publica en la raíz del dominio, confirmado con `curl` (404 en `/apt/...`, 200 en la raíz).

Añadido `apt-repo/publish-update.sh`, script de referencia para publicar futuros `.deb` sin downtime (`repo add` + `snapshot create` + `publish switch`).

**Único pendiente real:** DNS de `repo.solwed.es` → `51.89.21.128`, cuando el usuario pueda — y en ese momento, pedir el certificado real.

## Acceso desatendido RustDesk en equipo interno — investigado, bug real de Wayland encontrado (2026-07-15)

Usuario pidió activar el modo "Conexión a Escritorio Remoto"-style (sin autenticación ni consentimiento del cliente) para un equipo interno de oficina, no para clientes — caso distinto del acceso desatendido que este punto del manual pide no activar por defecto.

Confirmado que el servicio no se activa solo con `systemctl enable rustdesk` (mismo bug ya documentado el 2026-07-13/14: el `postinst` nunca copia el fichero de la unidad). Se activa a mano copiando la plantilla que el paquete ya trae:
```
sudo cp /usr/share/rustdesk/files/systemd/rustdesk.service /usr/lib/systemd/system/rustdesk.service
sudo systemctl daemon-reload
sudo systemctl enable --now rustdesk
```

**Bug real de Wayland encontrado al probarlo, no achacable a Solwed OS:** en Wayland, la captura de pantalla pasa obligatoriamente por `xdg-desktop-portal`, que exige confirmación humana la primera vez ("Seleccione la pantalla que se compartirá") — X11 no tenía esta barrera. RustDesk soporta un `restore_token` (confirmado en el código fuente, `libs/scrap/src/wayland/pipewire.rs`) que evita repetir la confirmación mientras la sesión de GNOME siga activa — pero al bloquear con `Super+L` (o por inactividad/suspensión), el portal revoca la sesión de PipeWire y vuelve a pedir confirmación desde cero. Confirmado que es un bug conocido y ya reportado aguas arriba (PR #14384 de `rustdesk/rustdesk`, sin mergear a día de hoy) — no solucionable desde la configuración de Solwed OS.

**Solución práctica adoptada mientras no llegue el fix upstream:** dejar la sesión de usuario permanentemente iniciada (con su contraseña normal, sin necesidad de autologin) y desactivar todo lo que pueda bloquearla o suspenderla — suspensión automática (Configuración → Energía) y bloqueo/apagado de pantalla por inactividad (Configuración → Privacidad → Bloqueo de pantalla, o `gsettings set org.gnome.desktop.session idle-delay 0` + `gsettings set org.gnome.desktop.screensaver lock-enabled false` si la GUI no ofrece "Nunca"). Queda como responsabilidad del usuario del equipo no pulsar `Super+L` manualmente.

Autologin (`/etc/gdm3/custom.conf`) queda como mejora aparte, solo para el caso de que el equipo se reinicie solo (corte de luz, actualización) — no relacionado con el bug de bloqueo.

Manual (`#item-support`) actualizado con todo el hallazgo, sin tocar el resto de la card ya cerrada.

## DNS real + certificado Let's Encrypt: repo APT y RustDesk migrados a erpsolwed.es (2026-07-16)

Los dos pendientes de DNS que quedaban abiertos (`repo.solwed.es`, `remoto.solwed.es`) llevaban bloqueados desde el 2026-07-15 esperando respuesta del jefe del usuario para tocar la zona `solwed.es` — en concreto, `rustdesk.solwed.es` ya existía apuntando a otra IP (`54.37.230.9`) sin saber si era una reserva libre o un servicio activo de otra cosa.

**Resuelto con un cambio de dominio, sin esperar respuesta**: en vez de pedir los registros bajo `solwed.es`, se crearon como subdominios nuevos de **`erpsolwed.es`** (zona sin ese conflicto): `repo.erpsolwed.es` → `51.89.21.128` y `remoto.erpsolwed.es` → `51.89.21.128`. Confirmado por resolución DNS real (no vía panel), ambos resuelven correctamente.

**Certificado Let's Encrypt real para el repo APT** — el sitio de CloudPanel en `erpsolwed` seguía registrado como `repo.solwed.es` (el dominio abandonado, sin DNS — NXDOMAIN confirmado), lo que bloqueaba `clpctl lets-encrypt:install:certificate` para siempre, incluso pasando `repo.erpsolwed.es` como `--subjectAlternativeName`, porque ese comando siempre valida también el dominio "propietario" del sitio. Solución: creado un **sitio nuevo** en CloudPanel (`site:add:static --domainName=repo.erpsolwed.es`, usuario `repoerp`), pedido el certificado ahí (dominio único, sin SAN), y solo después repuntada su raíz nginx a `/srv/solwed-apt/public` — repuntar el root antes del certificado rompe la validación ACME porque el challenge se escribe en el docroot por defecto de CloudPanel, no en la ruta real del repo. El sitio obsoleto `repo.solwed.es` (sin DNS, solo el `index.html` por defecto, nada del repo real) se eliminó de CloudPanel tras confirmar que no había nada de valor. Verificado extremo a extremo: `curl -v https://repo.erpsolwed.es/` sirve HTTP/2 200, certificado `issuer: Let's Encrypt`, listado real (`dists/`, `pool/`) intacto.

**Plantillas del repo actualizadas** a los dominios reales: `rustdesk-installer/RustDesk2.toml` + `rustdesk-installer/skel-config/rustdesk/RustDesk2.toml` (antes IP cruda `51.89.21.128` → ahora `remoto.erpsolwed.es`) y `apt-repo/solwed.list.template` (→ `repo.erpsolwed.es`, activado de verdad quitando el `.template`). De paso, restringida la línea `deb` a `arch=amd64` — el repo aptly solo publica `amd64`, y sin esto `apt update` avisaba (sin fallar) de que no podía cubrir `i386` en cualquier equipo con esa arquitectura habilitada (p.ej. tras instalar Steam/Wine).

**Lección para este servidor:** `lets-encrypt:install:certificate --domainName=X` en CloudPanel SIEMPRE valida el dominio `X` en sí, nunca solo los SAN — si el sitio quedó registrado bajo un dominio sin DNS real, no hay forma de pedirle un certificado por SAN; hay que crear un sitio nuevo bajo el dominio correcto, pidiendo el cert con el docroot todavía por defecto, y repuntar el `root` del vhost después.

## Alpha 4.4.0 — autologin en modo live roto al añadir la cuenta de soporte (2026-07-15/16)

Al añadir el usuario de rescate `soporte-solwed` (Nivel 4, cuenta para clientes que olvidan su contraseña) y regenerar la ISO, el arranque en modo live dejó de entrar solo con el usuario `solwed` — pedía usuario y contraseña en GDM, cuando antes entraba directo. Primeras hipótesis (choque de UID exacto 1000, initramfs desactualizado) descartadas con evidencia real, sin encontrar la causa — sesión bloqueada esperando un log de arranque real.

**Causa raíz real, encontrada 2026-07-16 con el primer log de arranque conseguido:** en `/usr/lib/user-setup/functions.sh`, la función `is_system_user()` comprueba si `/etc/passwd` ya tiene **cualquier** UID entre 1000 y 59999 (no un UID exacto) y, si lo encuentra, asume "ya existe una cuenta de usuario, no crear una automática". `user-setup-apply` (invocado desde `casper-bottom/25adduser`) solo crea el usuario live si `! is_system_user`. Al estar `soporte-solwed` en UID 1001 (dentro de ese rango), la comprobación empezó a devolver verdadero y **toda la creación del usuario `solwed` se saltaba silenciosamente** — incluida la configuración de autologin de GDM, que vive dentro del mismo bloque `if`. El fix previo de UID 1000→1001 no sirvió de nada porque la comprobación nunca fue por un número exacto.

**Fix:** añadida `export OVERRIDE_SYSTEM_USER=1` en `custom-root/usr/share/initramfs-tools/scripts/casper-bottom/25adduser`, justo antes de la llamada a `user-setup-apply` — variable de escape ya soportada oficialmente por `is_system_user()`. Verificado con evidencia dura (extracción y grep del initrd real, no solo mtime).

**Cerrado y confirmado en Alpha 4.5.0:** arranque live directo como `solwed`, sin pedir usuario/contraseña.

## Alpha 4.5.1 — el mismo bug también rompía la instalación real (2026-07-16)

Tras confirmar Alpha 4.5.0 en live, apareció el mismo síntoma en una **instalación real**: el usuario elegido durante el asistente de Ubiquity no llegaba a crearse, solo se podía entrar como `soporte-solwed`.

**Causa: Ubiquity tiene su propia copia duplicada de `user-setup-apply`/`functions.sh`**, con el mismo `is_system_user()`, que nadie había parcheado. En `custom-root/usr/lib/ubiquity/plugins/ubi-usersetup.py`, clase `Install.prepare()`, el modo OEM ya pasaba `OVERRIDE_SYSTEM_USER: '1'`, pero el modo de instalación normal (el que usa cualquier cliente real) pasaba `environ = {}` vacío.

**Fix:** mismo patrón, `environ = {'OVERRIDE_SYSTEM_USER': '1'}` en el modo normal.

**Cerrado y confirmado en Alpha 4.5.1:** instalación real completa, el usuario elegido durante el setup se crea correctamente.

**Lección general:** cualquier fix de `user-setup`/`is_system_user` debe aplicarse en las dos copias que vive en la imagen (`/usr/lib/user-setup/`, usada por casper en live, y `/usr/lib/ubiquity/user-setup/` + `ubi-usersetup.py`, usada por el instalador real) — son ficheros duplicados, no compartidos.

**Bug menor encontrado en el mismo boot-test, también arreglado:** RustDesk de `soporte-solwed` seguía mostrando la IP cruda en vez del dominio — su carpeta de usuario se creó (horneada en la imagen) antes de que se actualizara `/etc/skel` al dominio nuevo, y `/etc/skel` no se copia retroactivamente a cuentas ya existentes. Refrescado a mano su `RustDesk2.toml`. Cualquier cuenta pre-horneada necesitará este refresco manual cada vez que cambie una plantilla de skel, hasta que exista un mecanismo automático (mismo patrón que `alternatives-guard`/`branding-guard`).
