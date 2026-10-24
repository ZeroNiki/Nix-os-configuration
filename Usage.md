# Usage Guide: gigabyte-nixos Flake

Companion to `README.md` (hardware/package audit) — this document covers how to actually
install and live with the flake in `hosts/system/`, `modules/`, and `home/`.

Flake output name used throughout: **`gigabyte-nixos`** (see `flake.nix`).

---

## 0. Before you touch partitions — validate the config first (zero-risk)

Run these from the repo root. None of them write to disk or touch the bootloader; they only
evaluate Nix expressions and build artifacts into the local Nix store / `./result`.

```bash
# 1. Syntax + module evaluation check (follows all inputs, type-checks every option)
nix flake check

# 2. Build a bootable QEMU VM of the whole system into ./result
nix build '.#nixosConfigurations.gigabyte-nixos.config.system.build.vm' -o result

# 3. Boot it (needs KVM; the script name below matches the hostName in configuration.nix)
./result/bin/run-gigabyte-nixos-vm
```

> If you have `nixos-rebuild` available (e.g. running this from inside an existing NixOS
> install or a NixOS live ISO), the equivalent one-liner is:
> `nixos-rebuild build-vm --flake .#gigabyte-nixos`
> On a plain Arch host — as during this migration — `nixos-rebuild` doesn't exist yet, so step
> 2 above (`nix build .../config.system.build.vm`) is the direct equivalent and produces the
> exact same `run-*-vm` script.

**What actually got verified in this repo, on this machine, before writing this file:**
- `nix flake check` — passes (`all checks passed!`), after fixing four things the current
  nixos-unstable/home-manager revision no longer accepts: `programs.git.userName/userEmail/
  extraConfig` (→ `programs.git.settings.*`), `programs.git.delta.enable` (→ separate
  `programs.delta`), `programs.rofi.terminal` (→ `programs.rofi.settings.terminal`),
  `pkgs.greetd.tuigreet` (→ `pkgs.tuigreet`), `pkgs.noto-fonts-emoji` (→
  `pkgs.noto-fonts-color-emoji`), and `pkgs.polkit-kde-agent` (→
  `pkgs.kdePackages.polkit-kde-agent-1`, Plasma 5 packages were dropped from nixpkgs).
  The files in this repo already have the fixes applied.
- `nix build '.#nixosConfigurations.gigabyte-nixos.config.system.build.vm' --dry-run` —
  evaluates cleanly and resolves the full package set (Steam, NVIDIA, fonts, all Home
  Manager packages included).
- The real (non-dry-run) build was kicked off in the background from this same session —
  check your terminal/task history for whether `./result/bin/run-gigabyte-nixos-vm` exists;
  if it doesn't yet, re-run step 2 above and let it finish (it fetches/builds a full desktop
  closure — Steam, fonts, NVIDIA userspace, etc. — so expect it to pull real bandwidth and
  take a while on the first run).

If `nix flake check` ever fails again after you edit something, the error trace nix prints
(`error: attribute 'X' missing` / `'Y' has been renamed to 'Z'`) is almost always a renamed
nixpkgs option or package on whatever nixpkgs revision `nix flake update` pulled in — fix the
name, don't fight the error.

---

## 1. Installation: Arch → NixOS

This assumes you're booted from a **NixOS installer ISO** (not the running Arch system —
partitioning the live disk requires unmounting it first, which Arch itself can't do to its own
root). Back up anything in `/home` you care about before this section; it is destructive.

### 1.1 Boot the NixOS installer and get this flake onto it

```bash
# From the NixOS live ISO, with network up (nmtui, or nmcli for wifi):
nmcli device wifi connect "<SSID>" password "<password>"

# Clone (or copy via USB) this repo onto the live system:
nix-shell -p git --run "git clone <your-repo-url> /tmp/nix-os"
cd /tmp/nix-os
```

### 1.2 Partition the disk

The existing layout (from `system-audit.txt`) is a single NVMe with an EFI partition and a
btrfs root — replicate that shape. Example for a **fresh** install (adjust `/dev/nvme0n1` if
different; double-check with `lsblk` first):

```bash
lsblk  # confirm the target disk, e.g. /dev/nvme0n1

# --- Option A: manual partitioning with gdisk ---
gdisk /dev/nvme0n1
# n -> partition 1 -> default start -> +1G -> type EF00 (EFI System)
# n -> partition 2 -> default start -> default end (rest of disk) -> type 8300 (Linux)
# w -> write and confirm

mkfs.fat -F32 -n EFI /dev/nvme0n1p1
mkfs.btrfs -L nixos /dev/nvme0n1p2

# Recommended: carve subvolumes now (README.md flagged the old Arch install
# as a flat single-subvolume btrfs — fix that here while you can)
mount /dev/nvme0n1p2 /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@nix
btrfs subvolume create /mnt/@snapshots
umount /mnt

mount -o subvol=@,compress=zstd,discard=async,ssd /dev/nvme0n1p2 /mnt
mkdir -p /mnt/{boot/efi,home,nix,.snapshots}
mount -o subvol=@home,compress=zstd,discard=async,ssd /dev/nvme0n1p2 /mnt/home
mount -o subvol=@nix,compress=zstd,discard=async,ssd,noatime /dev/nvme0n1p2 /mnt/nix
mount -o subvol=@snapshots,compress=zstd /dev/nvme0n1p2 /mnt/.snapshots
mount /dev/nvme0n1p1 /mnt/boot/efi
```

