{ config, lib, pkgs, ... }:

let
  theme = import ../theme/everforest.nix;
in
{
  # Desktop bits that don't depend on the compositor: notifications, the
  # terminal, Wayland utilities. dwl itself lives in home/dwl/default.nix.

  # --- Notifications ---
  # Mod+n closes the newest one, Mod+Shift+n toggles do-not-disturb (bar
  # shows 󰂛 meanwhile): everything is hidden except critical notifications.
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
      # sections are sorted by name, the second one comes later and wins
      "mode=do-not-disturb".invisible = 1;
      "mode=do-not-disturb urgency=critical".invisible = 0;
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
      # ssh-env/ssh-terminfo: TERM stays xterm-ghostty (home/home.nix no
      # longer forces xterm-256color), ssh installs its terminfo on the host
      # or falls back to xterm-256color there
      shell-integration-features = "cursor,sudo,title,ssh-env,ssh-terminfo";

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
  # kanshi puts the external one to the right of the laptop at scale 1.
  # "desk" is the HCS PXG27QV2 (matched by its description, so any connector)
  # at 144 Hz instead of its preferred 60; it must come before "external",
  # since kanshi takes the first matching profile and "*" matches anything.
  # Modes are in mHz as wlr-randr shows them: kanshi picks the closest mode
  # within 0.05 Hz, so 144.002 can only be 144.001999, never 120 or 60.
  # No adaptiveSync: HDMI-A-2 on the NVIDIA reports vrr_capable = 0, and
  # wlroots would then reject the whole profile (README.md in home/dwl).
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
        profile.name = "desk";
        profile.exec = "dwl-status refresh";
        profile.outputs = [
          {
            criteria = "eDP-1";
            status = "enable";
            mode = "1920x1200@165.015Hz";
            position = "0,0";
            scale = 1.0;
          }
          {
            criteria = "HCS PXG27QV2 0x00000001";
            status = "enable";
            mode = "2560x1440@144.002Hz";
            position = "1920,0";
            scale = 1.0;
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
            scale = 1.0;
          }
        ];
      }
    ];
  };

  # --- Night light ---
  # Warmer screen from sunset to sunrise, computed for Tashkent
  # (time.timeZone in configuration.nix), fading over the twilight.
  services.wlsunset = {
    enable = true;
    latitude = 41.3;
    longitude = 69.3;
    temperature.night = 4000;
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
