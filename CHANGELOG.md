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
