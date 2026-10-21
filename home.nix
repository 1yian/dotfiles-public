{ config, pkgs, lib, user, hostname, ... }:

let
  dotfiles = "${config.home.homeDirectory}/.dotfiles";
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
  ink = {
    base = "#101014";
    mantle = "#0c0c10";
    surface = "#16161d";
    overlay = "#5c5c6a";
    subtext = "#8b8b96";
    text = "#e6e6ea";
    signal = "#3dffc0";
    signalDim = "#1a9e74";
    soft = "#9b8cff";
    info = "#6eb6ff";
    warn = "#ffb454";
    error = "#ff5c7a";
  };
in
{
  home.username = user;
  home.homeDirectory = if isDarwin then "/Users/${user}" else "/home/${user}";
  home.stateVersion = "24.11";
  home.language.base = "en_US.UTF-8";

  home.packages = with pkgs; [
    # `pi` ahead of the npm-installed one: a launch whose cwd is exactly a Firstmate
    # home (Herdr session restore, non-interactive shells) gets FM_HOME like optpi.
    (writeShellScriptBin "pi" ''
      if [ -z "''${FM_HOME:-}" ]; then
        case "$PWD" in
          "$HOME"/fm-homes/*/*|"$HOME"/fm-homes/) ;;
          "$HOME"/fm-homes/*)
            if [ -d "$PWD/config" ] && [ -d "$PWD/data" ]; then
              FM_HOME="$PWD"
              export FM_HOME
            fi
            ;;
        esac
      fi
      exec "$HOME/.local/bin/pi" "$@"
    '')
    # core CLI
    ripgrep
    fd
    fzf
    jq
    lazygit
    tree
    bat
    eza
    zoxide
    delta
    glow
    fastfetch
    # fonts
    nerd-fonts.jetbrains-mono
  ];

  fonts.fontconfig.enable = true;

  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
    DOTFILES_HOST = hostname;
    # bat / delta / man
    BAT_THEME = "ansi";
    MANPAGER = "sh -c 'col -bx | bat -l man -p'";
    MANROFFOPT = "-c";
    # fzf ink + signal
    FZF_DEFAULT_OPTS = lib.concatStringsSep " " [
      "--height=45%"
      "--layout=reverse"
      "--border=rounded"
      "--info=inline"
      "--prompt=❯ "
      "--pointer=▶"
      "--marker=■"
      "--color=bg:${ink.base},bg+:${ink.surface},fg:${ink.text},fg+:${ink.text}"
      "--color=hl:${ink.signal},hl+:${ink.signal},info:${ink.overlay},prompt:${ink.signal}"
      "--color=pointer:${ink.signal},marker:${ink.signalDim},spinner:${ink.soft},header:${ink.subtext}"
      "--color=border:${ink.overlay},gutter:${ink.base},query:${ink.text}"
    ];
    FZF_CTRL_T_OPTS = "--preview 'bat --color=always --style=plain --line-range=:200 {} 2>/dev/null || eza -la --color=always {}'";
    FZF_ALT_C_OPTS = "--preview 'eza -la --color=always --tree --level=2 {}'";
    # eza
    EZA_COLORS = "uu=0:gu=0:sn=32:sb=32:da=36:ur=37:uw=37:ux=37:ue=37:gr=37:gw=37:gx=37:tr=37:tw=37:tx=37";
    # Claude via Vertex: set ANTHROPIC_VERTEX_PROJECT_ID locally and opt in per run with CLAUDE_CODE_USE_VERTEX=1
    CLOUD_ML_REGION = "global";
    CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1";
    BUN_INSTALL = "$HOME/.bun";
  };

  home.sessionPath = [
    "$HOME/.local/bin"
    "$HOME/.bun/bin"
  ] ++ lib.optional isDarwin "/Applications/WezTerm.app/Contents/MacOS";

  programs.git = {
    enable = true;
    lfs.enable = true;
    settings = {
      user = {
        name = "Yian Wong";
        email = "16216651+1yian@users.noreply.github.com";
      };
      push.autoSetupRemote = true;
      pull.rebase = true;
      rebase.updateRefs = true;
      color.ui = true;
      init.defaultBranch = "main";
      core.pager = "delta";
      interactive.diffFilter = "delta --color-only";
      delta = {
        navigate = true;
        side-by-side = false;
        line-numbers = true;
        syntax-theme = "ansi";
        plus-style = "syntax #0d2a22";
        minus-style = "syntax #2a1218";
        plus-emph-style = "syntax #1a9e74";
        minus-emph-style = "syntax #ff5c7a";
        map-styles = "bold purple => syntax #9b8cff, bold blue => syntax #6eb6ff, bold cyan => syntax #3dffc0, bold yellow => syntax #ffb454";
      };
    };
  };

  programs.starship = {
    enable = true;
    enableZshIntegration = true;
    settings = {
      add_newline = false;
      command_timeout = 1000;
      palette = "ink_signal";
      format = lib.concatStrings [
        "[](fg:surface)"
        "$os"
        "$directory"
        "[](fg:surface bg:mantle)"
        "$git_branch"
        "$git_status"
        "[](fg:mantle)"
        "$fill"
        "$cmd_duration"
        "$hostname"
        "$line_break"
        "$character"
      ];
      palettes.ink_signal = {
        ink = ink.base;
        mantle = ink.mantle;
        surface = ink.surface;
        overlay = ink.overlay;
        subtext = ink.subtext;
        text = ink.text;
        signal = ink.signal;
        soft = ink.soft;
        error = ink.error;
        warn = ink.warn;
      };
      fill = {
        symbol = " ";
        style = "fg:overlay";
      };
      os = {
        disabled = false;
        style = "fg:signal bg:surface";
        format = "[ $symbol ]($style)";
      };
      os.symbols = {
        Macos = "󰀵";
      };
      directory = {
        style = "fg:text bg:surface";
        format = "[ $path ]($style)";
        truncation_length = 3;
        truncate_to_repo = true;
        truncation_symbol = "…/";
      };
      git_branch = {
        symbol = "";
        style = "fg:subtext bg:mantle";
        format = "[ $symbol$branch ]($style)";
      };
      git_status = {
        style = "fg:signal bg:mantle";
        format = "[$all_status$ahead_behind]($style)";
        conflicted = "⇕";
        ahead = "⇡\${count} ";
        behind = "⇣\${count} ";
        diverged = "⇕⇡\${ahead_count}⇣\${behind_count} ";
        untracked = "?";
        stashed = "≡";
        modified = "!";
        staged = "+";
        renamed = "»";
        deleted = "✘";
      };
      cmd_duration = {
        min_time = 1500;
        style = "fg:overlay";
        format = "[  $duration ]($style)";
      };
      hostname = {
        ssh_only = true;
        style = "fg:soft";
        format = "[  $hostname ]($style)";
      };
      character = {
        success_symbol = "[❯](bold signal)";
        error_symbol = "[❯](bold error)";
        vimcmd_symbol = "[❮](bold soft)";
      };
    };
  };

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.bat = {
    enable = true;
    config = {
      style = "plain";
      paging = "never";
    };
  };

  programs.eza = {
    enable = true;
    enableZshIntegration = true;
    git = true;
    icons = "auto";
    extraOptions = [ "--group-directories-first" ];
  };

  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
  };

  programs.zsh = {
    enable = true;
    dotDir = "${config.home.homeDirectory}/.config/zsh";
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    history = {
      size = 60000;
      save = 60000;
      path = "${config.home.homeDirectory}/.local/share/zsh/history";
      ignoreDups = true;
      ignoreSpace = true;
      share = true;
    };
    shellAliases = {
      ".." = "cd ..";
      "..." = "cd ../..";
      g = "git";
      ga = "git add";
      gc = "git commit";
      gs = "git status -sb";
      gd = "git diff";
      gl = "git log --oneline -20";
      push = "git push";
      pull = "git pull";
      m = "git switch main";
      add = "git add .";
      lg = "lazygit";
      rebuild = "${dotfiles}/rebuild.sh";
      dots = "cd ${dotfiles}";
      ff = "fastfetch";
      # ink-tinted cat via bat
      cat = "bat --paging=never";
    };
    initContent = ''
      # --- ink + signal line editor ------------------------------------------
      ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#5c5c6a'
      ZSH_AUTOSUGGEST_STRATEGY=(history completion)
      bindkey '^f' autosuggest-accept
      bindkey '^[[Z' reverse-menu-complete

      # self-heal leaked Kitty keyboard protocol (e.g. a TUI killed with ctrl+c
      # never pops its pushed flags, which breaks ctrl+c at the shell prompt).
      autoload -Uz add-zsh-hook
      _fix_kitty_kbd() { printf '\e[<u\e[=0;1u' }
      add-zsh-hook precmd _fix_kitty_kbd

      typeset -A ZSH_HIGHLIGHT_STYLES
      ZSH_HIGHLIGHT_STYLES[command]='fg=#3dffc0'
      ZSH_HIGHLIGHT_STYLES[builtin]='fg=#3dffc0'
      ZSH_HIGHLIGHT_STYLES[alias]='fg=#3dffc0'
      ZSH_HIGHLIGHT_STYLES[function]='fg=#3dffc0'
      ZSH_HIGHLIGHT_STYLES[precommand]='fg=#3dffc0,underline'
      ZSH_HIGHLIGHT_STYLES[unknown-token]='fg=#ff5c7a,underline'
      ZSH_HIGHLIGHT_STYLES[single-quoted-argument]='fg=#ffb454'
      ZSH_HIGHLIGHT_STYLES[double-quoted-argument]='fg=#ffb454'
      ZSH_HIGHLIGHT_STYLES[single-hyphen-option]='fg=#9b8cff'
      ZSH_HIGHLIGHT_STYLES[double-hyphen-option]='fg=#9b8cff'
      ZSH_HIGHLIGHT_STYLES[path]='fg=#6eb6ff'
      ZSH_HIGHLIGHT_STYLES[comment]='fg=#5c5c6a'
      ZSH_HIGHLIGHT_STYLES[redirection]='fg=#9b8cff'
      ZSH_HIGHLIGHT_STYLES[arg0]='fg=#3dffc0'

      # completion UI
      zstyle ':completion:*' menu select
      zstyle ':completion:*' list-colors "''${(s.:.)LS_COLORS}"
      zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}' 'r:|=*' 'l:|=* r:|=*'
      zstyle ':completion:*:descriptions' format '%F{#5c5c6a}%d%f'
      zstyle ':completion:*:messages' format '%F{#9b8cff}%d%f'
      zstyle ':completion:*:warnings' format '%F{#ff5c7a}no matches%f'

      # paths: user tooling first
      typeset -U path
      ${if isDarwin then ''
        path=("$HOME/.local/bin" /opt/homebrew/bin /usr/local/bin /opt/homebrew/share/google-cloud-sdk/bin $path)
        export PATH

        if command -v brew >/dev/null 2>&1; then
          export PATH="$(brew --prefix libpq)/bin:$PATH"
        fi'' else ''
        path=("$HOME/.local/bin" $path)
        export PATH''}

      # cargo / bun when present
      [ -r "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"
      [ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

      ${lib.optionalString isDarwin ''
        # gcloud
        if [ -r /opt/homebrew/share/google-cloud-sdk/path.zsh.inc ]; then
          . /opt/homebrew/share/google-cloud-sdk/path.zsh.inc
        fi
        if [ -r /opt/homebrew/share/google-cloud-sdk/completion.zsh.inc ]; then
          . /opt/homebrew/share/google-cloud-sdk/completion.zsh.inc
        fi''}

      # conda (optional - only if installed)
      if [ -x "$HOME/miniconda3/bin/conda" ]; then
        __conda_setup="$("$HOME/miniconda3/bin/conda" shell.zsh hook 2>/dev/null)"
        if [ $? -eq 0 ]; then
          eval "$__conda_setup"
        fi
        unset __conda_setup
      fi

      ${lib.optionalString isDarwin ''
        # chruby (optional)
        if [ -r /opt/homebrew/opt/chruby/share/chruby/chruby.sh ]; then
          source /opt/homebrew/opt/chruby/share/chruby/chruby.sh
          source /opt/homebrew/opt/chruby/share/chruby/auto.sh
          chruby ruby-3.1.3 2>/dev/null || true
        fi''}

      # claude: default max effort when flag omitted
      claude() {
        local a
        for a in "$@"; do
          case $a in --effort|--effort=*) command claude "$@"; return ;; esac
        done
        command claude --effort max "$@"
      }

      # Launch Pi with OptChat enabled for the current directory.
      optpi() {
        FM_HOME="$PWD" command pi "$@"
      }

      # host badge for SSH / multi-machine awareness
      if [[ -n "$DOTFILES_HOST" && -o interactive ]]; then
        : # starship + wezterm already show context; keep shell quiet
      fi
    '';
  };

  # Out-of-store symlinks: edit in repo, live on disk.
  # Older WezTerm builds reliably discover this canonical entrypoint.
  home.file.".wezterm.lua" = lib.mkIf isDarwin {
    source = config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/wezterm/wezterm.lua";
  };
  home.file.".config/wezterm" = lib.mkIf isDarwin {
    source = config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/wezterm";
  };
  home.file.".local/bin/mav-open-url" = lib.mkIf isDarwin {
    source = config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/bin/mav-open-url";
  };
  home.file.".local/bin/omp-bridge-image" = lib.mkIf isDarwin {
    source = config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/bin/omp-bridge-image";
  };
  home.file.".local/bin/daily-tool-update-note" = lib.mkIf (isDarwin && hostname == "maverick") {
    source = config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/bin/daily-tool-update-note";
  };

  # 05:00 local on maverick only. The agent asks firstmate; it does not update
  # tools, and it does not keep a process between runs. launchd coalesces a
  # missed interval on wake.
  launchd.agents = lib.mkIf (isDarwin && hostname == "maverick") {
    daily-tool-update = {
      enable = true;
      config = {
        ProgramArguments = [
          "${config.home.homeDirectory}/.local/bin/daily-tool-update-note"
        ];
        StartCalendarInterval = [
          {
            Hour = 5;
            Minute = 0;
          }
        ];
        WorkingDirectory = config.home.homeDirectory;
        EnvironmentVariables = {
          HOME = config.home.homeDirectory;
          PATH = "${config.home.homeDirectory}/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin";
        };
      };
    };
  };

  home.file.".agents/AGENTS.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/AGENTS.md";
  home.file.".agents/skills".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.agents/skills";
  home.file.".pi/agent/skills/principles".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.agents/skills/principles";

  # Pi: per-file links; ~/.pi/agent/{extensions,themes} also hold local, unmanaged files.
  home.file.".pi/agent/AGENTS.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/AGENTS.md";
  home.file.".pi/agent/themes/ink-signal.json".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.pi/agent/themes/ink-signal.json";
  # Vertex and automatic Anthropic rate-limit fallback stay macOS-only here.
  home.file.".pi/agent/extensions/vertex-claude" = lib.mkIf isDarwin {
    source = config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.pi/agent/extensions/vertex-claude";
  };
  home.file.".pi/agent/extensions/anthropic-rate-limit-fallback.ts" = lib.mkIf isDarwin {
    source = config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.pi/agent/extensions/anthropic-rate-limit-fallback.ts";
  };

  # Pi files are linked individually so local providers and credentials stay local.
  home.file.".pi/agent/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.pi/agent/settings.json";
  home.file.".pi/agent/tiers.json".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.pi/agent/tiers.json";
  # Extra Claude subscriptions (pi-multi-pass providers) get pi-anthropic-auth's request shaping.
  home.file.".pi/agent/extensions/pi-anthropic-auth/config.json".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.pi/agent/pi-anthropic-auth.json";
  home.file.".pi/agent/extensions/statusline.ts".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.pi/agent/extensions/statusline.ts";
  home.file.".pi/agent/extensions/fm-readable-ui.ts".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.pi/agent/extensions/fm-readable-ui.ts";
  home.file.".pi/agent/extensions/fm-optchat".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.pi/agent/extensions/fm-optchat";
  home.file.".pi/agent/optchat".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.pi/agent/optchat";

  home.file.".claude/CLAUDE.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/AGENTS.md";
  home.file.".codex/AGENTS.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/AGENTS.md";
  home.file.".config/opencode/AGENTS.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/AGENTS.md";

  home.file.".config/fastfetch/config.jsonc".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/fastfetch/config.jsonc";
}