```bash
# --- Option B: declarative partitioning with disko instead of the manual steps above ---
# Write hosts/system/disko.nix (see README.md section 5 for where it slots into the repo),
# describing the same @ / @home / @nix / @snapshots layout, then:
nix --extra-experimental-features "nix-command flakes" run github:nix-community/disko -- \
  --mode destroy,format,mount ./hosts/system/disko.nix
```

### 1.3 Generate hardware info and reconcile it with the repo

```bash
nixos-generate-config --root /mnt
```

This writes a fresh `/mnt/etc/nixos/hardware-configuration.nix`. **Diff it against
`hosts/system/hardware-configuration.nix` in this repo** — the filesystem UUIDs will differ
from the placeholder values (those were lifted from the old Arch install's `fstab`/`lsblk`
output in `system-audit.txt`), and if you repartitioned with subvolumes per step 1.2 the
`fileSystems` block needs `subvol=@`, `subvol=@home`, `subvol=@nix` entries instead of the
single `subvol=/`. Copy the corrected `fileSystems`/`boot.initrd.availableKernelModules`
block back into this repo's file, keeping the NVIDIA PRIME / graphics stanzas that
`nixos-generate-config` does **not** know how to write.

### 1.4 Put this flake where the installer expects it

```bash
mkdir -p /mnt/etc/nixos
cp -r /tmp/nix-os/* /mnt/etc/nixos/
# (the hardware-configuration.nix you reconciled in 1.3 should already be the one
#  sitting in /tmp/nix-os/hosts/system/ before you copy — edit it there, not after)
```

### 1.5 Install

```bash
nixos-install --flake /mnt/etc/nixos#gigabyte-nixos
```

`nixos-install` will prompt for the root password. The flake deliberately does **not** set a
password for your user account (nothing plaintext committed to the repo) — set one before you
reboot, from the installer shell:

```bash
nixos-enter --root /mnt -c 'passwd nellaror'
```

Once that's done:

```bash
reboot
```

Remove the installer USB when prompted. First boot lands on **greetd + tuigreet**
(`modules/desktop/niri.nix`) → log in → Niri starts automatically via the greeter's
`niri-session` command.

---

## 2. Post-Install Workflow

Once installed, `/etc/nixos` should **be** this git repo (or a symlink to wherever you keep it
checked out, e.g. `~/nix-os`) — treat it as the single source of truth and commit changes to
it like any other code.

### 2.1 Daily commands

```bash
# Evaluate + build the new system closure WITHOUT activating it.
# Use this to catch errors before touching your running system.
nixos-rebuild build --flake .

# Build AND switch to the new generation immediately (persists across reboot:
# adds a new bootloader entry). This is the normal "apply my changes" command.
sudo nixos-rebuild switch --flake .

# Activate the new generation for THIS boot only, without adding a bootloader
# entry — reboot and you're back on the previous generation. Use this to try
# something risky (e.g. an NVIDIA driver bump, a new compositor module)
# before committing to it with `switch`.
sudo nixos-rebuild test --flake .

# Pull newer nixpkgs/home-manager revisions and update flake.lock.
# Always follow this with `nixos-rebuild build --flake .` first to see what
# broke before switching — unstable moves fast (see the renamed-option list
# in section 0 above for the kind of breakage to expect).
nix flake update

# Reclaim disk space: drop old generations, then garbage-collect the store.
nix-env --delete-generations old
nix-store --gc
```

### 2.2 Rollback

If a `switch` leaves you with a broken graphical session, reboot and pick the previous
generation from the **systemd-boot** menu — every `switch` adds one, nothing is overwritten.
From a working system you can also roll back without rebooting into the menu:

```bash
sudo nixos-rebuild switch --rollback
```

### 2.3 Common day-to-day edits and where they live

| You want to... | Edit this file |
|---|---|
| Add/remove a CLI or GUI package | `home/home.nix` (`home.packages`) |
| Change NVIDIA PRIME mode (offload ↔ sync) | `hosts/system/hardware-configuration.nix` (`hardware.nvidia.prime`) |
| Enable/disable a system service (docker, libvirt, bluetooth...) | `hosts/system/configuration.nix` |
| Swap bar/launcher/notifications (e.g. wire up a real Noctalia package) | `home/desktop/noctalia.nix` |
| Swap compositor Niri → DWL | `modules/desktop/niri.nix` → new `modules/desktop/dwl.nix`, then flip the import in `flake.nix`'s module list. `xdg.portal.wlr.enable` is already on, so the portal layer needs no change. |

After any edit: `nixos-rebuild build --flake .` to check it compiles, then `sudo nixos-rebuild
switch --flake .` to apply. Commit the working `flake.lock` alongside config changes so the
history always maps a config version to the exact package set it was tested against.
