{ config, lib, pkgs, username, font, ... }:

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
  # Hard-links identical files in /nix/store once a day (nix-optimise.timer)
  # instead of on every added path (auto-optimise-store): same result,
  # builds don't wait for it.
  nix.optimise.automatic = true;
  # Garbage-collect during a build when less than 5 GiB is free, until 20 GiB is.
  nix.settings.min-free = 5 * 1024 * 1024 * 1024;
  nix.settings.max-free = 20 * 1024 * 1024 * 1024;
  # Flakes only: no nix-channel. `nix-shell -p` and `nix shell nixpkgs#...`
  # still work, they get this flake's nixpkgs (lib.nixosSystem sets
  # nixpkgs.flake.source, which fills NIX_PATH and the registry).
  nix.channel.enable = false;

  # --- nh: nixos-rebuild with a build tree and a package diff, plus GC ---
  # `nh os switch` / `nh os build` / `nh os test` (NH_FLAKE points here, so no
  # --flake needed). nh-clean.timer (weekly) drops every generation older than
  # 7 days except the last 5 and collects the store; `nh clean all` by hand.
  programs.nh = {
    enable = true;
    flake = "/etc/nixos";
    clean.enable = true;
    clean.extraArgs = "--keep 5 --keep-since 7d";
  };

  # --- Hostname & networking ---
  networking.hostName = "gigabyte-nixos";
  networking.networkmanager.enable = true;
  networking.networkmanager.wifi.powersave = true;
  # Realtek r8169 + Intel iwlwifi are picked up automatically by the kernel,
  # no extra config needed.

  # --- Locale / Time ---
  time.timeZone = "Asia/Tashkent";
  i18n.defaultLocale = "en_US.UTF-8";
  # Russian man pages (MANOPT="-L ru_RU.UTF-8" in home/shell.nix) need it generated.
  i18n.extraLocales = [ "ru_RU.UTF-8/UTF-8" ];

  # TTY (and tuigreet on it): Terminus, the PSF build of the desktop's
  # monospace font (theme/font.nix). 24 px rows: 160x50 on the laptop.
  # earlySetup sets it already in the initrd, so boot messages use it too.
  console = {
    font = "ter-v24n";
    packages = [ pkgs.terminus_font ];
    earlySetup = true;
  };

  # Num Lock on in the virtual consoles, tuigreet's included. -D makes it
  # the VT's default, so it survives a console reset by greetd/getty.
  # dwl turns it on for its own keyboards (home/dwl/patches/numlock-local.patch).
  systemd.services.numlock-tty = {
    description = "Num Lock on in the virtual consoles";
    wantedBy = [ "multi-user.target" ];
    before = [ "greetd.service" "getty.target" ];
    serviceConfig.Type = "oneshot";
    script = ''
      for tty in /dev/tty{1..6}; do
        ${pkgs.kbd}/bin/setleds -D +num <"$tty"
      done
    '';
  };

  # --- Swap: zram instead of a disk partition ---
  zramSwap.enable = true;

  # --- /tmp in RAM (half of it at most) ---
  # Nix builds don't land here: the daemon builds in /nix/var/nix/builds
  # (the default build-dir since Nix 2.30), on disk.
  boot.tmp.useTmpfs = true;

  # --- btrfs: monthly scrub, hourly snapshots of /home ---
  # autoScrub covers every btrfs device once, not every subvolume mount.
  services.btrfs.autoScrub.enable = true;
  # /home (subvolume @home) is snapshotted into /.snapshots (@snapshots):
  # every snapshot for 2 days, then one a day for 14. The system itself is
  # rolled back through generations instead.
  services.btrbk.instances.home = {
    onCalendar = "hourly";
    settings = {
      timestamp_format = "long"; # home.YYYYMMDDThhmm, several a day
      snapshot_preserve_min = "2d";
      snapshot_preserve = "14d";
      volume."/" = {
        snapshot_dir = ".snapshots";
        subvolume = "home";
      };
    };
  };

  # --- Audio: PipeWire (ALSA, PulseAudio and JACK clients all go through it) ---
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
  # The adapter stays off after boot (battery); bluetui (home/apps.nix,
  # click on the Bluetooth block of the bar) turns it on.
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = false;

  # --- External monitor brightness over DDC/CI (ddcutil, `brightness` in home/dwl) ---
  # Loads i2c-dev and gives /dev/i2c-* to the "i2c" group (and the local seat).
  hardware.i2c.enable = true;

  # --- Shell ---
  programs.zsh.enable = true;
  users.defaultUserShell = pkgs.zsh;

  # --- Containers / virtualisation ---
  virtualisation.docker.enable = true;
  # dockerd isn't started at boot, docker.socket starts it on the first
  # `docker` call. Containers with --restart=always then come up only after
  # that first call, not at boot.
  virtualisation.docker.enableOnBoot = false;
  # podman is intentionally NOT enabled alongside docker to avoid running
  # two container runtimes. Swap this block for virtualisation.podman if you prefer a
  # daemonless rootless runtime instead.

  virtualisation.libvirtd.enable = true;
  programs.virt-manager.enable = true;
  # VirtualBox is deliberately dropped — libvirt/qemu covers the same need
  # without running two hypervisors in parallel. vagrant's nixpkgs package
  # ships the vagrant-libvirt plugin (package in home/dev.nix),
  # VAGRANT_DEFAULT_PROVIDER is set there too.

  # --- Gaming ---
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = false;
    extraCompatPackages = [ pkgs.proton-ge-bin ];
  };
  programs.gamemode.enable = true;
  programs.gamescope.enable = true;

  # --- Fonts ---
  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
    nerd-fonts.terminess-ttf # monospace, see theme/font.nix
    nerd-fonts.jetbrains-mono # previous monospace, kept for a quick rollback
  ];
  # what programs get when they ask for plain "monospace" (Firefox, GTK, ...);
  # sans-serif and serif stay at the defaults
  fonts.fontconfig.defaultFonts.monospace = [ font.mono ];

  # --- Security ---
  security.polkit.enable = true;

  # --- User ---
  # No password is set here on purpose (don't commit one in plaintext).
  # Before first boot, either set `users.users.${username}.initialPassword`
  # for a throwaway one to change on first login, or run `passwd` from the
  # NixOS installer's chroot (`nixos-enter --root /mnt`) right after
  # `nixos-install` — see Usage.md, "Переустановка".
  users.users.${username} = {
    isNormalUser = true;
    description = "Nella";
    extraGroups = [ "wheel" "networkmanager" "docker" "libvirtd" "video" "input" "i2c" ];
    shell = pkgs.zsh;
  };

  # --- Editor: neovim only ---
  # nano (NixOS default) is off, vim and vi are nvim; the config comes from
  # ~/.dotfiles (home/dev.nix).
  programs.nano.enable = false;
  programs.neovim = {
    enable = true;
    defaultEditor = true; # EDITOR=nvim
    viAlias = true;
    vimAlias = true;
  };

  # --- Minimal system packages (everything user-facing lives in Home Manager) ---
  environment.systemPackages = [ pkgs.git ];

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
    # (QEMU_OPTS="-nographic"), not a graphical window. A real dwl session
    # needs GPU/GBM-accelerated video (virtio-vga-gl + `-display ...,gl=on`),
    # which didn't work from this host's GL stack. None of this affects the
    # real install: dwl runs on the laptop's Intel iGPU there.
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
