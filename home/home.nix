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
  # Ported from ~/.dotfiles/.zshrc, which is not linked: Home Manager owns
  # ~/.zshrc. Arch-only bits (fzf sourcing from /usr/share, zoxide init,
  # spicetify PATH) are dropped -- programs.fzf/zoxide do the first two.
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    # keep ~/.zshrc where it has always been (and silence the dotDir warning)
    dotDir = config.home.homeDirectory;

    # autosuggestions/syntax-highlighting come from the options above,
    # so they're not repeated here as oh-my-zsh plugins
    oh-my-zsh = {
      enable = true;
      plugins = [ "git" "copyfile" ];
    };

    plugins = [
      {
        name = "powerlevel10k";
        src = pkgs.zsh-powerlevel10k;
        file = "share/zsh-powerlevel10k/powerlevel10k.zsh-theme";
      }
    ];

    sessionVariables = {
      TERM = "xterm-256color";
      MANPAGER = "less -R";
      MANOPT = "-L ru_RU.UTF-8";
    };

    shellAliases = {
      v = "vim";
      nv = "nvim";
      cat = "bat";
      l = "lsd -lh";
      la = "lsd -lah";
      ls = "lsd";
      du = "dust";
      df = "duf";
      k = "kubectl";
      h = "helm";
      mkdir = "mkdir -p";
      otter = "otter-launcher";
      c = "clear";
      fetch = "fastfetch";
      # y is the yazi wrapper below, not an alias
    };

    initContent = lib.mkMerge [
      # Powerlevel10k instant prompt, has to stay at the very top of ~/.zshrc
      (lib.mkOrder 500 ''
        if [[ -r "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh" ]]; then
          source "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh"
        fi
      '')
      ''
        # To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
        [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

        typeset -g POWERLEVEL9K_INSTANT_PROMPT=off
      ''
    ];
  };

  home.sessionPath = [ "$HOME/.local/bin" ]; # pipx

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

  programs.fzf = {
    enable = true;
    defaultOptions = [
      "--height 40%"
      "--layout=reverse"
      "--border"
      "--preview 'bat --style=numbers --color=always --line-range :500 {}'"
    ];
  };
  programs.zoxide.enable = true;
  programs.bat.enable = true;
  programs.lsd = {
    enable = true;
    # its zsh integration only adds ls/ll/la/lt aliases, which clash with
    # the ones ported from the old .zshrc in programs.zsh.shellAliases
    enableZshIntegration = false;
  };
  programs.htop.enable = true;
  programs.tmux.enable = true;
  programs.yazi = {
    enable = true;
    # `y` opens yazi and cd's into the last directory on exit
    shellWrapperName = "y";
  };

  # --- Neovim / Vim configs from ~/.dotfiles ---
  # Out-of-store symlinks so they stay writable: lazy.nvim rewrites
  # lazy-lock.json, which a read-only /nix/store copy would not allow.
  xdg.configFile."nvim".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.dotfiles/.config/nvim";
  home.file.".vimrc".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.dotfiles/.vimrc";

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

    # --- nvim: LSP servers and formatters ---
    # Installed here instead of through mason (its ensure_installed lists
    # are empty in the nvim config): binaries mason downloads are
    # dynamically linked for FHS distros and often fail to start on NixOS.
    lua-language-server
    pyright
    typescript-language-server
    clang-tools # clangd + clang-format
    bash-language-server
    yaml-language-server
    vscode-langservers-extracted # jsonls
    stylua
    isort
    black
    prettier
    shfmt
    codespell
    # building plugins: telescope-fzf-native (make + cc), treesitter parsers
    gcc
    gnumake
    fd # telescope find_files

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
