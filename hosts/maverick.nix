{ user, ... }:

{
  # Maverick-only machine bits. Shared look/feel stays in configuration.nix + home.nix.
  # cloudflared tunnel "maverick" stays launchd-local (credentials are machine-bound).

  environment.variables = {
    DOTFILES_HOST = "maverick";
  };
}
