# Solwed OS

Distribución Linux personalizada para clientes de Solwed, construida remasterizando **AnduinOS** (distro basada en Ubuntu, estilo Windows 11, GNOME + dash-to-panel/arc-menu) con **Cubic**.

## Estado actual

**Solwed OS 1.0.0 — primera versión sin sufijo "Beta". Los 4 niveles del plan original (identidad visual, arranque/login, comportamiento/apps, infraestructura avanzada) completos y confirmados en boot-test real.**

- **Identidad visual:** identidad del sistema (`/etc/os-release`, `/etc/lsb-release`, `/etc/issue`, `/etc/issue.net`), fondo de pantalla/bloqueo/login de marca Solwed, icono/cursor/color de acento personalizados, GRUB con tema gráfico propio. Sin rastro visible de la marca de la distribución base — auditado explícitamente (selector de fondos, banners de TTY/SSH, menú de inicio, panel "Acerca de").
- **Arranque y login:** Plymouth, GDM (fondo, CSS, teclado español), tema de GNOME Shell y GTK con el color de acento aplicado de punta a punta.
- **Comportamiento y apps:** LibreOffice, Thunderbird (con plugin de WhatsApp Web), Brave por defecto, Autofirma + Okular, Timeshift, instalador de FacturaScripts bajo demanda (se retira solo del menú tras instalar, sustituido por un acceso directo a la app ya instalada), menú de inicio curado, asistente de IA (Solwed AI) conectado a un servidor propio.
- **Infraestructura avanzada:** soporte remoto autoalojado (servidor propio de retransmisión), repositorio de paquetes propio, asistente de bienvenida de primer inicio de sesión, y contraseña de rescate por equipo con identificador de recuperación propio consultable por el equipo de soporte — ver [`manual-soporte-remoto.html`](manual-soporte-remoto.html) para el procedimiento operativo.
- **Resiliencia frente a actualizaciones:** ninguna de las personalizaciones de este proyecto está protegida como conffile por los paquetes de la distribución base que las poseen — se sobreescriben en silencio en cualquier actualización relevante. Dos guardianes idempotentes, disparados por hooks de gestión de paquetes, reafirman automáticamente la marca (arranque/login, iconos, cursores, menú, tema, GRUB, identidad del sistema) si algún paquete los revierte.
- **Problema conocido, sin resolver:** el indicador de carga animado junto al puntero se muestra en azul (color por defecto) en vez del color de acento en algunos entornos virtualizados concretos — investigación en pausa.

Ver [`CHANGELOG.md`](CHANGELOG.md) para el detalle de cada versión y los bugs encontrados/resueltos, [`solwed-os-manual.html`](solwed-os-manual.html) para la guía técnica completa por niveles, [`manual-soporte-remoto.html`](manual-soporte-remoto.html) para el procedimiento de soporte, y [`solwed-os-producto.html`](solwed-os-producto.html) para la presentación cara al cliente.

## Estructura del repo

- `solwed-os-manual.html` — manual de referencia, guía completa por niveles con estado real, causas raíz y fixes de cada bug conocido de la plataforma (AnduinOS/Cubic/GNOME).
- `manual-soporte-remoto.html` — guía interna para el equipo de Solwed: qué hacer cuando un cliente pide soporte remoto (flujo A, RustDesk atendido, y flujo B, contraseña de rescate para un equipo bloqueado). No distribuir a clientes.
- `solwed-os-producto.html` — página de presentación cara al cliente: qué es Solwed OS, qué trae de serie y cómo funciona el soporte, sin detalle técnico interno.
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
- `ai-chat-shortcut/` — acceso directo preinstalable ("Solwed AI") a un chat de IA (Liquid AI/LFM) corriendo en servidor propio, con icono de marca propio.
- `scripts/` — scripts de aplicación de marca, pensados para copiarse y ejecutarse dentro del chroot de Cubic.

`reference/anduinos-clean-iso/` (ISO limpia de AnduinOS extraída, usada como referencia para verificar comportamiento de fábrica) no se versiona ni se mantiene en disco — se regenera localmente solo cuando hace falta comparar contra el sistema base, ver `.gitignore`.

## Cómo se trabaja

Esto no es un codebase convencional: el trabajo ocurre dentro de la terminal del chroot de Cubic, editando archivos del árbol de AnduinOS, y luego generando y probando la ISO en una VM o hardware real. El proyecto de Cubic (con el chroot `custom-root/`) vive fuera de este repo, en `/home/aruizb/cubic-projects/SolwedOS/`; este repo solo contiene documentación, changelog, assets de marca y scripts de referencia.

Ver [`CLAUDE.md`](CLAUDE.md) para el detalle de la arquitectura por niveles y los pasos a seguir en cada bloque de cambios.
