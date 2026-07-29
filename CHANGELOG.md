# Changelog — Solwed OS

Registro de cambios de Solwed OS, versión a versión: qué cambió, qué bugs se encontraron y cómo se corrigieron.

## [1.0.0] — 2026-07-29

Primera versión sin sufijo "Beta".

### Added
- `/etc/issue` y `/etc/issue.net` (banner de login por TTY/SSH) llevan la identidad de Solwed OS — antes seguían mostrando la marca de la distribución base.
- El instalador de FacturaScripts, tras una instalación con éxito, se elimina del menú y del escritorio y se sustituye por un acceso directo real a la aplicación (abre la URL ya instalada en el navegador).

### Changed
- El selector de fondos de pantalla del panel de Ajustes ya no incluye una entrada de la distribución base.
- Las 26 traducciones del nombre de la aplicación "Apariencia" quedan con la marca correcta (antes solo estaba traducido el español y el valor por defecto).
- El widget del tiempo de la barra de tareas viene desactivado por defecto (antes activado); si se activa a mano, arranca directo con una ubicación precargada, sin ventanas de configuración.

### Fixed
- El guardián de actualización de marca no disparaba la regeneración del menú de arranque (GRUB) al restaurar la identidad del sistema — un sistema con actualizaciones pendientes podía mostrar temporalmente la marca de la distribución base en el menú de arranque pese a que el resto del sistema ya estuviera bien.
- El script de despliegue del guardián de marca podía dejar de refrescar su copia de referencia de forma silenciosa si el directorio de staging no se limpiaba primero — quedaba protegiendo una versión desactualizada del sistema sin que nada lo indicara.
- El fondo de escritorio/login/bloqueo llevaba el logotipo superpuesto al panel de usuario, ilegible. Corregido quitando el icono del logotipo (se mantiene el nombre en texto).

## [Beta 1.3.0] — 2026-07-24

### Added
- Bloqueado, mediante un pin de gestor de paquetes, un asistente de configuración de primer arranque de la distribución base que empezó a llegar por una actualización normal — no aportaba nada que el asistente de bienvenida propio no cubriera ya, y no llevaba la identidad de Solwed OS.

### Fixed
- **Causa real del error del widget del tiempo, encontrada tras un primer intento incompleto:** el proveedor de geolocalización automática por IP usado por la extensión quedaba bloqueado por una protección anti-bot, de forma estructural (le pasa a cualquier instalación, no a un entorno concreto) — los otros dos proveedores alternativos también estaban rotos (límite de peticiones agotado / servicio dado de baja aguas arriba). Solución: se precarga una ubicación fija por defecto, sin depender de ningún servicio externo de geolocalización; el cliente puede cambiarla a mano si lo desea.
- El widget del tiempo vuelve a activarse por defecto (se había desactivado temporalmente como solución provisional al bug anterior) — con la ubicación ya precargada, se activa solo sin mostrar ninguna ventana de configuración.

## [Beta 1.0.3] — 2026-07-22

### Added
- Prototipo de acceso directo a un asistente de chat con inteligencia artificial, conectado a un servidor propio.

### Fixed
- El logotipo de marca (icono "W.") llevaba desde una versión anterior con un color mal aplicado en dos de sus cuatro trazos — el fichero corregido nunca había llegado al control de versiones, solo se había aplicado a mano en un build concreto.
- Corregido un bug real en el guardián de actualización de marca: varios iconos del sistema son en realidad enlaces simbólicos a otro fichero real, y el guardián los tenía registrados por el nombre del enlace en vez del nombre real — la copia de restauración escribía en el fichero equivocado y el icono se revertía solo en cada ejecución.
- Corregido un segundo bug en el propio mecanismo de instalación del guardián: al copiar sobre un directorio ya existente en vez de sustituirlo, los ficheros ya eliminados del proyecto seguían acumulados en el destino y volvían a aplicarse.
- El campo "ID de recuperación" del sistema de contraseña de rescate ya no depende de la identidad interna de la herramienta de soporte remoto — se genera de forma propia e independiente, evitando un caso real de colisión entre dos instalaciones distintas del mismo cliente.

