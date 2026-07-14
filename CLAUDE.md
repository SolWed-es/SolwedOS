# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

Solwed OS is a custom Linux distribution for Solwed's clients, built by remastering **AnduinOS** (a Windows 11-styled Ubuntu-based distro running GNOME with dash-to-panel/arc-menu-style extensions) using **Cubic** (Cubic ISO customization tool). Goal: Solwed-branded wallpaper/theme, boot/login screens, preinstalled apps/packages and default behavior, shipped to clients as a bootable ISO.

`solwed-os-manual.html` is the reference manual: a 4-level task list (visual identity → boot/login → behavior/apps → advanced infra) with exact file paths, commands, and risk ratings for each customization step. **Its assumptions about AnduinOS internals are superseded by `ANDUIN-BASELINE.md`** — facts verified directly against a clean AnduinOS 2.0.0 ISO's extracted filesystem. Where the two disagree, `ANDUIN-BASELINE.md` wins (e.g. dconf defaults live in `/etc/dconf/db/anduinos.d/`, not `local.d`; display manager is GDM3 only, no LightDM; Plymouth base theme to fork is `anduinos`, not `spinner`).

## Workflow

This isn't a conventional buildable codebase — work happens inside Cubic's chroot terminal, editing files inside the AnduinOS filesystem tree, then generating and boot-testing an ISO in a VM.

- Apply dconf-based system defaults with `dconf update` after editing anything under `/etc/dconf/db/anduinos.d/` (see `ANDUIN-BASELINE.md` — `local.d` is not loaded on this system).
- Regenerate GRUB config after editing `/etc/default/grub`: `update-grub`.
- Regenerate initramfs after any Plymouth theme change: `update-initramfs -u` (a bad `.script` here causes a silent black screen at boot, with no visible error).
- Snapshot the Cubic chroot before a large block of changes: `tar czf solwed-vX.Y-descripcion.tar.gz /ruta/al/chroot`.
- No graphical session exists inside the Cubic chroot, so visual/desktop changes (themes, panel/menu layout, login screen) cannot be validated there — always generate the ISO and boot-test in a VM (QEMU/VirtualBox) before chaining the next block of changes.

## Architecture (customization levels)

The manual organizes changes into 4 levels, ordered low-risk/reversible → high-risk/structural, each assuming the previous level already boot-tested clean:

1. **Visual identity** — wallpaper/lockscreen (register in `/usr/share/gnome-background-properties/`, set default via `/etc/dconf/db/anduinos.d/20-wallpapers.conf` pattern), system identity (`/etc/os-release`, `/etc/lsb-release` — keep `ID_LIKE=debian`, `VERSION_CODENAME=resolute`, `UBUNTU_CODENAME=resolute`, apt depends on these), icon/cursor accent color.
2. **Boot & login** — Plymouth splash theme (fork `/usr/share/plymouth/themes/anduinos/`, not `spinner`), GRUB (`/etc/default/grub`), GDM3 greeter (no LightDM on this system), MOTD (`/etc/update-motd.d/`).
3. **Behavior & apps** — preinstalled/removed packages (AnduinOS is a tree of `anduinos-*` metapackages with strict `Depends` — check `apt-cache rdepends` before purging anything, since removing one can cascade-remove `anduinos-desktop-core` and large parts of the desktop), GNOME panel/start-menu defaults as a new numbered file in `/etc/dconf/db/anduinos.d/`, locale/keyboard/timezone, browser homepage/bookmarks via Firefox enterprise policy (`/usr/lib/firefox/distribution/policies.json`).
4. **Advanced** — own signed APT repo for pushing updates without rebuilding the ISO, custom first-boot welcome wizard (replacing `gnome-initial-setup`), preinstalled-but-not-auto-started remote support agent (privacy: must not start without explicit client consent).

Key invariant across all levels: AnduinOS ships every branding aspect (theme, icons, wallpapers, extensions, dconf defaults) as its own versioned `anduinos-*` `.deb` package rather than files copied in by hand — mirror that pattern for Solwed branding (e.g. a `solwedos-wallpapers` package) so changes survive updates and are reproducible, instead of hand-editing files in place inside the Cubic chroot.

## Update-survival: AnduinOS packages fight back on upgrade

Verified against the real `postinst`/`.conffiles` of AnduinOS's own packages (`var/lib/dpkg/info/` in the clean reference ISO), not assumed: **almost nothing we customize is a protected dpkg conffile** (only `/etc/casper.conf` is). Every other file we edit in place — Plymouth theme selection, GDM background/theme selection, recolored icons and cursors, ArcMenu config and its icon, GNOME Shell/GTK dconf overrides, `/etc/default/grub`, `/etc/os-release`/`/etc/lsb-release` — belongs to an `anduinos-*` (or `base-files`/`grub2-common`) package that overwrites it silently on any future upgrade, with several packages (`plymouth-anduinos`, `anduinos-gdm3-wallpaper`) going further and unconditionally forcing `update-alternatives --set` back to their own theme in `postinst`'s `configure` step. Confirmed in production: a routine GNOME Software update reverted the boot splash back to "AnduinOS".

**Standing mitigation:** `alternatives-guard/` holds two idempotent scripts (`reassert-alternatives.sh` for the `update-alternatives` selections, `reassert-branding.sh` for everything else) plus matching `/etc/apt/apt.conf.d/` hook files (`DPkg::Post-Invoke`, fires after any dpkg/apt transaction — including ones GNOME Software/PackageKit triggers). Each script compares the live file against a known-good copy tracked in this repo (`branding/icons/`, `branding/cursors/`, `branding/panel/`, `branding/system-files/`, `grub-theme/`) and restores + reruns only what's needed (`dconf update`, `glib-compile-schemas`, `gtk-update-icon-cache`, `update-grub`, `update-initramfs`). Installed via `scripts/level2-05-alternatives-guard.sh` and `scripts/level2-06-branding-guard.sh`. **Any new file-based customization added to this project should get a matching tracked copy + restore step in this guard**, not just a one-time chroot edit — otherwise assume it will eventually get silently reverted by an upstream package update.
