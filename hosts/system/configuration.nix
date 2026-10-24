{ config, lib, pkgs, username, ... }:

{
  # --- Bootloader ---
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  # Must match wherever the ESP is actually mounted (hardware-configuration.nix
  # mounts it at /boot/efi, not the NixOS default of /boot) — without this,
  # bootctl looks for a FAT filesystem at /boot, finds the btrfs root instead,
  # and nixos-install fails installing the bootloader.
  boot.loader.efi.efiSysMountPoint = "/boot/efi";
  boot.loader.systemd-boot.configurationLimit = 10; # ESP is 1 GiB; cap how many generations' kernels/initrds get copied onto it
  boot.kernelPackages = pkgs.linuxPackages_zen;

  nixpkgs.config.allowUnfree = true; # required for the NVIDIA driver

  nix.settings.experimental-features = [ "nix-command" "flakes" ]; # otherwise `nix flake update`/`nix flake check` don't work post-install

  # --- Hostname & networking ---
  networking.hostName = "gigabyte-nixos";
  networking.networkmanager.enable = true;
  networking.networkmanager.wifi.powersave = true;
  # Realtek r8169 + Intel iwlwifi are picked up automatically by the kernel,
  # no extra config needed.

  # --- Locale / Time ---
  time.timeZone = "Asia/Tashkent";
  i18n.defaultLocale = "en_US.UTF-8";

  # --- Swap: zram instead of a disk partition (see Usage.md 1.2, Option A) ---
  zramSwap.enable = true;

  # --- Audio: PipeWire (replaces pipewire/pipewire-pulse/pipewire-jack/wireplumber from Arch) ---
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
    wireplumber.enable = true;
  };

  # --- Bluetooth ---
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;
  services.blueman.enable = true;

  # --- Shell ---
  programs.zsh.enable = true;
  users.defaultUserShell = pkgs.zsh;

  # --- Containers / virtualisation ---
  virtualisation.docker.enable = true;
  # podman is intentionally NOT enabled alongside docker to avoid the
  # duplicated-hypervisor/duplicated-runtime problem flagged in README.md
  # section 3. Swap this block for virtualisation.podman if you prefer a
  # daemonless rootless runtime instead.

  virtualisation.libvirtd.enable = true;
  programs.virt-manager.enable = true;
  # VirtualBox is deliberately dropped — libvirt/qemu covers the same need
  # without running two hypervisors in parallel (see README.md section 3).

  # --- Gaming ---
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = false;
  };
  programs.gamemode.enable = true;
  programs.gamescope.enable = true;

  # --- Fonts ---
  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
    nerd-fonts.jetbrains-mono
  ];

  # --- Security ---
  security.polkit.enable = true;

  # --- User ---
  # No password is set here on purpose (don't commit one in plaintext).
  # Before first boot, either set `users.users.${username}.initialPassword`
  # for a throwaway one to change on first login, or run `passwd` from the
  # NixOS installer's chroot (`nixos-enter --root /mnt`) right after
  # `nixos-install` — see Usage.md section 1.5.
  users.users.${username} = {
    isNormalUser = true;
    description = "Nella";
    extraGroups = [ "wheel" "networkmanager" "docker" "libvirtd" "video" "input" ];
    shell = pkgs.zsh;
  };

  # --- Minimal system packages (everything user-facing lives in Home Manager) ---
  environment.systemPackages = with pkgs; [
    git
    vim
  ];

  # --- CPU microcode ---
  hardware.cpu.intel.updateMicrocode = true;

  # --- Printing stays off by default; flip to true if you ever need CUPS ---
  services.printing.enable = false;

  # --- Test-VM resource sizing (only applies to `nixos-rebuild build-vm` /
  # `nix build .config.system.build.vm`; the real install ignores this block
  # entirely). Needed because the generated run-*-vm script hardcodes a
  # `-object memory-backend-memfd,...,size=<memorySize>M` tied to `-m`, so
  # bumping RAM via a bare `QEMU_OPTS="-m 8192"` at run time conflicts with
  # that backend and QEMU refuses to start ("Machine memory size does not
  # match the size of the memory backend"). Setting it here instead makes
  # nixpkgs generate a consistent pair.
  virtualisation.vmVariant = {
    virtualisation.memorySize = 8192; # MB
    virtualisation.cores = 4;
    # No VGA device: this VM is verified over the serial console
    # (QEMU_OPTS="-nographic"), not a graphical window. A real Niri session
    # needs GPU/GBM-accelerated video (virtio-vga-gl + `-display ...,gl=on`)
    # which turned out not to work from this particular host's GL stack —
    # see the chat history / Usage.md for that dead end. None of this
    # affects the real install: Niri runs against the laptop's actual Intel
    # iGPU there, not a virtio-gpu passthrough.
    virtualisation.qemu.options = [ "-vga" "none" ];

    # Throwaway login for THIS TEST VM ONLY — the real `configuration.nix`
    # (outside vmVariant) never sets a password, so nothing plaintext ends
    # up in the config used for the actual install. Log in as
    # `${username}` / `nixos`.
    users.users.${username}.password = "nixos";

    # KVM is used automatically when available (default accel=kvm:tcg);
    # no extra flag needed, and forcing -enable-kvm would make the VM fail
    # outright instead of falling back to software emulation on hosts/CI
    # where KVM isn't usable.
  };

  # NOTE: bump this only when you deliberately opt in to a new NixOS release;
  # it controls on-disk state format, not package versions.
  system.stateVersion = "24.11";
}