## [Beta 1.0.1] — 2026-07-21

### Added
- Regla de permisos para que, tras iniciar sesión como administrador, ninguna acción que requiera permisos elevados vuelva a pedir confirmación durante esa sesión (decisión de negocio, con el compromiso de seguridad correspondiente aceptado).
- Interfaz web de consulta para el equipo de soporte: formulario protegido por autenticación para consultar la contraseña de rescate de un equipo a partir de su ID de recuperación, sin necesidad de herramientas de línea de comandos.
- El identificador de recuperación se muestra en la propia pantalla de inicio de sesión (vista de "usuario no listado"), legible sin necesidad de iniciar sesión — pensado para el caso de un cliente bloqueado fuera de su cuenta.
- Sistema de contraseña de rescate por equipo: cada instalación genera su propia contraseña local en el primer arranque real y la registra en un servidor propio, sustituyendo a una contraseña compartida entre todo el parque de equipos.

### Fixed
- El logotipo grande del panel "Acerca de" en Ajustes → Sistema seguía mostrando la marca de la distribución base — ese panel no usa el mecanismo estándar de identidad del sistema, tiene la ruta del logotipo fija en el propio binario de Ajustes.
- Cerrado un fallo de seguridad real: la documentación autogenerada de la API del servidor de soporte quedaba accesible públicamente sin autenticación, exponiendo la estructura interna de la API. Desactivada por completo.
- La consulta de contraseñas de rescate pasó de una petición de tipo GET a una de tipo POST, para que el identificador no quede expuesto en el historial del navegador ni en los registros de acceso del servidor.

### Changed
- Versión renombrada de fase Alpha a Beta.

## [Alpha 4.8.0] — 2026-07-17

### Added
- Cuenta local de rescate para clientes bloqueados fuera de su cuenta, sin contraseña compartida entre equipos.

### Fixed
- Corregidos tres fallos reales en la puesta en marcha del sistema de rescate: un fallo de tubería en la generación de la contraseña aleatoria, un registro que capturaba la identidad incorrecta (la del proceso del sistema en vez de la del cliente), y una confusión de entorno de despliegue entre dos terminales distintas del proceso de construcción.

## [Alpha 4.7.0] — 2026-07-16

### Changed
- Reescrito el contenido y las capturas de pantalla del instalador gráfico: tres diapositivas genéricas de la distribución base sustituidas por contenido relevante (catálogo de aplicaciones, soporte remoto, actualizaciones), traducido a los 27 idiomas soportados. Eliminado cualquier resto visual o textual de la marca de la distribución base en el instalador.

## [Alpha 4.6.0] — 2026-07-16

### Added
- Asistente de bienvenida de primer inicio de sesión: aviso único con la lista de aplicaciones preinstaladas y los canales de soporte disponibles.

## [Alpha 4.5.1] — 2026-07-16

### Fixed
- El usuario elegido durante la instalación real no llegaba a crearse (solo quedaba disponible la cuenta de rescate) — mismo tipo de fallo que en la versión anterior, esta vez en la copia del instalador gráfico, que llevaba su propia lógica duplicada sin el mismo ajuste aplicado.
- El icono de la Tienda de software / instalador de FacturaScripts seguía mostrando el color por defecto (azul) en vez del color de marca.

## [Alpha 4.4.0] — 2026-07-15

### Fixed
- El arranque en modo live y la instalación real dejaban de crear automáticamente la cuenta de usuario normal en cuanto existía otra cuenta de sistema con un identificador dentro de cierto rango — causado por añadir la cuenta local de rescate. Corregido con el ajuste de compatibilidad que el propio mecanismo de creación de usuarios ya contempla para este caso.

## [Alpha 4.3.1] — 2026-07-15

### Fixed
- La preconfiguración del cliente de soporte remoto no llegaba a aplicarse de fábrica: la plantilla se depositaba con una capitalización de ruta distinta a la que el programa realmente lee en este sistema. Con el nombre de ruta correcto, la conexión al servidor propio queda preconfigurada sin ninguna intervención manual.

