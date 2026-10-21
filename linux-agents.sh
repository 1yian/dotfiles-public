#!/usr/bin/env bash
# Home Manager activation owns these Linux releases absent from nixpkgs.
# No credentials, hooks, daemon control, or account login. --force repairs a
# migrated node_modules tree (macOS optional dependencies are not portable).
set -euo pipefail

if [ "$(uname -s)" != Linux ] || [ "$(id -u)" = 0 ]; then
  echo 'Run linux-agents.sh as your Linux login user after Home Manager switch.' >&2
  exit 1
fi
case "${1:-}" in ''|--force) ;; *) echo 'usage: linux-agents.sh [--force]' >&2; exit 1 ;; esac
export PATH="$HOME/.nix-profile/bin:$HOME/.local/bin:$PATH"
packages=(
  @earendil-works/pi-coding-agent@1.3.0
  @anthropic-ai/claude-code@2.1.301
  @openai/codex@0.162.1
  @higgsfield/cli@1.1.26
  gh-axi@0.1.41
  chrome-devtools-axi@0.1.42
  chrome-devtools-mcp@1.11.0
  lavish-axi@0.1.89
  tasks-axi@0.2.6
  quota-axi@0.1.63
  gnhf@0.1.51
  twilio-cli@7.2.0
  vercel@64.2.0
)
# Idempotence is based on the installed packages, not a stamp that survives a
# broken/missing install. New pins are automatically reconciled on HM switch.
installed=$(npm ls --global --prefix "$HOME/.local" --depth=0 --json 2>/dev/null || true)
if [ "${1:-}" != --force ] && printf '%s' "$installed" | node -e '
let input = "";
process.stdin.on("data", chunk => input += chunk);
process.stdin.on("end", () => {
  try {
    const dependencies = JSON.parse(input).dependencies ?? {};
    const matches = process.argv.slice(1).every(spec => {
      const split = spec.lastIndexOf("@");
      return dependencies[spec.slice(0, split)]?.version === spec.slice(split + 1);
    });
    process.exit(matches ? 0 : 1);
  } catch { process.exit(1); }
});
' "${packages[@]}"; then
  echo 'Linux fleet npm releases already match their pins.'
else
  npm install --global --prefix "$HOME/.local" "${packages[@]}"
fi
pi --version
gh-axi --version
