# AnduinOS 2.0.0 — baseline verificado

Hechos comprobados directamente sobre `casper/filesystem.squashfs` de una ISO limpia de **AnduinOS 2.0.0 "Resolute Ringtail"** (`AnduinOS-2.0.0.iso`, extraída en `reference/anduinos-clean-iso/` — no se mantiene en disco de forma permanente, ver `.gitignore` y `README.md`; re-extraer de la ISO original si hace falta volver a verificar algo contra ella). Este documento sustituye — no complementa — las suposiciones de `solwed-os-manual.html`: donde haya contradicción, manda este archivo porque está verificado sobre el sistema real, no asumido.

## Correcciones clave respecto al manual original

| Punto | Manual asumía | Realidad verificada |
|---|---|---|
| `ID_LIKE` en os-release | `ubuntu` | **`debian`** (`UBUNTU_CODENAME=resolute` es un campo aparte) |
| `VERSION_CODENAME` | `noble` (ejemplo genérico) | **`resolute`** |
| Gestor de sesión | LightDM *o* GDM, a confirmar | **Solo GDM3** (`/usr/sbin/gdm3`, no hay `lightdm` instalado) |
| Base del tema Plymouth | copiar `spinner` genérico | Ya existe un tema propio **`anduinos`** (paquete `plymouth-anduinos`), es la base correcta para partir |
| Dónde van los defaults de dconf | `/etc/dconf/db/local.d/` | **No existe `local.d`.** El perfil activo (`/etc/dconf/profile/user`) apunta a `system-db:anduinos` → los ficheros van en **`/etc/dconf/db/anduinos.d/`**, numerados (`10-arcmenu.conf`, `14-dash-to-panel.conf`, `20-wallpapers.conf`, etc.) |
| Extensiones de panel/menú | "probablemente dash-to-panel / arc-menu" | Confirmado: `dash-to-panel@jderose9.github.com` y `arcmenu@arcmenu.com`, empaquetadas como fork propio `gnome-shell-extension-dash-to-panel-anduinos` (no el paquete vanilla) |

## Identidad del sistema

```
# /etc/os-release
PRETTY_NAME="AnduinOS 2.0.0"
NAME="AnduinOS"
VERSION_ID="2.0.0"
VERSION="2.0.0 (Resolute Ringtail)"
VERSION_CODENAME=resolute
ID=anduinos
ID_LIKE=debian
UBUNTU_CODENAME=resolute
```

Al clonar este bloque para Solwed OS: conservar `ID_LIKE=debian`, `VERSION_CODENAME` y `UBUNTU_CODENAME` reales — son los que usan apt y otras herramientas para resolver repositorios.

## Arranque y sesión

- Kernel: `7.0.0-27-generic`. `initramfs.conf`: `MODULES=most`, `COMPRESS=zstd`.
- `/etc/default/grub`: `GRUB_TIMEOUT_STYLE=hidden`, `GRUB_TIMEOUT=0` (menú oculto por defecto), `GRUB_DISTRIBUTOR` ya se deriva de `/etc/os-release` (no hace falta hardcodearlo).
- Display manager: **GDM3 únicamente** (`/etc/X11/default-display-manager` → `/usr/sbin/gdm3`). El branch del manual para LightDM no aplica a este sistema.
- Plymouth: tema por defecto activo vía `update-alternatives` → `/usr/share/plymouth/themes/anduinos/anduinos.plymouth`. Partir de copiar `anduinos/`, no `spinner/`.

## Estructura de personalización propia de AnduinOS

AnduinOS no es un Ubuntu genérico con un tema encima: es un árbol de metapaquetes propios (`anduinos-*`) con dependencias estrictas. Los relevantes:

