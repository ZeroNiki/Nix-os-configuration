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

  # dwl-session exports XDG_CURRENT_DESKTOP=dwl, which selects config.dwl:
  # wlr for screenshots/screencast, gtk for file pickers.
  portalConfig = {
    default = [ "gtk" ];
    "org.freedesktop.impl.portal.Screenshot" = [ "wlr" ];
    "org.freedesktop.impl.portal.ScreenCast" = [ "wlr" ];
  };
in
{
  # --- DWL: system-level bits only ---
  # The compositor itself, its bar and startup scripts are user packages
  # (home/dwl/default.nix); start it with `dwl-session` from a tty, or pick
  # "dwl" in tuigreet.
  services.displayManager.sessionPackages = [ dwlDesktopSession ];

  # --- Greeter: greetd + tuigreet ---
  # Chosen over sddm (README.md section 2: pick one display manager) because
  # it is a single small binary with a TTY-like UI, which also matches the
  # DWL/suckless direction better than a Qt-based greeter.
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        # --sessions lists every registered session (dwl from above) under
        # F3; --remember-session keeps the last pick, dwl-session (same path
        # as in dwlDesktopSession) is the default when nothing was picked yet.
        # --theme takes only ANSI color names (the greeter runs on a 16-color
        # VT), picked to sit close to the Everforest accents used in DWL.
        command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --remember-session --sessions ${config.services.displayManager.sessionData.desktops}/share/wayland-sessions --theme 'border=green;title=green;prompt=green;input=white;text=white;time=gray;action=darkgray;button=yellow' --cmd /etc/profiles/per-user/${username}/bin/dwl-session";
        user = "greeter";
      };
    };
  };

  # --- Polkit authentication agent ---
  # Started with graphical-session.target, which dwl-startup brings up
  # through dwl-session.target (both in home/dwl/default.nix).
  security.polkit.enable = true;
  systemd.user.services.polkit-agent = {
    description = "Polkit authentication agent";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.kdePackages.polkit-kde-agent-1}/libexec/polkit-kde-authentication-agent-1";
      Restart = "on-failure";
      RestartSec = 1;
      TimeoutStopSec = 10;
    };
  };

  # --- Secrets and GTK settings ---
  # Set explicitly, they used to be implicit defaults of the old compositor
  # module. gnome-keyring is the Secret Service for vesktop/obsidian/
  # telegram/firefox, unlocked at login through PAM, and brings
  # gcr-ssh-agent along; dconf is the GSettings backend GTK apps need to
  # keep their settings (GIO_EXTRA_MODULES).
  services.gnome.gnome-keyring.enable = true;
  programs.dconf.enable = true;

  # swaylock (Mod+Shift+l, set up in home/dwl/default.nix) checks the
  # password through PAM and can't unlock without its own service entry.
  security.pam.services.swaylock = { };

  # --- XDG Desktop Portals ---
  # config.common is the same as config.dwl: the fallback for apps started
  # without XDG_CURRENT_DESKTOP=dwl in their environment.
  xdg.portal = {
    enable = true;
    wlr.enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config.dwl = portalConfig;
    config.common = portalConfig;
  };

  # --- Wayland session environment ---
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1"; # Electron/Chromium apps (discord, obsidian, ...) use native Wayland
    MOZ_ENABLE_WAYLAND = "1"; # Firefox
  };
}
