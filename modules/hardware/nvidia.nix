{ config, ... }:

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
    open = true; # open kernel modules (Turing and newer)
    package = config.boot.kernelPackages.nvidiaPackages.stable;

    powerManagement.enable = true;
    powerManagement.finegrained = true; # dynamic power-gating while idle, important on a laptop
    nvidiaSettings = true;

    prime = {
      offload = {
        enable = true;
        enableOffloadCmd = true; # provides `nvidia-offload <command>`
      };
      # Bus IDs from `lspci` (hex there, decimal here):
      #   00:02.0 VGA ... Intel Iris Xe Graphics            -> PCI:0:2:0
      #   01:00.0 VGA ... NVIDIA GeForce RTX 4060 Max-Q/Mobile -> PCI:1:0:0
      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:1:0:0";
    };
  };
}
