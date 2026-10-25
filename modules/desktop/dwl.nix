{ config, lib, pkgs, username, ... }:

let
  # Login-screen entry for tuigreet (F3 there picks the session). dwl itself
  # is a Home Manager package, so point at the per-user profile.
  dwlDesktopSession = (pkgs.writeTextDir "share/wayland-sessions/dwl.desktop" ''
    [Desktop Entry]
    Name=dwl
    Comment=dwl Wayland compositor
    Exec=/etc/profiles/per-user/${username}/bin/dwl-session
    Type=Application
  '').overrideAttrs (old: {
    passthru = (old.passthru or { }) // { providedSessions = [ "dwl" ]; };
  });
in
{
  # --- DWL: system-level bits only ---
  # The compositor itself, its bar and startup scripts are user packages
  # (home/dwl/default.nix); start it with `dwl-session` from a tty, or pick
  # "dwl" in tuigreet.
  services.displayManager.sessionPackages = [ dwlDesktopSession ];

  # swaylock (Mod+Shift+l, set up in home/dwl/default.nix) checks the
  # password through PAM and can't unlock without its own service entry.
  security.pam.services.swaylock = { };

  # dwl-session exports XDG_CURRENT_DESKTOP=dwl, which selects this portal
  # config: wlr for screenshots/screencast (wlr.enable is already on in
  # niri.nix), gtk for file pickers. niri keeps using its own config.
  xdg.portal = {
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config.dwl = {
      default = [ "gtk" ];
      "org.freedesktop.impl.portal.Screenshot" = [ "wlr" ];
      "org.freedesktop.impl.portal.ScreenCast" = [ "wlr" ];
    };
  };
}
