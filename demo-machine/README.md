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

## Deshacer

```bash
sudo systemctl unmask sleep.target suspend.target hibernate.target hybrid-sleep.target
sudo rm /etc/systemd/logind.conf.d/99-solwed-always-on.conf
sudo systemctl restart systemd-logind
gsettings reset org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type
gsettings reset org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type
```
