{ config, lib, pkgs, username, ... }:

{
  imports = [
    ./desktop/noctalia.nix
    ./dwl # dwl + bar (dwlb) + launcher theme, see home/dwl/default.nix
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
    claude-code

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

    # --- Niri default-config safety net ---
    # On the fresh machine ~/.config/niri/config.kdl won't exist yet (the real
    # dotfiles come later via stow, see the note at the bottom of this file),
    # so Niri writes its own default config, whose built-in binds expect
    # `alacritty` (Mod+T) and `fuzzel` (Mod+D) -- neither of which is
    # otherwise installed here (ghostty/rofi are the chosen terminal/launcher,
    # wired up in home/desktop/noctalia.nix, but only once that config.kdl is
    # in place). Keep these two around so the very first login still has a
    # working terminal and launcher before the stow step happens. Mod+Shift+/
    # shows the full default keybind cheat sheet; Mod+Shift+E exits the session.
    alacritty
    fuzzel
  ];

  xdg.enable = true;

  # --- Dotfiles ---
  # Home Manager already generates and owns the config files for several of
  # the programs enabled above and in home/desktop/noctalia.nix: zsh (.zshrc),
  # git, delta, fzf, zoxide, bat, lsd, htop, tmux, yazi, waybar, rofi, mako,
  # and ghostty. Running `stow` from ~/.dotfiles for any of those same names
  # will refuse to overwrite Home Manager's generated files/symlinks (stow
  # errors out rather than clobbering them) — remove those entries from the
  # dotfiles stow package list, or stop managing them here, don't run both.
  #
  # Niri is the exception: `programs.niri.enable` only installs the binary
  # and session glue (modules/desktop/niri.nix) — it does NOT manage
  # ~/.config/niri/config.kdl. That one still comes from `~/.dotfiles` via
  # stow, same as before. On a fresh install Niri will have already written
  # its own default config.kdl on first login (see the "Niri default-config
  # safety net" packages above) — delete that auto-created file before
  # running `stow niri`, or stow will refuse there too.
}
