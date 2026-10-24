{ config, lib, pkgs, username, ... }:

{
  imports = [
    ./desktop/noctalia.nix
  ];

  home.username = username;
  home.homeDirectory = "/home/${username}";
  home.stateVersion = "24.11";

  programs.home-manager.enable = true;

  # --- Shell ---
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
  };

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

  programs.fzf.enable = true;
  programs.zoxide.enable = true;
  programs.bat.enable = true;
  programs.lsd.enable = true;
  programs.htop.enable = true;
  programs.tmux.enable = true;
  programs.yazi.enable = true;

  # --- CLI / TUI & Dev Tools (README.md section 3) ---
  home.packages = with pkgs; [
    ripgrep
    duf
    dust
    jq
    tree
    git-lfs
    glab
    stow
    tree-sitter
    glow
    sops
    age
    rsync
    wget
    socat
    sshpass
    strace
    smartmontools
    plocate
    neovim

    nodejs
    python3
    python3Packages.pip
    pipx

    # minikube bundles its own (older) kubectl under bin/, which otherwise
    # collides with the standalone kubectl package below during buildEnv;
    # hiPrio makes the explicit, newer kubectl win that conflict.
    (lib.hiPrio kubectl)
    kubernetes-helm
    minikube
    terraform
    terraform-ls
    vagrant

    cpufetch
    fastfetch

    # --- GUI: work / study (README.md section 3) ---
    firefox
    vesktop # Wayland-native Discord client, replaces discord + telegram combo bloat
    telegram-desktop
    obsidian
    keepassxc
    zathura
    syncthing
    obs-studio

    # --- Gaming: user-level helpers (system-wide bits live in configuration.nix) ---
    protontricks
    mangohud
  ];

  xdg.enable = true;

  # --- Dotfiles ---
  # The current Arch setup symlinks ~/.config/{niri,kitty,rofi,...} into
  # ~/.dotfiles via GNU stow. Keep using that workflow during the migration:
  # home-manager intentionally does NOT manage those dirs here to avoid two
  # tools fighting over the same symlinks. Once the suckless/DWL stack is
  # final, port the dotfiles' content into xdg.configFile blocks instead.
}