- `anduinos-desktop` → metapaquete raíz.
- `anduinos-desktop-core` → depende (`Depends`, no solo `Recommends`) de `gdm3`, `gnome-shell`, `gnome-session`, `anduinos-session | ubuntu-session | gnome-session`, etc. **Purgar cualquiera de estos con `apt remove --purge` puede arrastrar el metapaquete completo** y con él partes del escritorio que no se pretendía tocar — de ahí el aviso del manual de comprobar `apt-cache rdepends` antes de purgar, que aquí es doblemente importante por la cantidad de metapaquetes encadenados.
- `anduinos-dconf-defaults`, `anduinos-live-settings`, `anduinos-gnome-extensions`, `anduinos-fluent-gtk-theme` / `anduinos-fluent-icon-theme`, `anduinos-wallpapers`, `anduinos-gdm3-wallpaper`, `firefox-anduinos` — cada aspecto de marca (tema, iconos, fondos, navegador) ya viene como su propio paquete versionado, en vez de archivos sueltos copiados a mano. **Para Solwed OS, el patrón correcto es imitar esta estructura** (paquete `.deb` propio `solwedos-wallpapers`, `solwedos-appearance`, etc.) en vez de escribir directamente sobre `/usr/share/...`, así sobrevive a actualizaciones y es reproducible.

### Extensiones GNOME instaladas (`usr/share/gnome-shell/extensions/`)

`dash-to-panel@jderose9.github.com`, `arcmenu@arcmenu.com`, `blur-my-shell@aunetx`, `user-theme@gnome-shell-extensions.gcampax.github.com`, `tiling-assistant@leleat-on-github`, `clipboard-indicator@tudmotu.com`, `appindicatorsupport@rgcjonas.gmail.com`, `ding@rastersoft.com` (iconos de escritorio), `simple-weather@romanlefler.com`, `network-stats@gnome.noroadsleft.xyz`, entre otras — todas con su propio fichero de configuración por defecto en `/etc/dconf/db/anduinos.d/` (ver siguiente sección).

### dconf: dónde van realmente los defaults

```
/etc/dconf/profile/user:
  user-db:user
  system-db:anduinos        ← esta es la db activa, NO "local"

/etc/dconf/db/anduinos.d/
  01-custom-keybindings.conf
  02-ptyxis-terminal.conf
  03-system-extensions.conf
  08-desktop-icons-ng.conf
  09-appindicator.conf
  10-arcmenu.conf
  11-blur-my-shell.conf
  12-clipboard-indicator.conf
  13-customize-ibus.conf
  14-dash-to-panel.conf
  15-lockkeys.conf
  17-network-stats.conf
  18-simple-weather.conf
  19-tiling-assistant.conf
  20-wallpapers.conf
```

Cualquier default nuevo de Solwed (fondo, apps ancladas al panel, atajos) va en un fichero nuevo dentro de **`/etc/dconf/db/anduinos.d/`** siguiendo esta numeración, seguido de `dconf update`. Escribir en `local.d` (como sugería el manual genérico) no tiene efecto porque ese perfil no se carga.

### Fondos de pantalla — patrón real

`20-wallpapers.conf`:
```
[org/gnome/desktop/background]
picture-uri='file:///usr/share/backgrounds/new_bubbles-light.jpg'
picture-uri-dark='file:///usr/share/backgrounds/new_bubbles-dark.jpg'
```

Registro del selector de fondos en `/usr/share/gnome-background-properties/fluent.xml` (un único XML con todos los fondos del sistema, no uno por fondo):
```xml
<wallpaper deleted="false">
  <name>New Bubbles</name>
  <filename>/usr/share/backgrounds/new_bubbles-light.jpg</filename>
  <filename-dark>/usr/share/backgrounds/new_bubbles-dark.jpg</filename-dark>
  <options>zoom</options>
  <shade_type>solid</shade_type>
</wallpaper>
```

Para Solwed OS: añadir la entrada de Solwed a este mismo `fluent.xml` (o a un XML propio adicional — GNOME lee todos los `.xml` de esa carpeta) y apuntar `20-wallpapers.conf` (o un fichero propio con número más alto, p. ej. `21-solwed-wallpaper.conf`) al fondo de Solwed.

## Pendiente de verificar (no comprobado aún)

- Contenido exacto de `anduinos-bwrap-hack` (nombre sugiere sandboxing vía bubblewrap, relevante si Solwed OS añade un agente de soporte remoto — Nivel 4 del manual).
- Proceso exacto de instalación (Calamares/Ubiquity/instalador propio) — no verificado en este pase, relevante para confirmar si el instalador sobreescribe `/etc/default/grub` u otros defaults al final del proceso, tal como avisaba el manual.
