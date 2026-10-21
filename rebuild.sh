#!/usr/bin/env bash
set -euo pipefail

HOST="$(hostname -s | tr '[:upper:]' '[:lower:]')"
case "$HOST:$(uname -s)" in
  maverick:Darwin|frontera:Darwin)
    exec /run/current-system/sw/bin/darwin-rebuild switch --flake ~/.dotfiles#"$HOST" "$@"
    ;;
  p620:Linux)
    if ! command -v nix >/dev/null 2>&1; then
      # shellcheck disable=SC1091
      . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
    fi
    exec nix --extra-experimental-features "nix-command flakes" run "$HOME/.dotfiles#home-manager" -- \
      switch --flake "$HOME/.dotfiles#$HOST" -b backup "$@"
    ;;
  *)
    echo "Unsupported host/platform '$HOST/$(uname -s)'." >&2
    echo "Expected maverick/frontera on macOS, or p620 on Linux." >&2
    exit 1
    ;;
esac
