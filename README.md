# dotfiles

Shared agent + terminal setup on **maverick**, **frontera**, and **p620**.

Mac stack: Nix + nix-darwin + Home Manager + Homebrew, shaped like [Kun's Mac setup](https://blog.kunchenguid.com/p/how-i-built-a-reproducible-mac-setup).
Ubuntu stack (P620): Nix + standalone Home Manager, with no nix-darwin or Homebrew.

## Machines

| Host | Flake attr | Notes |
|------|------------|--------|
| `maverick` | `darwinConfigurations.maverick` (`#maverick`) | This MacBook. |
| `frontera` | `darwinConfigurations.frontera` (`#frontera`) | Twin Mac, same user `yian`. |
| `p620` | `homeConfigurations.p620` (`#p620`) | Ubuntu Server, x86_64, user `yian`, real home `/Users/yian`; `/home/yian` is a compatibility symlink. |

`./rebuild.sh` and `./bootstrap.sh` pick the attr from `hostname -s`.

## Shared source of truth (locked)

- **AGENTS.md** - maverick version
- **skills** - maverick set: `axi`, `grill-me`, `lavish`, `no-mistakes`, `ui-ux-pro-max`
- **Look** - green-field **ink + signal** (WezTerm, starship, fzf, zsh highlight)

Host-only overlays live in `hosts/<name>.nix` (and WezTerm hostname branches).

## Aesthetic: ink + signal

| Token | Hex | Use |
|-------|-----|-----|
| ink base | `#101014` | background |
| mantle | `#0c0c10` | panels |
| signal | `#3dffc0` | accent, cursor, prompt, success |
| soft | `#9b8cff` | secondary (thinking, options) |
| error | `#ff5c7a` | errors |
| text | `#e6e6ea` | primary text |

Midnight pit-wall styling: JetBrainsMono Nerd Regular at 15pt, generous padding,
97% opacity, and a persistent numbered tab rail with hostname and clock.
Inactive panes stay readable. Mint headings and selection accents complete the look.
The giant Apple remains available on the Macs through `ff`; P620 uses Ubuntu.
No automatic file listing.

WezTerm reloads its linked Lua config automatically. Shared agent and shell
files apply to all hosts; each machine must have the updated checkout.

## Layout

```
flake.nix                 two darwinConfigurations + homeConfigurations.p620
configuration.nix         shared macOS + brew
hosts/maverick.nix        host overlay
hosts/frontera.nix
hosts/p620.nix            Ubuntu user tools, home path, console-only login guard
hosts/p620-fleet-packages.nix  checksum-pinned Linux fleet binaries
p620-system.sh            Ubuntu packages, atomic home move, tty1 autologin
system/                  monitor launcher, getty drop-in, foot colors/font
home.nix                  packages, zsh, starship, symlinks
home/.config/wezterm/     ink + signal terminal
home/.config/fastfetch/
home/.pi/agent/           Pi settings, status line, readable transcript, optional OptChat
home/AGENTS.md
home/.agents/skills/
bootstrap.sh
rebuild.sh
linux-agents.sh           HM activation's pinned Linux npm fleet CLIs
home/bin/daily-tool-update-note  maverick 05:00 firstmate inbox note
```

[Shared Pi configuration](home/.pi/agent/README.md) applies through individual out-of-store links. Run `optpi` to launch Pi with `FM_HOME` set to the current directory; plain `pi` is unchanged.

Secrets stay local: Pi auth/model files, ADC, cloudflared credentials. Never committed.

## Bootstrap

```bash
# on any supported machine, after clone
git clone git@github.com:1yian/dotfiles.git ~/Projects/dotfiles
cd ~/Projects/dotfiles
./bootstrap.sh
```

On the Macs, Homebrew cleanup is `none` so existing packages are not zapped.
On P620, migrate the home and prove a new SSH login first (below). Bootstrap
switches the locked standalone Home Manager and sets the login shell to the
stable `~/.nix-profile/bin/zsh`. HM activation reconciles the pinned npm CLIs
into `~/.local` only when versions differ. Initial installation requires npm
network access; rebuilds with matching versions do not reinstall. No service
login or credential transfer happens here.

Ubuntu owns the kernel, NVIDIA driver, disk mounts, and machine networking.
Nix manages its own daemon; Home Manager manages user-level configuration.
Bootstrap never changes disks, graphics drivers, GRUB, EFI, BIOS, or firmware. `/`, `/data`, and
`/scratch` must remain mounted by UUID, not NVMe device name.
Linux user tools include Node, Bun, uv, tmux, Neovim, gh, gcloud, cloudflared, Terraform,
direnv, overmind, Redis, PostgreSQL clients, Python, ffmpeg, shellcheck,
actionlint, headless Google Chrome, and the fleet tools below. Ubuntu owns
Docker and its Compose plugin. Docker-group membership grants root-equivalent
access, as does the already configured passwordless sudo.
WezTerm, Homebrew paths, and Mac clipboard/browser bridge scripts stay
darwin-only. P620's `ff` uses Ubuntu; tmux enables extended keys and 256 colors.
The Linux browser adapter passes HM's actual Chrome executable path to the
pinned MCP; plain `chrome-devtools-axi` works without a hardcoded `/opt` install.
Ubuntu's tool-specific `p620-google-chrome` AppArmor profile permits the Nix
Chrome executable to create user namespaces. Its `flags=(unconfined)` is an
explicitly approved exemption, not restrictive AppArmor confinement. Chrome's
own namespace sandbox remains enabled; only its SUID helper is disabled.
No `--no-sandbox`, global AppArmor reload, or kernel/sysctl changes are used.
To remove the policy after stopping Chrome clients:
`sudo apparmor_parser --remove /etc/apparmor.d/p620-google-chrome && sudo rm -- /etc/apparmor.d/p620-google-chrome`.
Also remove its installation step from `p620-system.sh` if changing that decision,
since rerunning `install` restores the committed policy.
Twilio's automatic updater is disabled to preserve its pin.
Cleo's Supabase CLI remains project-pinned via `npm ci`; its `cleo-cli` launcher
comes from the project after Firstmate copies it, not from this repo.

### P620 fleet release pins

Derived from Maverick's installed inventory and tracked Firstmate's
`bin/fm-bootstrap.sh` dependency check, plus Cleo prerequisites:

| Tool | Linux pin |
|------|-----------|
| Herdr | 0.9.5 |
| treehouse | 3.1.4 |
| no-mistakes | 1.84.0 public release |
| Pi | 1.3.0 |
| Claude Code / Codex | 2.1.301 / 0.162.1 |
| gh-axi / chrome-devtools-axi | 0.1.41 / 0.1.42 |
| chrome-devtools-mcp (Linux browser adapter) | 1.11.0 |
| lavish-axi / tasks-axi / quota-axi | 0.1.89 / 0.2.6 / 0.1.63 |
| Higgsfield / gnhf | 1.1.26 / 0.1.51 |
| Twilio / Vercel | 7.2.0 / 64.2.0 |
| gcloud | 589.0.0 |

Release tags checked 2026-10-15. Other user packages follow `flake.lock`, not
Homebrew's incidental installed versions. Shared Pi packages are exact pins:
pi-web-access 0.41.0, pi-fff 0.11.0, pi-anthropic-auth 3.4.2,
pi-catppuccin-tui 0.1.3, and codex-fast-mode 0.1.2. The work settings retain
only their existing subset. Patched pi-optchat stays at 0.7.2; do not use its
newer upstream release or replace a running home's prepared copy.

Lavish 0.1.89 passes Firstmate's `fm-bootstrap.sh lavish-compatible` and
`lavish-reply-compatible` checks, enabling synchronous reply acceptance rather
than the older 0.1.79 legacy path. Mac-only CuaDriver, WezTerm bridges and
Xcode/iOS tooling are not replaced with Linux substitutes.

These are Linux installation pins, not an assertion that the fleet is already
updated. Mac npm CLIs, Herdr, treehouse, and no-mistakes are installed outside
this repo. At the 2026-10-15 pre-rollout inventory, Herdr differed: maverick
0.9.0, P620 0.9.1, frontera 0.9.4. Coordinate their update to 0.9.5 before
relying on frontera's remote link; changing this Linux pin alone does not
update either Mac or any running Herdr server. Only Firstmate may arrange a
live-server upgrade or update the shared no-mistakes daemon.

Audit declarations and README consistency with `python3 scripts/check-tool-pins.py`;
add `--latest` to compare the npm pins with the registry without installing.

### First P620 checkout without GitHub credentials

From an authenticated machine, copy a bundle of `main` (or substitute the desired branch):

```bash
git bundle create /tmp/dotfiles.bundle main
scp -o StrictHostKeyChecking=yes -o UserKnownHostsFile=/tmp/p620-known /tmp/dotfiles.bundle yian@p620:/tmp/dotfiles.bundle
ssh -o StrictHostKeyChecking=yes -o UserKnownHostsFile=/tmp/p620-known yian@p620 'mkdir -p ~/Projects; git clone --branch main /tmp/dotfiles.bundle ~/Projects/dotfiles; cd ~/Projects/dotfiles; git remote set-url origin https://github.com/1yian/dotfiles.git'
# Then migrate home, prove fresh SSH, and bootstrap, as below.
```

Only tracked repository content is transferred. Do not copy local agent state,
secrets, or credentials. Set `BOOTSTRAP_HOST` only to override the hostname;
bootstrap still validates that the selected host matches the OS.

### P620 machine setup and monitor

Use the pinned `/tmp/p620-known` file supplied by Firstmate. Verify its ED25519
fingerprint is `SHA256:2xALbDjBLrqtUWjN6ahvxFPrkxG/uJKybXasymn2LWs`.
Stop on a mismatch; never edit `~/.ssh/known_hosts` to work around it.
For an existing checkout, transfer a bundle of the desired branch, then
`git fetch /tmp/dotfiles.bundle <branch>` and fast-forward/switch that branch
in `~/Projects/dotfiles`. P620 does not need GitHub credentials for this.

Run the machine steps separately, in order:

```bash
# On P620, with the updated tracked checkout:
cd ~/Projects/dotfiles
sudo ./p620-system.sh migrate-home
# Stop here and open a NEW strict-key SSH connection from Maverick:
ssh -o StrictHostKeyChecking=yes -o UserKnownHostsFile=/tmp/p620-known yian@p620 \
  'echo "HOME=$HOME"; getent passwd yian; readlink -f /home/yian'
# Must show HOME=/Users/yian and /home/yian resolving to /Users/yian.
# Then, in that new P620 login:
cd ~/Projects/dotfiles
sudo ./p620-system.sh install
./bootstrap.sh
sudo ./p620-system.sh console-kiosk
sudo systemctl restart getty@tty1   # only the monitor login, not the machine
```

The home migration atomically exchanges directory and symlink on the same
filesystem, then uses `vipw`'s passwd lock to change only yian's home field.
It neither copies nor rewrites `authorized_keys`, kills login sessions, nor
restarts sshd. Unexpected destinations/mounts are refused rather than merged.
The old absolute login-shell and Nix-profile paths keep working via the symlink.
Steps are idempotent; no reboot, firmware, kernel, networking, GRUB, partition,
`fstab`, `/data`, or `/scratch` change is performed.

**Physical access is passwordless admin access.** tty1 autologins as yian.
Only that local login enters the monitor launcher; SSH gets a normal shell.
The launcher runs cage with one full-screen foot terminal and Herdr's explicit
`--session default`. Cage uses software rendering on the existing Ubuntu DRM
seat, not a desktop/display manager or Nix graphics drivers. Foot provides
UTF-8 box drawing, truecolor and a readable 18pt JetBrainsMono Nerd Font at
2560x1440, using ink + signal. Detach/quit or a killed client reattaches after
two seconds without closing foot/cage; the detached server/panes are not in
the getty kill scope. Foot's render workers are disabled to avoid a pixman
shutdown race on this many-core host. HM seeds a writable ink + signal Herdr
config only when absent; existing/migrated preferences are preserved.
Herdr's normal session state persists in the user's own configuration directory.
Do not stop its server to restart the monitor.

`console-text` selects the plain framebuffer console alternative (16x32 font,
160x45 cells on this monitor). Inspect `/dev/vcs1`/`/dev/vcsu1`; use the kiosk
when the console's limited palette/glyphs cannot render Herdr correctly.
For the kiosk, capture the actual display with `grim` as yian using its
`/run/user/1000/wayland-*` socket, not an SSH terminal screenshot.
For recovery, another VT still offers a normal login, or use SSH to disable
`/etc/systemd/system/getty@tty1.service.d/p620-herdr.conf` and restart tty1.

## Daily 05:00 general system update

Maverick's Home Manager launchd agent runs `daily-tool-update-note` at 05:00 local time.
The script submits an actionable inbox note, not a reminder, giving `fm-inbox.sh note` 60 seconds to submit it; this is not the update deadline.
Firstmate must immediately dispatch a worker without asking for confirmation to update and verify **both maverick and P620**:

- Sync each dotfiles clone: fetch, fast-forward pull if behind, push if ahead, and report divergence instead of forcing, rebasing, merge-resolving, or discarding uncommitted or unpushed work. After a pull, inspect the activation plan and switch Home Manager only if safe and non-disruptive.
- Reconcile Pi and its extensions, no-mistakes, and lavish-axi to dotfiles pins. Update firstmate and secondmates through `bin/fm-update.sh`. Update other installed global npm, pipx, and uv tools without overriding managed pins.
- On maverick, run `brew update` and eligible `brew upgrade`, preserving pins. Never run macOS system updates.
- On P620, run `apt update`, inventory installed and candidate kernel/NVIDIA packages (including meta-packages, images, headers, modules, libraries, and firmware), apply and verify `apt-mark hold` **before** `apt upgrade`, and leave those holds in place. Inspect a simulated upgrade first; never permit protected installs, replacements, removals, or upgrades, and never use full-upgrade, dist-upgrade, or release upgrades. Inspect snap refresh candidates and refresh only eligible snaps, excluding kernel, driver, GPU/Strata, BIOS, and firmware components.
- Restart only verified idle sessions through guarded paths. Defer shared no-mistakes daemon updates/restarts while other work is running. Never reboot or change BIOS/firmware, drivers, GPU/Strata, credentials, or the major OS version through any updater, including Home Manager.

Verify dotfiles revision/sync state, Home Manager results, installed CLI/extension versions against pins, package-manager results, remaining updates, and P620 holds plus unchanged kernel/NVIDIA versions directly on each host. Report one concise line per machine to the captain with versions, changes, holds, deferrals, and failures.
The note is handled only after **both** machines are successfully updated and verified. Offline hosts, failed commands, and deferred or unverified required updates must be reported and left pending for retry, not marked done at dispatch.
The request id is `daily-tool-update-YYYY-MM-DD`, so a replay the same day does not create a second note.
Output is appended to `~/Library/Logs/daily-tool-update.log`.
There is no P620 timer.
The agent is armed on the next maverick `rebuild`. A merged commit alone does
not install it: confirm `launchctl list | grep daily-tool-update` and the
`~/.local/bin/daily-tool-update-note` link after switching.

After merging a tool refresh, fast-forward each checkout and run `rebuild` on
P620 and maverick. Do not restart existing Pi sessions or secondmates. A new
ordinary Pi launch reconciles missing or changed npm package pins; `pi update
--extensions` deliberately skips exact npm pins. Verify a fresh Pi startup on
P620, the installed CLI versions on both hosts, and the Herdr version match
(including frontera) before declaring the rollout complete.

## Day to day

```bash
dots          # cd ~/.dotfiles
# edit…
rebuild       # darwin-rebuild on Macs, home-manager switch on p620
```

App configs are out-of-store symlinks - repo edits apply immediately. Package/shell module changes need `rebuild`.
On Linux, `rebuild` is unprivileged and uses the flake's locked Home Manager CLI.
HM switches reconcile pinned agents automatically. To repair a copied macOS
npm tree, run `./linux-agents.sh --force`; do not copy native Mac binaries over
Linux packages. No-mistakes is installed but its shared daemon is not started,
restarted or configured by this setup.

## P620 fleet handoff (Firstmate-owned)

No projects, Firstmate/secondmate homes, credentials, or OptChat sessions are
copied by this setup. Firstmate performs that separate authorized migration
and fleet cutover, then verifies the tool accounts work. If a credential is not
portable, authenticate on P620 using its tool's supported login:

- GitHub: `gh auth login` and `gh auth setup-git` for private repos (gh-axi uses the same authentication).
- Google Cloud / Vertex: `gcloud auth login` and `gcloud auth application-default login`, with access to the Vertex project set in `ANTHROPIC_VERTEX_PROJECT_ID`.
- Pi: `/login` for each intended subscription provider (for example Anthropic or OpenAI), or provision provider API keys locally.
- Claude Code / Codex / OpenCode: their own login flows for any account-backed use; Claude's configured Vertex mode instead needs the gcloud ADC above.
- Any additional Firstmate integrations (Higgsfield, search, Cloudflare tunnels, etc.) need their own credentials if enabled later. No integration login is attempted here.

## Bring up the other Mac

1. Clone this repo to `~/Projects/dotfiles`
2. Confirm `hostname -s` is `maverick` or `frontera`
3. `./bootstrap.sh`
4. Copy secrets by hand: gcloud ADC as needed
