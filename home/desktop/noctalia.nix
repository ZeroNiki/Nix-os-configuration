{ config, lib, pkgs, ... }:

let
  theme = import ../theme/everforest.nix;
in
{
  # NOTE: Noctalia (the Quickshell-based shell currently used on top of Niri)
  # is not packaged in nixpkgs as of writing. To actually run it here:
  #   1. Add its repo (and quickshell's) as flake inputs.
  #   2. Package it with a small overlay/derivation.
  #   3. Replace the waybar block below with a systemd.user.service that
  #      execs the Noctalia shell binary instead.
  # Until that overlay exists, waybar is wired up below as a nixpkgs-native
  # stand-in bar so the session is never left without a panel. Because this
  # module only touches the bar/launcher/notifications layer (not niri.nix
  # or xdg.portal), swapping it out later -- or swapping compositors to DWL
  # -- does not require touching anything else.

  programs.waybar = {
    enable = true;
    systemd.enable = true;
    settings = {
      mainBar = {
        layer = "top";
        position = "top";
        height = 30;
        modules-left = [ "niri/workspaces" ];
        modules-center = [ "clock" ];
        modules-right = [ "pulseaudio" "network" "battery" "tray" ];
      };
    };
  };

  # --- Launcher ---
  # rofi and wofi both appear in the Arch package list (README.md flagged
  # the duplication); rofi is kept here as the single launcher.
  programs.rofi = {
    enable = true;
    settings.terminal = "${pkgs.ghostty}/bin/ghostty";
  };

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
  # `theme = noctalia`). Ghostty ships no Everforest Dark *Medium*, so the
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

  # --- Clipboard, screenshots, output management, OSD ---
  # Compositor-agnostic Wayland utilities (README.md section 4): these stay
  # unchanged across the future Niri -> DWL swap.
  services.cliphist.enable = true;

  home.packages = with pkgs; [
    grim
    slurp
    satty
    wl-clipboard
    kanshi
    brightnessctl
    swayosd
  ];
}
