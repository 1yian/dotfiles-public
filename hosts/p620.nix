{
  config,
  pkgs,
  lib,
  ...
}:

let
  fleet = import ./p620-fleet-packages.nix { inherit pkgs; };
in
{
  # Real /Users paths preserve imported worktrees and cwd-keyed Pi sessions.
  home.homeDirectory = lib.mkForce "/Users/yian";
  home.sessionVariables = {
    TWILIO_DISABLE_AUTOUPDATE = "1";
    # Use Chrome's namespace sandbox; Nix cannot provide a root-setuid helper.
    CHROME_DEVTOOLS_AXI_CHROME_ARGS = "--disable-setuid-sandbox";
    CHROME_DEVTOOLS_AXI_MCP_PATH = "${config.home.homeDirectory}/.local/libexec/p620-chrome-devtools-mcp.mjs";
  };
  # Puppeteer assumes /opt/google/chrome/chrome on Linux; supply the real HM
  # browser path instead of a root-owned symlink into a user's package tree.
  home.file.".local/libexec/p620-chrome-devtools-mcp.mjs".source =
    ../home/bin/p620-chrome-devtools-mcp.mjs;
  # Ubuntu owns the kernel, NVIDIA driver, disks, networking, and system services.
  # Home Manager owns only yian's shell, CLI tools, and shared agent configuration.
  targets.genericLinux.enable = true;
  # Headless CLI setup: do not install a second set of graphics drivers via Nix.
  targets.genericLinux.gpu.enable = false;
  programs.home-manager.enable = true;
  programs.starship.settings.os.symbols.Ubuntu = "󰕈";
  programs.tmux = {
    enable = true;
    terminal = "tmux-256color";
    extraConfig = ''
      # Preserve modified Enter keys for Pi and other terminal agents.
      set -g extended-keys on
      set -g extended-keys-format csi-u
    '';
  };
  programs.zsh.envExtra = ''
    if [ -r /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
      . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
    fi
  '';

  # Console-only login launcher. Pane shells and SSH never enter this path.
  programs.zsh.profileExtra = ''
    if [[ -o login && -z "$SSH_CONNECTION" && -z "$HERDR_PANE_ID" ]] \
        && [[ "$(tty)" == /dev/tty1 ]] \
        && [[ -x /usr/local/bin/p620-herdr-console ]]; then
      exec /usr/local/bin/p620-herdr-console
    fi
  '';

  # Seed a writable default, not a read-only symlink: Herdr's Settings saves it.
  # Existing local preferences (including migrated ones) are never overwritten.
  home.activation.herdrDefaults = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [[ ! -e "$HOME/.config/herdr/config.toml" ]]; then
      run mkdir -p "$HOME/.config/herdr"
      run install -m 644 ${pkgs.writeText "p620-herdr-defaults.toml" ''
        onboarding = false
        [theme]
        name = "terminal"
        [theme.custom]
        panel_bg = "#101014"
        sidebar_bg = "#0c0c10"
        active_row_bg = "#16161d"
        text = "#e6e6ea"
        accent = "#3dffc0"
        green = "#3dffc0"
        blue = "#6eb6ff"
        red = "#ff5c7a"
        yellow = "#ffb454"
      ''} "$HOME/.config/herdr/config.toml"
    fi
  '';

  home.activation.linuxFleetAgents = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run env PATH="${pkgs.nodejs}/bin:${pkgs.bash}/bin:$PATH" \
      ${pkgs.bash}/bin/bash ${../linux-agents.sh}
  '';

  home.packages = with pkgs; [
    zsh
    bashInteractive
    neovim
    nodejs
    bun
    uv
    gh
    cloudflared
    (google-cloud-sdk.overrideAttrs (old: {
      version = "589.0.0";
      installCheckPhase =
        builtins.replaceStrings [ google-cloud-sdk.version ] [ "589.0.0" ]
          old.installCheckPhase;
      src = fetchurl {
        url = "https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-589.0.0-linux-x86_64.tar.gz";
        hash = "sha256-jAFJxj9Yp3eVm7rBHMFQ/OmPL5F4p07zN84LOs8kt/A=";
      };
    }))
    terraform
    overmind
    redis
    postgresql
    python3
    ffmpeg
    shellcheck
    actionlint
    opencode
    google-chrome
    fleet.herdr
    fleet.treehouse
    fleet.no-mistakes
  ];

  # Keep the shared Mac fastfetch config and its Apple logo unchanged.
  home.file.".config/fastfetch/config.jsonc".source = lib.mkForce (
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.dotfiles/home/.config/fastfetch/p620.jsonc"
  );
}
