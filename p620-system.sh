#!/usr/bin/env bash
# Ubuntu machine setup, separate from unprivileged Home Manager. Never reboots.
set -euo pipefail

fail() { printf 'p620-system: %s\n' "$*" >&2; exit 1; }
[ "$(uname -s):$(uname -m):$(hostname -s)" = Linux:x86_64:p620 ] \
  || fail 'only run on the Ubuntu x86_64 P620'
[ "$(id -u)" = 0 ] || fail 'run with sudo'
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

migrate_home() {
  # An atomic exchange keeps the old sshd home AND its login shell available at
  # every instant. A normal mv followed by ln would leave a lockout window.
  python3 - <<'PY'
import ctypes
import hashlib
import os
import pwd
import stat
import subprocess
import tempfile

old, new = '/home/yian', '/Users/yian'
account = pwd.getpwnam('yian')
if account.pw_dir not in (old, new):
    raise SystemExit('Refusing unexpected passwd home: ' + account.pw_dir)
if os.path.islink('/Users') or os.path.ismount(old):
    raise SystemExit('Refusing symlinked /Users or mounted old home')
if not os.path.exists('/Users'):
    os.mkdir('/Users', 0o755)
parent = os.stat('/Users')
if parent.st_uid != 0 or stat.S_IMODE(parent.st_mode) != 0o755:
    raise SystemExit('/Users must be root-owned mode 755')
keys = old + '/.ssh/authorized_keys'
with open(keys, 'rb') as source:
    before = hashlib.sha256(source.read()).hexdigest()
if not os.access(account.pw_shell, os.X_OK):
    raise SystemExit('Current login shell is unavailable')

if os.path.islink(old):
    if os.readlink(old) != new or not os.path.isdir(new) or os.path.islink(new):
        raise SystemExit('Refusing unexpected home symlink layout')
else:
    if not os.path.isdir(old) or os.stat(old).st_uid != account.pw_uid:
        raise SystemExit('Old home is not a directory owned by yian')
    if os.path.lexists(new):
        raise SystemExit('Destination exists; refusing to overwrite it')
    if os.stat(old).st_dev != parent.st_dev:
        raise SystemExit('Atomic exchange requires the same filesystem')
    libc = ctypes.CDLL(None, use_errno=True)
    if not hasattr(libc, 'renameat2'):
        raise SystemExit('renameat2 unavailable; refusing non-atomic migration')
    # Before exchange, this self-link is unused by passwd. After exchange it
    # becomes /home/yian -> /Users/yian with the original directory at new.
    os.symlink(new, new)
    result = libc.renameat2(-100, old.encode(), -100, new.encode(), 2)
    if result != 0:
        error = ctypes.get_errno()
        os.unlink(new)
        raise OSError(error, os.strerror(error))
    os.sync()

# usermod refuses home changes while the user has any process, including the
# SSH session doing this work. vipw is the supported locked passwd editor and
# does not require killing sessions. Change exactly one field, never shadow.
if account.pw_dir != new:
    with tempfile.TemporaryDirectory(prefix='p620-passwd-') as scratch:
        editor = scratch + '/editor'
        with open(editor, 'w') as destination:
            destination.write('''#!/usr/bin/python3
import pathlib, sys
path = pathlib.Path(sys.argv[1])
lines = path.read_text().splitlines(keepends=True)
matched = 0
for index, line in enumerate(lines):
    fields = line.rstrip('\\n').split(':')
    if fields[0] == 'yian':
        assert len(fields) == 7 and fields[5] == '/home/yian'
        fields[5] = '/Users/yian'
        lines[index] = ':'.join(fields) + '\\n'
        matched += 1
assert matched == 1
path.write_text(''.join(lines))
''')
        os.chmod(editor, 0o700)
        subprocess.run(['vipw', '--passwd'], check=True, stdin=subprocess.DEVNULL,
                       env={**os.environ, 'EDITOR': editor, 'VISUAL': editor})
with open(new + '/.ssh/authorized_keys', 'rb') as source:
    assert hashlib.sha256(source.read()).hexdigest() == before
assert os.path.realpath(old) == new
assert os.access(account.pw_shell, os.X_OK)
assert pwd.getpwnam('yian').pw_dir == new
print('Home ready: /Users/yian; /home/yian resolves; authorized_keys unchanged')
PY
  echo 'STOP HERE: prove a fresh strict-host-key SSH login before other setup.'
}

install_system() {
  [ "$(getent passwd yian | cut -d: -f6)" = /Users/yian ] || fail 'migrate home first'
  export DEBIAN_FRONTEND=noninteractive
  # No full desktop/display manager, graphics driver, kernel or boot packages.
  apt-get update
  apt-get install -y --no-install-recommends \
    docker.io docker-compose-v2 build-essential pkg-config libpq-dev \
    python3 python3-venv curl ca-certificates unzip lsof psmisc \
    console-setup kbd fonts-dejavu-core cage foot grim apparmor
  # Load only this tool-specific profile, not every lane's/system's policies.
  apparmor_parser --skip-kernel-load "$DIR/system/p620-google-chrome.apparmor"
  install -m 644 "$DIR/system/p620-google-chrome.apparmor" /etc/apparmor.d/p620-google-chrome
  apparmor_parser --replace /etc/apparmor.d/p620-google-chrome
  usermod -aG docker yian
  systemctl enable --now docker.service
  echo 'Docker group applies on the next login; membership grants root-equivalent access.'
}

install_console() {
  local mode=$1
  [ "$(getent passwd yian | cut -d: -f6)" = /Users/yian ] || fail 'migrate home first'
  [ -x /Users/yian/.nix-profile/bin/herdr ] || fail 'switch Home Manager first'
  install -m 755 "$DIR/system/p620-herdr-console" /usr/local/bin/p620-herdr-console
  install -d /etc/p620-herdr /etc/systemd/system/getty@tty1.service.d
  printf '%s\n' "$mode" > /etc/p620-herdr/console-mode
  install -m 644 "$DIR/system/foot.ini" /etc/p620-herdr/foot.ini
  install -m 644 "$DIR/system/getty-autologin.conf" /etc/systemd/system/getty@tty1.service.d/p620-herdr.conf
  # The guard lives in HM's zprofile: only tty1, never SSH or pane shells.
  systemctl daemon-reload
  echo 'Configured. Restart only the monitor login: sudo systemctl restart getty@tty1'
}

case "${1:-}" in
  migrate-home) migrate_home ;;
  install) install_system ;;
  console-text) install_console text ;;
  console-kiosk) install_console kiosk ;;
  *) fail 'usage: sudo ./p620-system.sh migrate-home|install|console-text|console-kiosk' ;;
esac
