# Solwed OS

Distribución Linux personalizada para clientes de Solwed, construida remasterizando **AnduinOS** (distro basada en Ubuntu, estilo Windows 11, GNOME + dash-to-panel/arc-menu) con **Cubic**.

## Estado actual

**Solwed OS Beta 1.0.3 — fase Alpha cerrada (los 4 Niveles del plan original a alcance completo, confirmados en hardware real y VM), ahora en corrección de bugs post-Alpha.**

- **Nivel 1 (identidad visual):** identidad del sistema (`/etc/os-release`, `/etc/lsb-release`), fondo de pantalla y bloqueo de marca Solwed, icono/cursor/color de acento personalizados (`Fluent-round-yellow`). El logo grande de Ajustes → Sistema → Acerca de (ruta escrita a fuego en `gnome-control-center`, no cubierta por el mecanismo genérico de iconos) también corregido — antes seguía mostrando "ANDUINOS".
- **Nivel 2 (arranque y login):** Plymouth con marca Solwed, fondo y CSS de GDM en amarillo Solwed, **tema gráfico de GRUB propio**, usuario/hostname live, iconos de ArcMenu/apariencia rebrandeados, teclado español, tema de GNOME Shell y GTK en amarillo de acento.
- **Nivel 3 (comportamiento y apps):** LibreOffice, Thunderbird (con plugin de WhatsApp Web), Brave por defecto, Autofirma + Okular, Timeshift, instalador gráfico de FacturaScripts bajo demanda, menú de inicio (ArcMenu) curado. Icono de Software/FacturaScripts en naranja.
- **Nivel 4 (avanzado), cerrado del todo:** RustDesk autoalojado (servidor `hbbs`/`hbbr` propio en `erpsolwed`), repositorio APT propio, asistente de bienvenida, y **contraseña de rescate por máquina** para `soporte-solwed` (ver `rescue-password/`) — ID de recuperación de 9 dígitos generado localmente por SHA-256 (no depende de RustDesk), consultable por el técnico en `https://remoto.erpsolwed.es/soporte`.
- **Post-Alpha — admin sin confirmación repetida:** regla de polkit (`polkit/00-solwed-admin-no-prompt.rules`) para que, tras el login, ninguna acción que pida permisos de administrador vuelva a preguntar — decisión de negocio explícita, con el trade-off de seguridad aceptado.
- **Post-Alpha — bug real de symlinks en el guardián de marca, corregido:** varios iconos del tema (incl. el de Software/FacturaScripts) son symlinks a otro fichero real; el repo los trackeaba con el nombre del symlink en vez del real, lo que hacía que el guardián los revirtiera solo. Renombrados a su nombre real y `level2-06-branding-guard.sh` corregido para no acumular huérfanos entre ejecuciones.
- **Post-Alpha — widget del tiempo:** ya no se salta su autoconfiguración de primer arranque (detecta la ciudad real del cliente por IP).
- **Post-Alpha, ya cerrados:** confirmación repetida de admin (polkit) verificada con boot-test, bug de doble instalación con mismo ID de rescate, y logo "ANDUINOS" en Ajustes → Acerca de.
- **Nuevo — prototipo de chat de IA ("Asistente Solwed"):** acceso directo preinstalable que abre un chat basado en un modelo Liquid AI (LFM) corriendo en un servidor propio (Open WebUI + Ollama), confirmado funcionando en boot-test real. Aún apunta a un servidor de pruebas (Tailscale), pendiente de dominio público y de conexión a datos por cliente antes de producción — ver `ai-chat-shortcut/` y `CHANGELOG.md`.
- **Investigación aparcada, pendiente de decisión de negocio:** RDP multiusuario simultáneo con una cuenta por técnico en vez de la compartida `soporte-solwed`.
- **Bug conocido, aparcado (no prioritario):** el círculo animado de "cargando" junto al puntero se ve en azul en Proxmox mientras que en hardware real (Dell) no da problema — configuración descartada como causa, investigación en pausa, ver `CHANGELOG.md`.
- **Resiliencia frente a actualizaciones:** ninguna de las personalizaciones de este proyecto está protegida como conffile por los paquetes de AnduinOS/Ubuntu que las poseen — se sobreescriben en silencio en cualquier actualización relevante. Dos guardianes idempotentes, disparados por hooks de APT, reafirman automáticamente Plymouth/GDM y el resto de la marca (iconos, cursores, ArcMenu, dconf/GTK, GRUB, `os-release`/`lsb-release`, el logo del Acerca de) si algún paquete los revierte.

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
- `slideshow-fix/` — slideshow del instalador (Ubiquity) reescrito, en staging para hornear en `custom-root` (27 idiomas + fallback en inglés), incluidas las capturas reales (`screenshots/`) y los manifests (`index.html`, `directory.jsonp`).
- `welcome-wizard/` — diálogo de bienvenida del primer login (script + `.desktop` de autostart + logo).
- `thunderbird-addons/` — extensiones de Thunderbird preinstaladas (`.xpi`), pensadas para sideload vía `distribution/extensions/`.
- `facturascripts-installer/` — instalador gráfico bajo demanda de FacturaScripts (lanzador sin privilegios + worker root vía `pkexec`, separados porque esta ISO es Wayland puro).
- `autofirma-installer/` — instalador de Autofirma 1.9 + script de confianza de certificado para Chromium/Brave (primer login).
- `rustdesk-installer/` — `.deb` de RustDesk + plantilla de preconfiguración (`RustDesk2.toml`).
- `apt-repo/` — clave GPG pública del repositorio APT propio (preinstalada) y plantilla de `sources.list` (sin activar hasta tener servidor).
- `rescue-password/` — contraseña de rescate por máquina para `soporte-solwed`: script de primer arranque (genera ID de recuperación + contraseña, los registra en el servidor), script del banner de login, y `server/` (FastAPI + SQLite + Docker, desplegado en `erpsolwed` como `remoto.erpsolwed.es`).
- `polkit/` — regla de polkit para que el administrador no vuelva a confirmar acciones tras el login (`00-solwed-admin-no-prompt.rules`).
- `ai-chat-shortcut/` — acceso directo preinstalable ("Asistente Solwed") a un chat de IA (Liquid AI/LFM) corriendo en servidor propio, con icono de marca propio.
- `scripts/` — scripts de aplicación de marca, pensados para copiarse y ejecutarse dentro del chroot de Cubic.
- `Capturas Errores/` — capturas de pantalla y salidas de terminal recogidas durante la depuración.
- `reference/` — ISO limpia de AnduinOS extraída, usada como referencia para verificar comportamiento de fábrica (gitignored, se regenera localmente).

## Cómo se trabaja

Esto no es un codebase convencional: el trabajo ocurre dentro de la terminal del chroot de Cubic, editando archivos del árbol de AnduinOS, y luego generando y probando la ISO en una VM o hardware real. El proyecto de Cubic (con el chroot `custom-root/`) vive fuera de este repo, en `/home/aruizb/cubic-projects/SolwedOS/`; este repo solo contiene documentación, changelog, assets de marca y scripts de referencia.

Ver [`CLAUDE.md`](CLAUDE.md) para el detalle de la arquitectura por niveles y los pasos a seguir en cada bloque de cambios.
