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

  # The services below are WantedBy graphical-session.target, which
  # dwl-session.target (home/dwl/default.nix) pulls in at login.

  # --- Clipboard history ---
  # wl-paste in watch mode feeding cliphist, as a user service (plus one
  # for images); also puts cliphist itself in PATH for `cliphist list`.
  services.cliphist.enable = true;

  # --- Wallpaper ---
  # A random picture from ~/Pictures/Wallpapers, a new one every 5 minutes,
  # picked separately for each monitor, including ones plugged in later.
  # "center" zooms the picture to cover the screen and crops what sticks out,
  # without stretching. wpaperd doesn't fail without pictures: with an empty
  # directory it warns and watches it for new files; if the directory is
  # missing it logs an error and runs with no wallpaper (dwl's rootcolor
  # shows through) until `systemctl --user restart wpaperd`.
  services.wpaperd = {
    enable = true;
    settings.any = {
      path = "${config.home.homeDirectory}/Pictures/Wallpapers";
      duration = "2m";
      sorting = "random";
      mode = "center";
    };
  };

  # --- Monitors ---
  # dwl alone already places a new monitor (monrules in home/dwl/config.h);
  # kanshi puts the external one to the right of the laptop at its preferred
  # (native) mode, 1440p at scale 1.25, i.e. 2048x1152 logical pixels.
  # "*" is any other output, whatever connector it is on (see `wlr-randr`).
  # dwlb puts a bar on a new output by itself, but its status text only
  # arrives with dwl-status's next line, so each profile asks for it at once.
  services.kanshi = {
    enable = true;
    settings = [
      {
        profile.name = "laptop";
        profile.exec = "dwl-status refresh";
        profile.outputs = [
          {
            criteria = "eDP-1";
            status = "enable";
            position = "0,0";
          }
        ];
      }
      {
        profile.name = "external";
        profile.exec = "dwl-status refresh";
        profile.outputs = [
          {
            criteria = "eDP-1";
            status = "enable";
            position = "0,0";
          }
          {
            criteria = "*";
            status = "enable";
            position = "1920,0";
            scale = 1.25;
          }
        ];
      }
    ];
  };

  # --- Screenshots, brightness, outputs ---
  # Wayland utilities called from home/dwl/config.h (README.md section 4);
  # wlr-randr lists the outputs (names, modes, scale) for the kanshi profiles.
  home.packages = with pkgs; [
    grim
    slurp
    wl-clipboard
    brightnessctl
    wlr-randr
  ];
}
