{ lib, pkgs, ... }:

{
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
        "x-scheme-handler/spotify" = "spotify.desktop";
        "x-scheme-handler/claude-cli" = "claude-code-url-handler.desktop";
      };
  };
  xdg.configFile."mimeapps.list".force = true;

  home.packages = with pkgs; [
    # --- GUI: work / study ---
    # firefox: programs.firefox in home/firefox/default.nix
    vesktop # Wayland-native Discord client
    telegram-desktop
    obsidian
    keepassxc
    zathura
    syncthing
    imv # images; mpv is programs.mpv above
    # official CEF client: librespot (spotify-player, ncspot) gets no audio
    # keys on this account, see librespot-org/librespot#1649
    spotify

    # --- TUI ---
    bluetui # Bluetooth, also opened by the bar's Bluetooth block

    # --- Gaming: user-level helpers (system-wide bits live in configuration.nix) ---
    protontricks
    mangohud
    (prismlauncher.override {
      jdks = [ jdk25 jdk21 jdk17 jdk8 ];
    })
  ];
}
