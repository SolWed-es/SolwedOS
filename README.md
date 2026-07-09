# Solwed OS

Distribución Linux personalizada para clientes de Solwed, construida remasterizando **AnduinOS** (distro basada en Ubuntu, estilo Windows 11, GNOME + dash-to-panel/arc-menu) con **Cubic**.

## Estado actual

**Alpha 3.1.1 — Niveles 1 y 2 completos y validados en hardware real** (Dell Latitude 5490), **Nivel 3 en marcha:**

- **Nivel 1 (identidad visual):** identidad del sistema (`/etc/os-release`, `/etc/lsb-release`) con URLs de soporte propias, fondo de pantalla y bloqueo de marca Solwed, icono/cursor/color de acento personalizados (`Fluent-round-yellow`).
- **Nivel 2 (arranque y login):** Plymouth con marca Solwed, fondo y logo de GDM, usuario/hostname live, iconos de ArcMenu/apariencia rebrandeados, teclado español, tema de GNOME Shell y GTK en amarillo de acento, slideshow del instalador (Ubiquity) reescrito en los 27 idiomas soportados.
- **Nivel 3 (comportamiento y apps), arrancado:** LibreOffice y Thunderbird preinstalados (Thunderbird vía el PPA de mozillateam, paquete `.deb` real, no snap), plugin de WhatsApp Web preinstalado en Thunderbird, carpeta "LibreOffice" y Thunderbird anclados en el menú de inicio (ArcMenu), instalador gráfico de FacturaScripts bajo demanda (icono de escritorio, `zenity` + `pkexec`).

Ver [`CHANGELOG.md`](CHANGELOG.md) para el detalle de cada cambio y los bugs encontrados/resueltos durante el proceso.

## Estructura del repo

- `solwed-os-manual.html` — manual de referencia original, plan de personalización en 4 niveles.
- `CLAUDE.md` — guía de trabajo destilada del manual, con las correcciones verificadas contra AnduinOS real.
- `ANDUIN-BASELINE.md` — hechos verificados directamente sobre una ISO limpia de AnduinOS 2.0.0 (dónde vive cada cosa, qué asume mal el manual original).
- `CHANGELOG.md` — registro de qué se aplicó en el chroot de Cubic en cada sesión, y por qué.
- `branding/` — assets de marca aplicados al sistema (Plymouth, GDM, cursores, panel).
- `imagenes_Solwed/` — assets de marca originales (wallpapers, logo fuente).
- `slideshow-fix/` — slideshow del instalador (Ubiquity) reescrito, en staging para hornear en `custom-root` (27 idiomas + fallback en inglés).
- `thunderbird-addons/` — extensiones de Thunderbird preinstaladas (`.xpi`), pensadas para sideload vía `distribution/extensions/`.
- `facturascripts-installer/` — instalador gráfico bajo demanda de FacturaScripts (lanzador sin privilegios + worker root vía `pkexec`, separados porque esta ISO es Wayland puro).
- `scripts/` — scripts de aplicación de marca, pensados para copiarse y ejecutarse dentro del chroot de Cubic.
- `Capturas Errores/` — capturas de pantalla y salidas de terminal recogidas durante la depuración.
- `reference/` — ISO limpia de AnduinOS extraída, usada como referencia para verificar comportamiento de fábrica (gitignored, se regenera localmente).

## Cómo se trabaja

Esto no es un codebase convencional: el trabajo ocurre dentro de la terminal del chroot de Cubic, editando archivos del árbol de AnduinOS, y luego generando y probando la ISO en una VM o hardware real. El proyecto de Cubic (con el chroot `custom-root/`) vive fuera de este repo, en `/home/aruizb/cubic-projects/SolwedOS/`; este repo solo contiene documentación, changelog y referencias.

Ver [`CLAUDE.md`](CLAUDE.md) para el detalle de la arquitectura por niveles y los pasos a seguir en cada bloque de cambios.
