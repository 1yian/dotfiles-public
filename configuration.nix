{ user, hostname, ... }:

{
  # Determinate manages the Nix daemon.
  nix.enable = false;

  nixpkgs.config.allowUnfree = true;
  nixpkgs.hostPlatform = "aarch64-darwin";

  networking.hostName = hostname;

  system.primaryUser = user;
  users.users.${user} = {
    home = "/Users/${user}";
    shell = "/bin/zsh";
  };
  system.stateVersion = 6;

  system.defaults = {
    NSGlobalDomain = {
      AppleInterfaceStyle = "Dark";
      KeyRepeat = 2;
      InitialKeyRepeat = 15;
      AppleShowAllExtensions = true;
      NSAutomaticCapitalizationEnabled = false;
      NSAutomaticPeriodSubstitutionEnabled = false;
      NSAutomaticSpellingCorrectionEnabled = false;
      NSAutomaticQuoteSubstitutionEnabled = false;
      NSNavPanelExpandedStateForSaveMode = true;
      NSNavPanelExpandedStateForSaveMode2 = true;
    };
    dock = {
      autohide = true;
      mru-spaces = false;
      show-recents = false;
    };
    finder = {
      AppleShowAllExtensions = true;
      FXPreferredViewStyle = "Nlsv";
      ShowPathbar = true;
      _FXShowPosixPathInTitle = true;
    };
    trackpad.Clicking = true;
  };

  nix-homebrew = {
    enable = true;
    inherit user;
    autoMigrate = true;
  };

  homebrew = {
    enable = true;
    # Existing brew trees on both Macs are large and not fully declared.
    onActivation.cleanup = "none";
    onActivation.autoUpdate = false;
    brews = [
      "zsh-autosuggestions"
      "zsh-syntax-highlighting"
    ];
    casks = [
      "wezterm"
      "font-jetbrains-mono-nerd-font"
    ];
  };
}
