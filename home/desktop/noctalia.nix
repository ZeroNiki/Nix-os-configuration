{ config, lib, pkgs, ... }:

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
    };
  };

  # --- Terminal ---
  # ghostty kept as the single terminal; kitty/tabby/termius dropped per
  # README.md section 3 (duplicated terminal/SSH-client functionality).
  programs.ghostty = {
    enable = true;
    enableZshIntegration = true;
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
