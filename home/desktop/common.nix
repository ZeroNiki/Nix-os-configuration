{ config, lib, pkgs, ... }:

let
  theme = import ../theme/everforest.nix;
in
{
  # Desktop bits that don't depend on the compositor: notifications, the
  # terminal, Wayland utilities. dwl itself lives in home/dwl/default.nix.

  # --- Notifications ---
  services.mako = {
    enable = true;
    settings = {
      default-timeout = 5000;
      font = "JetBrainsMono Nerd Font 11";
      background-color = "#${theme.bg0}";
      text-color = "#${theme.fg}";
      border-color = "#${theme.green}";
      progress-color = "over #${theme.bg2}";
      "urgency=critical" = {
        border-color = "#${theme.red}";
      };
    };
  };

  # --- Terminal ---
  # ghostty kept as the single terminal; kitty/tabby/termius dropped per
  # README.md section 3 (duplicated terminal/SSH-client functionality).
  # Settings carried over from ~/.dotfiles/.config/ghostty/config (minus its
  # `theme` line). Ghostty ships no Everforest Dark *Medium*, so the
  # built-in Dark Hard is used with its background swapped for bg0.
  programs.ghostty = {
    enable = true;
    enableZshIntegration = true;
    settings = {
      theme = "Everforest Dark Hard";
      background = "#${theme.bg0}";

      font-family = "JetBrainsMono Nerd Font";
      font-size = 18;
      font-style = "Regular";
      background-opacity = 0.8;

      window-padding-x = 12;
      window-padding-y = 12;
      window-decoration = true;
      confirm-close-surface = false;

      cursor-style = "block";
      cursor-style-blink = true;
      mouse-hide-while-typing = true;
      scrollback-limit = 10000;

      shell-integration = "detect";
      shell-integration-features = "cursor,sudo,title";

      # vim-style split navigation
      keybind = [
        "alt+h=goto_split:left"
        "alt+j=goto_split:down"
        "alt+k=goto_split:up"
        "alt+l=goto_split:right"
      ];
    };
  };

  # --- Clipboard, screenshots, brightness ---
  # Wayland utilities called from home/dwl/config.h (README.md section 4).
  # The clipboard history is fed by `wl-paste --watch cliphist store` in
  # dwl-startup (home/dwl/default.nix); cliphist here is for `cliphist list`.
  home.packages = with pkgs; [
    grim
    slurp
    wl-clipboard
    cliphist
    brightnessctl
  ];
}
