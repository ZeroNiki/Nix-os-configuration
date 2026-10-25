{ config, lib, pkgs, ... }:

{
  # --- Graphics stack: Intel Iris Xe (i915/xe) + NVIDIA RTX 4060 (PRIME offload) ---
  # Lives in its own module (not hardware-configuration.nix) on purpose: that
  # file is nominally overwritten by `nixos-generate-config` during install,
  # and this block has nothing to do with hardware detection — it's a design
  # choice (offload vs. sync, which driver), not something a generator could
  # know to write.
  hardware.graphics = {
    enable = true;
    enable32Bit = true; # needed for Steam/Proton
  };

  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable = true;
    open = true; # equivalent of nvidia-open-dkms on Arch
    package = config.boot.kernelPackages.nvidiaPackages.stable;

    powerManagement.enable = true;
    powerManagement.finegrained = true; # dynamic power-gating while idle, important on a laptop
    nvidiaSettings = true;

    prime = {
      offload = {
        enable = true;
        enableOffloadCmd = true; # provides `nvidia-offload <command>`
      };
      # Bus IDs derived from `lspci` (confirmed hardware, see system-audit.txt):
      #   00:02.0 VGA ... Intel Iris Xe Graphics            -> PCI:0:2:0
      #   01:00.0 VGA ... NVIDIA GeForce RTX 4060 Max-Q/Mobile -> PCI:1:0:0
      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:1:0:0";
    };
  };

  # --- Emergency fallback: Intel-only boot entry ---
  # Picked from the systemd-boot menu (or `sudo nixos-rebuild switch --specialisation
  # intel-only` once booted) if NVIDIA + Wayland gives a black screen / failed
  # session on first boot and there's no earlier generation to roll back to
  # yet. Boots with the nvidia kernel modules blacklisted entirely, so the
  # session runs on the Intel iGPU only via the "modesetting" X driver (which
  # DWL/wlroots also uses as its DRM backend on Wayland) — no PRIME, no
  # offload, nothing nvidia-shaped left to fail.
  specialisation.intel-only.configuration = {
    system.nixos.tags = [ "intel-only" ];
    services.xserver.videoDrivers = lib.mkForce [ "modesetting" ];
    hardware.nvidia.prime.offload.enable = lib.mkForce false;
    hardware.nvidia.prime.offload.enableOffloadCmd = lib.mkForce false;
    hardware.nvidia.powerManagement.finegrained = lib.mkForce false;
    boot.blacklistedKernelModules = [ "nvidia" "nvidia_drm" "nvidia_modeset" "nvidia_uvm" "nouveau" ];
  };
}
