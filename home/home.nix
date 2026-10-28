{ config, lib, pkgs, username, ... }:

let
  # Prompt: "starship" (Pure-style, see programs.starship below; no oh-my-zsh)
  # or "p10k" to roll back to oh-my-zsh + powerlevel10k with ~/.p10k.zsh,
  # which is left in place for that.
  prompt = "starship";
  starship = prompt == "starship";
  omz = "${pkgs.oh-my-zsh}/share/oh-my-zsh";
in
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
  # With prompt = "starship" oh-my-zsh is gone, only its git aliases stay
  # (sourced from the package in initContent).
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    # keep ~/.zshrc where it has always been (and silence the dotDir warning)
    dotDir = config.home.homeDirectory;

    # autosuggestions/syntax-highlighting come from the options above,
    # so they're not repeated here as oh-my-zsh plugins
    oh-my-zsh = lib.mkIf (!starship) {
      enable = true;
      plugins = [ "git" "copyfile" ];
    };

    plugins = lib.optional (!starship) {
      name = "powerlevel10k";
      src = pkgs.zsh-powerlevel10k;
      file = "share/zsh-powerlevel10k/powerlevel10k.zsh-theme";
    };

    # TERM is left to the terminal (xterm-ghostty): forcing xterm-256color
    # turned off undercurl, the kitty keyboard protocol and more in nvim.
    # Over ssh ghostty copies its terminfo to the host or falls back to
    # xterm-256color by itself (ssh-terminfo/ssh-env in home/desktop/common.nix).
    sessionVariables = {
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

    initContent =
      if starship then
        ''
          # oh-my-zsh's git aliases (gst, ga, gc, gp, gcl, ...) without
          # oh-my-zsh; lib/git.zsh has git_current_branch, some of them call it.
          # Its precmd hook removes itself with add-zsh-hook, which oh-my-zsh
          # used to autoload (now only zsh-autosuggestions does, by chance).
          autoload -Uz add-zsh-hook
          source ${omz}/lib/git.zsh
          source ${omz}/plugins/git/git.plugin.zsh

          # what the copyfile plugin did: a file's contents to the clipboard
          copyfile() { wl-copy <"''${1:?usage: copyfile FILE}"; }
        ''
      else
        lib.mkMerge [
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

  # Pure-style prompt, the same layout ~/.p10k.zsh had: directory and git on
  # the first line, command time / virtualenv / user@host (ssh and root only)
  # on its right, then the prompt character alone on the second line.
  # ANSI colors, so ghostty's Everforest paints them.
  programs.starship = {
    enable = starship;
    settings = {
      add_newline = true;
      format = "$directory$git_branch$git_state$git_status$fill$cmd_duration$python$username$hostname$line_break$character";
      fill.symbol = " ";
      directory = {
        style = "blue";
        truncation_length = 8;
        truncate_to_repo = false;
      };
      git_branch = {
        format = "[$branch]($style)";
        style = "bright-black";
      };
      git_state.format = " [$state( $progress_current/$progress_total)]($style)";
      git_status = {
        format = "( [$conflicted$untracked$modified$staged$renamed$deleted]($style))( [$ahead_behind$stashed](cyan))";
        style = "red";
        conflicted = "=";
        untracked = "?";
        modified = "!";
        staged = "+";
        renamed = "»";
        deleted = "✘";
        stashed = "≡";
        ahead = "⇡";
        behind = "⇣";
        diverged = "⇡⇣";
      };
      cmd_duration = {
        min_time = 3000;
        format = "[$duration]($style) ";
        style = "yellow";
      };
      # only with an active virtualenv, not for every directory with .py files
      python = {
        format = "[$virtualenv]($style) ";
        style = "bright-black";
        detect_extensions = [ ];
        detect_files = [ ];
      };
      username = {
        format = "[$user]($style)";
        style_user = "bright-black";
        style_root = "red";
      };
      hostname.format = "[@$hostname]($style) ";
      hostname.style = "bright-black";
      character = {
        success_symbol = "[❯](purple)";
        error_symbol = "[❯](red)";
        vimcmd_symbol = "[❮](green)";
      };
    };
  };

  home.sessionPath = [ "$HOME/.local/bin" ]; # pipx

  # no VirtualBox here: `vagrant up` goes to libvirt (the vagrant-libvirt
  # plugin comes with nixpkgs' vagrant, see `vagrant plugin list`)
  home.sessionVariables.VAGRANT_DEFAULT_PROVIDER = "libvirt";

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
  # `, cowsay` runs a program from nixpkgs without installing it, and an
  # unknown command says which package has it. The database is prebuilt
  # (nix-index-database input in flake.nix), nothing to index locally.
  programs.nix-index.enable = true;
  programs.nix-index-database.comma.enable = true;
  programs.bat.enable = true;
  programs.lsd = {
    enable = true;
    # its zsh integration only adds ls/ll/la/lt aliases, which clash with
    # the ones ported from the old .zshrc in programs.zsh.shellAliases
    enableZshIntegration = false;
  };
  programs.htop.enable = true;
  programs.yazi = {
    enable = true;
    # `y` opens yazi and cd's into the last directory on exit
    shellWrapperName = "y";
  };

  # Minimal fastfetch: small NixOS logo, a handful of lowercase keys,
  # ANSI colors, so the terminal theme (Everforest) paints them.
  programs.fastfetch = {
    enable = true;
    settings = {
      logo = {
        source = "nixos_small";
        color = {
          "1" = "green";
          "2" = "green";
        };
        padding = {
          top = 1;
          right = 3;
        };
      };
      display = {
        separator = "  ";
        key.width = 8;
        color = {
          keys = "green";
          title = "green";
        };
      };
      modules = [
        "title"
        { type = "os"; key = "os"; }
        { type = "kernel"; key = "kernel"; }
        { type = "uptime"; key = "uptime"; }
        { type = "packages"; key = "pkgs"; }
        { type = "wm"; key = "wm"; }
        { type = "terminal"; key = "term"; }
        { type = "shell"; key = "shell"; }
        { type = "memory"; key = "memory"; }
        "break"
        { type = "colors"; symbol = "circle"; }
      ];
    };
  };

  # --- Neovim config from ~/.dotfiles ---
  # Out-of-store symlink so it stays writable: lazy.nvim rewrites
  # lazy-lock.json, which a read-only /nix/store copy would not allow.
  # vim (system package) runs with its defaults, no ~/.vimrc.
  xdg.configFile."nvim".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.dotfiles/.config/nvim";

  # mpv-mpris: playerctl (media keys in home/dwl/config.h) controls mpv too
  programs.mpv = {
    enable = true;
    scripts = [ pkgs.mpvScripts.mpris ];
  };

  # --- Default applications (xdg-open, file pickers, links from apps) ---
  # HM owns ~/.config/mimeapps.list; force, because apps (Telegram and the
  # like) rewrite it on their own, and a stale mimeapps.list.hm-bak would
  # otherwise stop the next activation.
  xdg.mimeApps = {
    enable = true;
    defaultApplications =
      let
        pdf = "org.pwmt.zathura-pdf-mupdf.desktop";
        image = "imv.desktop";
        video = "mpv.desktop";
        browser = "firefox.desktop";
        telegram = "org.telegram.desktop.desktop";
        types = apps: lib.genAttrs apps;
      in
      { "application/pdf" = pdf; }
      // types [ "image/png" "image/jpeg" "image/gif" "image/webp" "image/bmp" "image/tiff" "image/svg+xml" "image/avif" "image/heif" "image/jxl" ] (_: image)
      // types [ "video/mp4" "video/x-matroska" "video/webm" "video/quicktime" "video/x-msvideo" "video/mpeg" "video/ogg" ] (_: video)
      // types [ "text/html" "x-scheme-handler/http" "x-scheme-handler/https" ] (_: browser)
      // types [ "x-scheme-handler/tg" "x-scheme-handler/tonsite" "x-scheme-handler/ton" ] (_: telegram)
      // {
        "x-scheme-handler/discord" = "vesktop.desktop";
        "x-scheme-handler/claude-cli" = "claude-code-url-handler.desktop";
      };
  };
  xdg.configFile."mimeapps.list".force = true;

  # --- CLI / TUI & Dev Tools ---
  home.packages = with pkgs; [
    ripgrep
    duf
    dust
    jq
    tree
    git-lfs
    glab
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
    nixd # Nix LSP: options and packages of this flake
    nixfmt
    ruff # Python: formatter, import sorting and linter (LSP: `ruff server`)
    stylua
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

    # --- GUI: work / study ---
    firefox
    vesktop # Wayland-native Discord client, replaces discord + telegram combo bloat
    telegram-desktop
    obsidian
    keepassxc
    zathura
    syncthing
    spotify
    imv # images; mpv is programs.mpv above

    # --- Gaming: user-level helpers (system-wide bits live in configuration.nix) ---
    protontricks
    mangohud
    (prismlauncher.override {
      jdks = [ jdk25 jdk21 jdk17 jdk8 ];
    })
  ];

  xdg.enable = true;

  # --- Dotfiles ---
  # Home Manager generates and owns the configs of the programs enabled here,
  # in home/desktop/common.nix and in home/dwl/default.nix: zsh (.zshrc),
  # git, delta, fzf, zoxide, starship, bat, lsd, htop, yazi, fastfetch, mpv,
  # mimeapps.list, mako, ghostty, swaylock, swayidle and fuzzel. dwl has no
  # config file, its config.h is compiled in. Only nvim comes from
  # ~/.dotfiles, as an mkOutOfStoreSymlink link (see above), so it stays
  # editable in place.
}
