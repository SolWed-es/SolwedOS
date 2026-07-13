#!/bin/sh
# Bug #5 fix: /usr/bin/bwrap must exec bwrap.real directly (no shell fork/wait
# layer), otherwise the fds glycin passes via --seccomp/--dbus-fd don't survive
# into the sandboxed loader, and it exits silently before doing any work.
# Run from inside Cubic's chroot terminal (root there, no sudo).

cat > /usr/bin/bwrap <<'EOF'
#!/bin/sh
exec /usr/bin/bwrap.real "$@"
EOF
chmod +x /usr/bin/bwrap

cat /usr/bin/bwrap