### Added
- Servidor de repositorio de paquetes propio, con clave de firma dedicada y publicación mediante herramienta de gestión de repositorios.
- Servidor propio de soporte remoto desplegado (registro y retransmisión de conexiones).

## [Alpha 4.2.0] — 2026-07-14

### Added
- Segundo guardián de actualización de marca, más amplio: reafirma iconos, cursores, menú de inicio, tema del sistema, identidad (`os-release`/`lsb-release`) y GRUB si una actualización de paquete los revierte.

### Fixed
- Los botones de la pantalla de inicio de sesión (Wifi, accesibilidad, teclado) se mostraban en azul en vez del color de acento — causado por una hoja de estilos estática de la distribución base que se reescribe por completo al generar el fondo de esa pantalla. Recoloreada la hoja de estilos y documentado como limitación conocida el interruptor de modo claro/oscuro de esa misma pantalla (no depende de nada personalizable en este sistema).
- El splash de arranque y el fondo de la pantalla de inicio de sesión volvían a mostrar la marca de la distribución base tras una actualización desde la tienda de aplicaciones — los paquetes correspondientes reafirman su propia configuración en cada actualización, de forma incondicional. Añadido el primer guardián de actualización (disparado tras cualquier operación de gestión de paquetes) que revierte esto automáticamente.

## [Alpha 4.1.1] — 2026-07-14

### Added
- Tema gráfico propio para el menú de arranque (GRUB), con tiempo de espera visible de 5 segundos.
- Selección de idioma español por defecto en el menú del medio de instalación.

## [Alpha 4.0.0] — 2026-07-13

### Added
- Cliente de soporte remoto preinstalado y preconfigurado contra un servidor propio (sin servidor todavía desplegado en esta versión).

### Fixed
- Neutralizado que el paquete del cliente de soporte remoto activara por defecto su servicio de acceso desatendido (sin confirmación ni presencia del usuario) — queda desactivado de fábrica, tal y como se requiere.

## [Alpha 3.2.1] — 2026-07-10

### Fixed
- Completado el recoloreo de iconos de aplicaciones que había quedado a medias (terminal, e icono de la Tienda de software con una capa incrustada como imagen que el primer script de recoloreo no alcanzaba).
- Corregido el logotipo de marca, que llevaba mal aplicado el color en dos de sus cuatro trazos desde su introducción.

## [Alpha 3.2.0] — 2026-07-10

### Added
- Autofirma (firma electrónica), Okular (lector/firmador de PDF).
- Fondos de escritorio de mayor resolución.

### Changed
- Navegador por defecto: sustituido por Brave.
- Cliente de escritorio remoto de terceros evaluado y retirado — no resolvía el caso de uso real (acceso entrante de soporte, no saliente del cliente).

### Fixed
- Corregida la confianza de certificados de Autofirma en el navegador por defecto (el instalador solo la registraba en almacenes que este navegador no usa).
- Corregido que LibreOffice se cerrara solo, sin error visible, segundos después de abrirse en el sistema ya instalado — causado por una capa de compatibilidad del sistema que no preservaba correctamente los descriptores de archivo esperados por el decodificador de imágenes en sandbox. Sustituida por una invocación directa.
- Corregido el acceso directo al navegador en el menú de inicio, que había quedado apuntando a la aplicación anterior tras el cambio de navegador por defecto.

## [Alpha 3.1.1] — 2026-07-09

### Fixed
- El instalador gráfico de FacturaScripts no completaba la instalación: elevar todo el proceso a administrador de una vez impedía mostrar cualquier ventana gráfica en este sistema (arquitectura de sesión gráfica sin compatibilidad heredada). Separado en un lanzador sin privilegios (con la interfaz) y un proceso de trabajo con privilegios elevados (sin interfaz), comunicados por una tubería de progreso.
- Corregido un aviso de módulo de servidor web no cargado que rompía las URLs de FacturaScripts — el servicio arrancaba antes de que se activara el módulo necesario y no se reiniciaba después.

## [Alpha 3.1.0] — 2026-07-09

