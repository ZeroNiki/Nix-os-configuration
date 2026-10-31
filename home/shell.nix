{ config, pkgs, ... }:

let
  omz = "${pkgs.oh-my-zsh}/share/oh-my-zsh";
in
{
  # --- Shell ---
  # Ported from ~/.dotfiles/.zshrc, which is not linked: Home Manager owns
  # ~/.zshrc. Arch-only bits (fzf sourcing from /usr/share, zoxide init,
  # spicetify PATH) are dropped -- programs.fzf/zoxide do the first two.
  # oh-my-zsh is not loaded, only its git aliases stay (sourced from the
  # package in initContent).
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    # keep ~/.zshrc where it has always been (and silence the dotDir warning)
    dotDir = config.home.homeDirectory;

    # TERM is left to the terminal (xterm-ghostty): forcing xterm-256color
    # turned off undercurl, the kitty keyboard protocol and more in nvim.
    # Over ssh ghostty copies its terminfo to the host or falls back to
    # xterm-256color by itself (ssh-terminfo/ssh-env in home/desktop/common.nix).
    sessionVariables = {
      MANPAGER = "less -R";
      MANOPT = "-L ru_RU.UTF-8";
    };

    shellAliases = {
      v = "nvim";
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

    initContent = ''
      # oh-my-zsh's git aliases (gst, ga, gc, gp, gcl, ...) without
      # oh-my-zsh; lib/git.zsh has git_current_branch, some of them call it.
      # Its precmd hook removes itself with add-zsh-hook, which oh-my-zsh
      # used to autoload (now only zsh-autosuggestions does, by chance).
      autoload -Uz add-zsh-hook
      source ${omz}/lib/git.zsh
      source ${omz}/plugins/git/git.plugin.zsh

      # what the copyfile plugin did: a file's contents to the clipboard
      copyfile() { wl-copy <"''${1:?usage: copyfile FILE}"; }
    '';
  };

  # Pure-style prompt, the same layout ~/.p10k.zsh had: directory and git on
  # the first line, command time / virtualenv / user@host (ssh and root only)
  # on its right, then the prompt character alone on the second line.
  # ANSI colors, so ghostty's Everforest paints them.
  programs.starship = {
    enable = true;
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

  # --- CLI / TUI utilities ---
  # file search is fd (dev.nix), there is no locate database
  home.packages = with pkgs; [
    ripgrep
    duf
    dust
    jq
    tree
    glow
    rsync
    wget
    socat
    sshpass
    strace
    smartmontools
  ];
}
