{ config, lib, pkgs, username, ... }:

{
  imports = [
    ./desktop/common.nix # mako, ghostty, Wayland utilities
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
  ];

  xdg.enable = true;

  # --- Dotfiles ---
  # Home Manager generates and owns the configs of the programs enabled here,
  # in home/desktop/common.nix and in home/dwl/default.nix: zsh (.zshrc),
  # git, delta, fzf, zoxide, bat, lsd, htop, tmux, yazi, mako, ghostty,
  # swaylock and fuzzel. dwl has no config file, its config.h is compiled in.
  # Only nvim and vim come from ~/.dotfiles, as mkOutOfStoreSymlink links
  # (see above), so they stay editable in place. Don't `stow` any of the
  # Home Manager-owned names from ~/.dotfiles: stow refuses to overwrite the
  # generated files/symlinks, and the two would fight over them anyway.
}
