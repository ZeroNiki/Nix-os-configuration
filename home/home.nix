{ username, ... }:

{
  imports = [
    ./shell.nix # zsh, starship, CLI utilities, fastfetch
    ./dev.nix # nvim config, LSP servers and formatters, languages, DevOps
    ./apps.nix # GUI programs, mpv, default applications, gaming
    ./desktop/common.nix # mako, ghostty, Wayland utilities
    ./dwl # dwl + bar (dwlb) + launcher theme, see home/dwl/default.nix
    ./firefox # programs.firefox + the start page, see home/firefox/default.nix
  ];

  home.username = username;
  home.homeDirectory = "/home/${username}";
  home.stateVersion = "24.11";

  programs.git = {
    enable = true;
    settings = {
      user.name = "Nella Rory";
      user.email = "nmenshov935@gmail.com";
      init.defaultBranch = "main";
    };
  };
  programs.delta = {
    enable = true;
    enableGitIntegration = true;
  };

  xdg.enable = true;

  # --- Dotfiles ---
  # Home Manager generates and owns the configs of the programs enabled here,
  # in shell.nix, dev.nix, apps.nix, desktop/common.nix and dwl/default.nix:
  # zsh (.zshrc), git, delta, fzf, zoxide, starship, bat, lsd, htop, yazi,
  # fastfetch, mpv, Firefox policies (not the profile), mimeapps.list, mako,
  # ghostty, swaylock, swayidle and fuzzel. dwl has no config file, its
  # config.h is compiled in. Only nvim comes from ~/.dotfiles, as an
  # mkOutOfStoreSymlink link (dev.nix), so it stays editable in place.
}
