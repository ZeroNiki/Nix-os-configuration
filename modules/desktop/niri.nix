{ config, lib, pkgs, ... }:

{
  # --- Niri: scrollable-tiling Wayland compositor (current primary compositor) ---
  # If this option is missing on your pinned nixpkgs revision, pull niri from
  # its own flake (github:YaLTeR/niri) instead and swap this line for the
  # overlay/home-manager module it ships.
  programs.niri.enable = true;

  # --- Greeter: greetd + tuigreet ---
  # Chosen over sddm (README.md section 2: pick one display manager) because
  # it is a single small binary with a TTY-like UI, which also matches the
  # DWL/suckless direction better than a Qt-based greeter.
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --cmd niri-session";
        user = "greeter";
      };
    };
  };

  # --- Polkit authentication agent ---
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

  # --- XDG Desktop Portals ---
  # wlr.enable is turned on now even though Niri mostly relies on the gnome
  # portal today: it is the portal backend DWL will need, so enabling it
  # early keeps the eventual Niri -> DWL swap to modules/desktop only.
  xdg.portal = {
    enable = true;
    wlr.enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gnome ];
    config.common.default = [ "gnome" ];
  };

  # --- Wayland session environment ---
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1"; # Electron/Chromium apps (discord, obsidian, ...) use native Wayland
    MOZ_ENABLE_WAYLAND = "1"; # Firefox
  };

  # --- NVIDIA VRAM heap-reuse workaround for niri specifically ---
  # Per niri's own wiki (Nvidia.md): the proprietary/open driver doesn't
  # release freed Wayland-compositor buffers back into the pool, so niri can
  # creep towards ~1 GiB of VRAM in use instead of the expected ~100 MiB. This
  # per-process application profile is NVIDIA's documented fix, scoped to the
  # `niri` process only -- it does not change which GPU renders anything, so
  # it's safe under PRIME offload too.
  environment.etc."nvidia/nvidia-application-profiles-rc.d/50-niri-limit-free-buffer-pool.json".text = builtins.toJSON {
    rules = [
      {
        pattern.feature = "procname";
        pattern.matches = "niri";
        profile = "Limit Free Buffer Pool On Wayland Compositors";
      }
    ];
    profiles = [
      {
        name = "Limit Free Buffer Pool On Wayland Compositors";
        settings = [
          {
            key = "GLVidHeapReuseRatio";
            value = 0;
          }
        ];
      }
    ];
  };

  environment.systemPackages = with pkgs; [
    niri
    xwayland-satellite # Xwayland-on-demand, matches the Arch package of the same name
  ];
}
