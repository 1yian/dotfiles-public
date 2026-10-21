#!/usr/bin/env bash
# Fresh Mac or Ubuntu P620 -> home applied. Run once. Later: ./rebuild.sh
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
HOST="$(printf '%s' "${BOOTSTRAP_HOST:-$(hostname -s)}" | tr '[:upper:]' '[:lower:]')"

case "$HOST:$(uname -s)" in
  maverick:Darwin|frontera:Darwin|p620:Linux) ;;
  *)
    echo "Unsupported host/platform '$HOST/$(uname -s)'." >&2
    echo "Expected maverick/frontera on macOS, or p620 on Linux." >&2
    echo "Override hostname only: BOOTSTRAP_HOST=maverick|frontera|p620." >&2
    exit 1
    ;;
esac

if [ "$(id -u)" = 0 ]; then
  echo "Run bootstrap as your login user, not root (sudo is requested when needed)." >&2
  exit 1
fi

if [ "$HOST" = p620 ] && { [ "$HOME" != /Users/yian ] || [ "$(getent passwd "$(id -un)" | cut -d: -f6)" != /Users/yian ]; }; then
  echo 'Run sudo ./p620-system.sh migrate-home, then prove a fresh SSH login first.' >&2
  exit 1
fi

if ! command -v nix >/dev/null 2>&1 && [ -r /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
  # shellcheck disable=SC1091
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
fi

echo "==> Host target: $HOST"

echo "==> Step 1: Determinate Nix"
if command -v nix >/dev/null 2>&1; then
  echo "    nix already installed"
else
  curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix \
    | sh -s -- install --no-confirm
  # shellcheck disable=SC1091
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
fi

echo "==> Step 2: symlink repo to ~/.dotfiles"
ln -sfn "$DIR" ~/.dotfiles

echo "==> Step 3: flake user check"
REAL_USER="$(whoami)"
FLAKE_USER="$(sed -nE 's/^[[:space:]]*user = "([^"]+)";.*/\1/p' "$DIR/flake.nix" | head -n1)"
if [ -z "$FLAKE_USER" ]; then
  echo "    Could not find user = in flake.nix" >&2
  exit 1
elif [ "$FLAKE_USER" != "$REAL_USER" ]; then
  if [ "${BOOTSTRAP_ASSUME_YES:-}" = "1" ]; then
    REPLY=y
  else
    read -r -p "    flake user is \"$FLAKE_USER\", you are \"$REAL_USER\". Rewrite? [y/N] " REPLY
  fi
  if [ "$REPLY" = "y" ] || [ "$REPLY" = "Y" ]; then
    tmp="$(mktemp)"
    sed -E "s/^([[:space:]]*user = \")[^\"]+(\";.*)/\1${REAL_USER}\2/" "$DIR/flake.nix" > "$tmp"
    cp "$tmp" "$DIR/flake.nix"
    rm "$tmp"
  else
    exit 1
  fi
fi

echo "==> Step 4: clear paths home-manager will symlink"
stamp="$(date +%Y%m%d-%H%M%S)"
backup_root="$HOME/.dotfiles-migration-$stamp"
migrate() {
  local target="$1"
  if [ -e "$target" ] || [ -L "$target" ]; then
    local dest="$backup_root${target#"$HOME"}"
    mkdir -p "$(dirname "$dest")"
    echo "    move $target -> $dest"
    mv "$target" "$dest"
  fi
}

if [ "$(uname -s)" = Darwin ]; then
  migrate "$HOME/.wezterm.lua"
  migrate "$HOME/.config/wezterm"
fi
migrate "$HOME/.config/fastfetch"
migrate "$HOME/.agents/AGENTS.md"
migrate "$HOME/.agents/skills"
migrate "$HOME/.claude/CLAUDE.md"
migrate "$HOME/.codex/AGENTS.md"
migrate "$HOME/.config/opencode/AGENTS.md"
# HM owns zsh under ~/.config/zsh; leave legacy ~/.zshrc as backup if present
if [ -f "$HOME/.zshrc" ] && [ ! -L "$HOME/.zshrc" ]; then
  migrate "$HOME/.zshrc"
fi

echo "==> Step 5: switch configuration for $HOST"
NIX_BIN="$(command -v nix || echo /nix/var/nix/profiles/default/bin/nix)"
if [ ! -x "$NIX_BIN" ]; then
  echo "    nix not found" >&2
  exit 1
fi

export NIX_CONFIG="${NIX_CONFIG:-}
experimental-features = nix-command flakes"

if [ "$HOST" = p620 ]; then
  "$NIX_BIN" run "$DIR#home-manager" -- switch --flake "$DIR#$HOST" -b backup
  # Home Manager activation installs the pinned Linux fleet agents.
  shell_path="$HOME/.nix-profile/bin/zsh"
  if ! grep -Fxq "$shell_path" /etc/shells; then
    printf '%s\n' "$shell_path" | sudo tee -a /etc/shells >/dev/null
  fi
  if [ "$(getent passwd "$REAL_USER" | cut -d: -f7)" != "$shell_path" ]; then
    sudo chsh -s "$shell_path" "$REAL_USER"
  fi
elif [ -x /run/current-system/sw/bin/darwin-rebuild ]; then
  sudo /run/current-system/sw/bin/darwin-rebuild switch --flake ~/.dotfiles#"$HOST"
else
  sudo "$NIX_BIN" --extra-experimental-features "nix-command flakes" \
    run github:nix-darwin/nix-darwin/nix-darwin-26.05#darwin-rebuild -- \
    switch --flake ~/.dotfiles#"$HOST"
fi

echo "==> Done on $HOST"
echo "    backups: ${backup_root:-none}"
echo "    next:    open a new terminal/SSH session, restart agents, run: ff"
