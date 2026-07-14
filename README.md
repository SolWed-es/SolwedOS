# Solwed OS

Distribución Linux personalizada para clientes de Solwed, construida remasterizando **AnduinOS** (distro basada en Ubuntu, estilo Windows 11, GNOME + dash-to-panel/arc-menu) con **Cubic**.

## Estado actual

**Alpha 4.2.0 — Niveles 1 y 2 completos y confirmados en hardware real** (Dell Latitude 5490), **Nivel 3 sustancialmente hecho, Nivel 4 en marcha:**

- **Nivel 1 (identidad visual):** identidad del sistema (`/etc/os-release`, `/etc/lsb-release`), fondo de pantalla y bloqueo de marca Solwed, icono/cursor/color de acento personalizados (`Fluent-round-yellow`).
- **Nivel 2 (arranque y login):** Plymouth con marca Solwed, fondo y CSS de GDM en amarillo Solwed (no solo el fondo), **tema gráfico de GRUB propio** (fondo, tipografía, timeout de 5s, Solwed OS por defecto), idioma "Spanish" resaltado por defecto en el menú de arranque del propio ISO, usuario/hostname live, iconos de ArcMenu/apariencia rebrandeados, teclado español, tema de GNOME Shell y GTK en amarillo de acento, slideshow del instalador (Ubiquity) reescrito en los 27 idiomas soportados.
- **Nivel 3 (comportamiento y apps):** LibreOffice, Thunderbird (PPA de mozillateam, `.deb` real, con plugin de WhatsApp Web preinstalado), Brave como navegador por defecto, Autofirma + Okular (firma electrónica), Timeshift, instalador gráfico de FacturaScripts bajo demanda, menú de inicio (ArcMenu) curado con carpeta LibreOffice y anclados propios.
- **Nivel 4 (avanzado), en marcha:** cliente de RustDesk preinstalado y preconfigurado (servicio de acceso desatendido verificado inactivo; servidor propio `hbbs`/`hbbr` pendiente), preparación del lado cliente de un repositorio APT propio (clave GPG dedicada, `sources.list` en plantilla; servidor `aptly` pendiente). Asistente de bienvenida sin empezar.
- **Resiliencia frente a actualizaciones:** ninguna de las personalizaciones de este proyecto está protegida como conffile por los paquetes de AnduinOS que las poseen — se sobreescriben en silencio en cualquier actualización relevante (confirmado en producción: una actualización rutinaria desde GNOME Software revirtió el splash de arranque). Dos guardianes idempotentes, disparados por hooks de APT (`DPkg::Post-Invoke`, se activan también cuando la actualización viene de GNOME Software/PackageKit) reafirman automáticamente Plymouth/GDM y el resto de la marca (iconos, cursores, ArcMenu, dconf/GTK, GRUB, `os-release`/`lsb-release`) si algún paquete los revierte.

Ver [`CHANGELOG.md`](CHANGELOG.md) para el detalle de cada cambio y los bugs encontrados/resueltos durante el proceso, y [`solwed-os-manual.html`](solwed-os-manual.html) para la guía completa por niveles con estado, causa raíz y fix de cada bug conocido de la plataforma.

## Estructura del repo

- `solwed-os-manual.html` — manual de referencia, guía completa por niveles con estado real, causas raíz y fixes de cada bug conocido de la plataforma (AnduinOS/Cubic/GNOME).
- `CLAUDE.md` — guía de trabajo para Claude Code: arquitectura por niveles, flujo de trabajo con Cubic, y el patrón de "guardianes" para sobrevivir a actualizaciones de paquete.
- `ANDUIN-BASELINE.md` — hechos verificados directamente sobre una ISO limpia de AnduinOS 2.0.0 (dónde vive cada cosa, qué asume mal el manual original).
- `CHANGELOG.md` — registro cronológico de qué se aplicó en el chroot de Cubic en cada sesión, y por qué.
- `branding/` — assets de marca aplicados al sistema: `plymouth/`, `gdm/`, `wallpapers/`, `cursors/` (temas de cursor recoloreados completos), `panel/` (icono de ArcMenu), `icons/` (iconos de apps recoloreados), `system-files/` (copias conocidas-buenas de `os-release`, `lsb-release`, `/etc/default/grub`, overrides de dconf/gschema — fuente de restauración de `reassert-branding.sh`).
- `grub-theme/` — tema gráfico de GRUB (`theme.txt`, fondo, fuentes `.pf2`).
- `alternatives-guard/` — los dos guardianes de actualización (`reassert-alternatives.sh` para Plymouth/GDM, `reassert-branding.sh` para el resto) y sus hooks de `/etc/apt/apt.conf.d/`.
- `imagenes_Solwed/` — assets de marca originales (wallpapers, logo fuente, fondo de GRUB).
- `slideshow-fix/` — slideshow del instalador (Ubiquity) reescrito, en staging para hornear en `custom-root` (27 idiomas + fallback en inglés).
- `thunderbird-addons/` — extensiones de Thunderbird preinstaladas (`.xpi`), pensadas para sideload vía `distribution/extensions/`.
- `facturascripts-installer/` — instalador gráfico bajo demanda de FacturaScripts (lanzador sin privilegios + worker root vía `pkexec`, separados porque esta ISO es Wayland puro).
- `autofirma-installer/` — instalador de Autofirma 1.9 + script de confianza de certificado para Chromium/Brave (primer login).
- `rustdesk-installer/` — `.deb` de RustDesk + plantilla de preconfiguración (`RustDesk2.toml`).
- `apt-repo/` — clave GPG pública del repositorio APT propio (preinstalada) y plantilla de `sources.list` (sin activar hasta tener servidor).
- `scripts/` — scripts de aplicación de marca, pensados para copiarse y ejecutarse dentro del chroot de Cubic.
- `Capturas Errores/` — capturas de pantalla y salidas de terminal recogidas durante la depuración.
- `reference/` — ISO limpia de AnduinOS extraída, usada como referencia para verificar comportamiento de fábrica (gitignored, se regenera localmente).

## Cómo se trabaja

Esto no es un codebase convencional: el trabajo ocurre dentro de la terminal del chroot de Cubic, editando archivos del árbol de AnduinOS, y luego generando y probando la ISO en una VM o hardware real. El proyecto de Cubic (con el chroot `custom-root/`) vive fuera de este repo, en `/home/aruizb/cubic-projects/SolwedOS/`; este repo solo contiene documentación, changelog, assets de marca y scripts de referencia.

Ver [`CLAUDE.md`](CLAUDE.md) para el detalle de la arquitectura por niveles y los pasos a seguir en cada bloque de cambios.