### Added
- Instalador gráfico de FacturaScripts (facturación y contabilidad) bajo demanda, no preinstalado.
- Carpeta de aplicaciones ofimáticas y acceso directo al cliente de correo en el menú de inicio.
- Mecanismo permanente para que cualquier acceso directo nuevo en el escritorio se considere de confianza automáticamente, sin advertencia previa.

## [Alpha 3.0.0] — 2026-07-09

### Added
- Suite ofimática completa preinstalada.
- Cliente de correo, con complemento de mensajería web integrado.

### Fixed
- Corregido que la gestión de repositorios de terceros (PPA) dejara de funcionar tras el cambio de identidad del sistema — faltaban dos ficheros de plantilla propios de la distribución base que esa herramienta necesita para resolver el nombre del sistema.

## [Alpha 2.8.0] — 2026-07-09

### Fixed
- El interruptor de "mostrar el tiempo" del panel de apariencia no venía activado por defecto pese a estar la extensión correspondiente ya instalada y preconfigurada.
- Teclado por defecto corregido a distribución española (antes en inglés) en consola y en la sesión gráfica.
- Corregido que la barra superior del escritorio siguiera con el tema neutro de la distribución base en vez del tema de color de marca.
- Corregido el mismo problema de color en el instalador (Ubiquity) y en cualquier aplicación con interfaz gráfica que herede la configuración por defecto del sistema.

### Changed
- Reescritas las diapositivas del instalador gráfico en los 27 idiomas soportados, quitando referencias a infraestructura propia de la distribución base y redirigiendo el soporte a los canales de Solwed.

## [Alpha 2.6.0] — 2026-07-08

### Fixed
- El tema de cursores (incluido el indicador de carga animado junto al puntero) mantenía el color azul por defecto de la distribución base — es un asset binario independiente del tema de iconos, nunca recoloreado hasta esta versión. Recoloreados los cursores afectados preservando sombreado y transparencia originales.

## [Alpha 2.5.0] — 2026-07-08

### Fixed
- Corregido que el usuario y el nombre de equipo del modo live siguieran mostrando la marca de la distribución base pese a haber editado la configuración correspondiente — el fichero editado se empaqueta dentro de la imagen de arranque en un paso de compilación aparte; sin regenerarla, el cambio no llegaba a aplicarse.
- Renombrada la aplicación de apariencia del menú de inicio a la marca de Solwed OS.
- Recoloreado el icono del botón de inicio del menú.

## [Alpha 2.4.0] — 2026-07-08

### Fixed
- Corregido el logotipo que aparecía bajo el panel de inicio de sesión / bloqueo, que seguía siendo el de la distribución base — es un elemento independiente del fondo de pantalla, configurado por separado.

## [Alpha 2.3.0] — 2026-07-08

### Changed
- El splash de arranque pasa de mostrar solo el icono de marca a mostrar el nombre completo junto al icono, con el color de acento aplicado correctamente en el propio icono.
- Reajustada la posición del logotipo del fondo de pantalla para no chocar con la barra de tareas del escritorio.

## [Alpha 2.2.0] — 2026-07-08

Primera versión con el arranque y el inicio de sesión (splash, fondo de login) rebrandeados de punta a punta.

### Fixed
- Reajustada la posición del logotipo del fondo de pantalla, que se superponía al panel de inicio de sesión.
- Corregido el texto del menú de arranque del medio de instalación, que seguía nombrando a la distribución base.
- Mejorado el contraste del fondo de pantalla de bloqueo en modo claro (este sistema reutiliza el fondo de escritorio también para la pantalla de bloqueo, sin clave de configuración independiente).

## Primeras versiones — identidad visual e instalación

Trabajo previo a la numeración de versiones: identidad del sistema, fondo de pantalla, iconos, cursores y color de acento personalizados; corrección de dos fallos estructurales de arranque heredados de la distribución base (uno relacionado con la partición de arranque UEFI de cualquier imagen regenerada, y otro con una restricción de sandbox de descodificación de imágenes que dejaba el escritorio instalado sin fondo ni iconos).

## Problemas conocidos, sin resolver

- El indicador de carga animado junto al puntero se muestra en color azul por defecto, en vez del color de acento, en algunos entornos virtualizados concretos — investigación en pausa, sin causa confirmada.
