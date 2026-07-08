# Solwed OS

Distribución Linux personalizada para clientes de Solwed, construida remasterizando **AnduinOS** (distro basada en Ubuntu, estilo Windows 11, GNOME + dash-to-panel/arc-menu) con **Cubic**.

## Estado actual

**Nivel 1 (identidad visual) completo y validado en hardware real** (Dell Latitude 5490):

- Identidad del sistema (`/etc/os-release`, `/etc/lsb-release`) con URLs de soporte propias.
- Fondo de pantalla y bloqueo de marca Solwed.
- Icono, cursor y color de acento personalizados (`Fluent-round-yellow`).

Ver [`CHANGELOG.md`](CHANGELOG.md) para el detalle de cada cambio y los bugs encontrados/resueltos durante el proceso.

## Estructura del repo

- `solwed-os-manual.html` — manual de referencia original, plan de personalización en 4 niveles.
- `CLAUDE.md` — guía de trabajo destilada del manual, con las correcciones verificadas contra AnduinOS real.
- `ANDUIN-BASELINE.md` — hechos verificados directamente sobre una ISO limpia de AnduinOS 2.0.0 (dónde vive cada cosa, qué asume mal el manual original).
- `CHANGELOG.md` — registro de qué se aplicó en el chroot de Cubic en cada sesión, y por qué.
- `imagenes_Solwed/` — assets de marca (wallpapers, logo).
- `Capturas Errores/` — capturas de pantalla y salidas de terminal recogidas durante la depuración.
- `reference/` — ISO limpia de AnduinOS extraída, usada como referencia para verificar comportamiento de fábrica (gitignored, se regenera localmente).

## Cómo se trabaja

Esto no es un codebase convencional: el trabajo ocurre dentro de la terminal del chroot de Cubic, editando archivos del árbol de AnduinOS, y luego generando y probando la ISO en una VM o hardware real. El proyecto de Cubic (con el chroot `custom-root/`) vive fuera de este repo, en `/home/aruizb/cubic-projects/SolwedOS/`; este repo solo contiene documentación, changelog y referencias.

Ver [`CLAUDE.md`](CLAUDE.md) para el detalle de la arquitectura por niveles y los pasos a seguir en cada bloque de cambios.
