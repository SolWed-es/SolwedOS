# Máquina de demo Solwed OS

Portátil **Dell Latitude 5490** con Solwed OS Beta 1.4.0 nativo, usado para enseñar
el sistema a clientes y como equipo de desarrollo (git, gh, Cubic instalados;
el repo vive en `~/SolwedOS` con `origin` = fork de SolWed-ES y `upstream` = AlexRuiz03).

## Modo "siempre encendido"

Aplicado el 2026-08-02 con [`always-on.sh`](always-on.sh):

- `sleep.target`/`suspend.target`/`hibernate.target`/`hybrid-sleep.target` enmascarados
  (nada puede suspender el equipo).
- Drop-in de logind `99-solwed-always-on.conf`: cerrar la tapa no suspende.
- GNOME sin auto-suspensión por inactividad (enchufado y en batería).
- Pantalla siempre encendida: sin apagado por inactividad, sin atenuado y sin bloqueo
  automático de sesión (añadido el 2026-08-02 a petición para la demo).

Para reaplicarlo (o aplicarlo en otra máquina de demo):

```bash
pkexec bash demo-machine/always-on.sh   # parte de sistema (root)
bash demo-machine/always-on.sh --user   # parte de GNOME (usuario de la sesión)
```

## Paso manual pendiente de BIOS (arranque tras corte de luz)

Para que arranque solo al volver la corriente si se apagó del todo — no configurable
desde el SO:

1. Reiniciar y pulsar **F2** en el logo de Dell.
2. **Power Management → AC Behavior** → activar **Wake on AC**.
3. **Apply → Exit**.

## IA local (Liquid AI) + FacturaScripts + dashboard contable

Montado el 2026-08-02:

- **Ollama** instalado como servicio (API en `127.0.0.1:11434`) con el modelo
  **LFM2.5-1.2B-Instruct de Liquid AI** (730 MB, elegido para los 8 GB de RAM;
  responde en ~6 s por frase en CPU). Alias del modelo: `solwed-ai`
  (`ollama run solwed-ai`). Pendiente: al ampliar RAM a 16-24 GB (zócalo DIMM B
  libre), pasar a `LFM2.5-8B-A1B` como modelo principal.
- **FacturaScripts** operativo en `http://localhost/facturas` (admin /
  SolwedDemo2026). La instalación web falló a medias por un bug del instalador
  (config.php truncado); se completó a mano. Datos de demo cargados con
  [`seed-facturascripts-demo.php`](seed-facturascripts-demo.php): 10 clientes,
  4 proveedores y 12 meses de facturas (77 ventas, 39 compras) con tendencia
  creciente y mezcla de cobrado/pendiente.
- **Dashboard contable con IA**: [`dashboard-contable.php`](dashboard-contable.php)
  consulta MySQL con SQL fijo, genera un HTML autocontenido (offline, modo
  claro/oscuro, gráficas SVG con tooltips) y pide al LFM local el análisis en
  español de las cifras. Salida: `~/Dashboard-Contable.html`. Lanzador de menú:
  [`solwed-dashboard-ia.desktop`](solwed-dashboard-ia.desktop) ("Dashboard
  Contable IA"), instalado en `~/.local/share/applications/`.

Guion de demo sugerido: abrir FacturaScripts (ERP con datos reales) → lanzar
"Dashboard Contable IA" → enseñar que el análisis lo escribe una IA corriendo
en el propio equipo, sin internet.

## Plugins de FacturaScripts instalados (2026-08-02)

- **SolwedConnectFS** (clonado en `~/solwedconnect-fs`, repo
  `SolWed-es/solwedconnect-fs`): tema visual Solwed + conexión al ecosistema.
  Suscripción sin activar (falta código de app.solwed.es) — el plugin funciona
  igualmente en modo `plan: none`.
- **SolwedAI** (desarrollado en `~/solwedai-fs`, repo `SolWed-es/solwedai-fs`):
  página **Informes → Solwed AI** con chat de IA local sobre las cifras del
  negocio, gráficas de 12 meses y navegación por lenguaje natural ("ábreme la
  factura 1"). La empresa de demo se renombró de "E-2944" a "Solwed Demo SL".
  v0.2: chat flotante en el propio Tablero y router de pantallas híbrido
  (léxico + IA local) sobre el catálogo completo de la tabla `pages` — pide
  "llévame a tesorería" desde el Tablero y te lleva. v0.3: pantalla propia en
  Configuración → SolwedAI para elegir proveedor de IA (Ollama local, Solwed AI
  vía la conexión de SolwedConnectFS, o cualquier API compatible OpenAI).
- **Informes** v4.22 (oficial de FacturaScripts, clonado en `~/informes` para
  trabajar sobre él): informes comerciales, contables y financieros, gráficos y
  pizarras. Instalado y activado desde la propia UI de Plugins. No está en el
  catálogo de la forja (SolwedPlugins-container) — se decidió no añadirlo.

## Deshacer

```bash
sudo systemctl unmask sleep.target suspend.target hibernate.target hybrid-sleep.target
sudo rm /etc/systemd/logind.conf.d/99-solwed-always-on.conf
sudo systemctl restart systemd-logind
gsettings reset org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type
gsettings reset org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type
```
