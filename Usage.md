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
# From the NixOS live ISO, bring networking up first.

# --- Wi-Fi via NetworkManager (default on the graphical/minimal ISO) ---
nmcli device wifi connect "<SSID>" password "<password>"
# or interactively: nmtui

# --- Wi-Fi via iwd, IF that's what this particular boot image ships ---
# Not every NixOS ISO build includes iwd — check first:
if command -v iwctl >/dev/null 2>&1; then
  iwctl
  # inside the interactive iwctl prompt:
  #   device list                        # confirm the Wi-Fi device, e.g. wlan0
  #   station wlan0 scan
  #   station wlan0 get-networks
  #   station wlan0 connect "<SSID>"     # prompts for the password
  #   exit
else
  echo "iwctl not present on this ISO — use nmcli/nmtui above instead."
fi

# Either way, confirm you're actually online before continuing:
ping -c1 cache.nixos.org
```

### 1.1b Pull this flake from GitHub instead of a USB stick

This repo's `origin` is already set to a real GitHub remote
(`git@github.com:ZeroNiki/Nix-os-configuration.git`), so the installer ISO can clone it
directly over the network instead of you carrying it in on a USB stick. Worth doing — it's
the same "config lives in git, not on whatever machine happens to have it" idea the rest of
this repo already follows, and it means any future reinstall is just "clone + install" from
any machine, not "remember which USB stick has the current version."

```bash
# From your CURRENT machine (Arch), before rebooting into the installer —
# push whatever you have locally so the ISO can pull the real thing:
cd /home/nellaror/Documents/Training/nix-os
git add -A
git commit -m "..."        # only if there's something worth committing
git push origin main
```

```bash
# From the NixOS live ISO, once networking is up (1.1 above):

# --- If the GitHub repo is PUBLIC: plain HTTPS clone, no credentials needed ---
nix-shell -p git --run \
  "git clone https://github.com/ZeroNiki/Nix-os-configuration.git /tmp/nix-os"

# --- If the repo is PRIVATE: the live ISO has no SSH key or saved credentials
#     by default, so pick ONE of these first ---

#   (a) Fine-grained GitHub personal access token (simplest, no key copying):
nix-shell -p git --run \
  "git clone https://<token>@github.com/ZeroNiki/Nix-os-configuration.git /tmp/nix-os"

#   (b) An actual SSH key, copied onto the ISO (e.g. via the same USB stick,
#       or `scp` from another machine on the same network):
mkdir -p ~/.ssh && cp /path/to/copied/id_ed25519 ~/.ssh/ && chmod 600 ~/.ssh/id_ed25519
nix-shell -p git openssh --run \
  "eval \$(ssh-agent) && ssh-add ~/.ssh/id_ed25519 && \
   git clone git@github.com:ZeroNiki/Nix-os-configuration.git /tmp/nix-os"

cd /tmp/nix-os
```

> **Don't let this become a reason to commit secrets.** The GitHub flow only works cleanly
> because nothing sensitive lives in this repo's git history: no account password
> (`hosts/system/configuration.nix` deliberately leaves it unset — 1.5 below), no age/sops
> keys, and now (after the `.gitignore` update alongside this section) no stray
> `gigabyte-nixos.qcow2` test-VM disk image or `result`/`result-*` build symlinks either —
> those are real files that end up sitting in this directory after the Stage-0 VM testing
> above and have no business in version control. If you later add `sops-nix` for real
> secrets (API tokens, VPN configs), keep the **encrypted** `.sops.yaml`-managed files in the
> repo and the **decryption key** (`~/.config/sops/age/keys.txt`) off of it, copied onto each
> machine out-of-band instead.
>
> Not pushing to GitHub at all and copying the repo via USB stays a perfectly fine, slightly
> more manual alternative — pick whichever matches how many machines you're actually
> provisioning. For "just this one laptop," USB is simpler; for "this laptop today, maybe a
> desktop later," the GitHub flow pays for itself the second time.

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

```bash
# --- Option C: cfdisk — EFI + separate /home, NO swap partition ---
# Simpler than Option A: three plain partitions instead of one btrfs volume
# with subvolumes, and no swap partition at all (swap is handled by zram
# instead — see the note right after this block).
cfdisk /dev/nvme0n1
# cfdisk is a full-screen menu driven by arrow keys + Enter; nothing is
# written to the disk until you explicitly select [Write]. Create, in order:
#   1. [New] -> size ~1G           -> [Type] -> "EFI System"
#   2. [New] -> size e.g. 100G     -> [Type] -> "Linux filesystem"   (becomes /)
#   3. [New] -> remaining space    -> [Type] -> "Linux filesystem"   (becomes /home)
#   Then: [Write] -> type "yes" to confirm -> [Quit]

mkfs.fat -F32 -n EFI  /dev/nvme0n1p1
mkfs.ext4 -L nixos    /dev/nvme0n1p2
mkfs.ext4 -L home     /dev/nvme0n1p3

mount /dev/nvme0n1p2 /mnt
mkdir -p /mnt/{boot/efi,home}
mount /dev/nvme0n1p1 /mnt/boot/efi
mount /dev/nvme0n1p3 /mnt/home
```

> **No swap partition, by design.** This layout relies on zram (compressed,
> RAM-backed swap — no disk partition needed) instead of a physical swap
> partition. `hosts/system/configuration.nix` doesn't enable it yet, so add
> it yourself before or after the install:
> ```nix
> zramSwap.enable = true;
> ```
> If you change your mind and want a real swap partition after all, give it
> its own `[New]` entry in `cfdisk` before `[Write]` (type "Linux swap"),
> then `mkswap /dev/nvme0n1pX && swapon /dev/nvme0n1pX` instead of/alongside
> the zram option.
>
> With three separate partitions, `nixos-generate-config` in step 1.3 below
> will write **three** plain `fileSystems` entries (`/`, `/home`,
> `/boot/efi`) — no `subvol=` options anywhere, since there's no btrfs here
> — and `swapDevices = [ ];` stays empty. Replace the single btrfs
> `fileSystems."/"` block in `hosts/system/hardware-configuration.nix` with
> all three.

### 1.3 Generate hardware info and reconcile it with the repo

```bash
nixos-generate-config --root /mnt
```

This writes a fresh `/mnt/etc/nixos/hardware-configuration.nix`. **Diff it against
`hosts/system/hardware-configuration.nix` in this repo** — the filesystem UUIDs will differ
from the placeholder values (those were lifted from the old Arch install's `fstab`/`lsblk`
output in `system-audit.txt`), and the `fileSystems` block needs to match whichever
partitioning option you used in 1.2:
- **Option A** (btrfs + subvolumes): `subvol=@`, `subvol=@home`, `subvol=@nix` entries
  instead of the single `subvol=/`.
- **Option C** (cfdisk, plain partitions, no swap): three separate `fileSystems` entries
  (`/`, `/home`, `/boot/efi`), no `subvol=` anywhere, and `swapDevices = [ ];` stays empty.

Copy the corrected `fileSystems`/`boot.initrd.availableKernelModules` block back into this
repo's file, keeping the NVIDIA PRIME / graphics stanzas that `nixos-generate-config` does
**not** know how to write.

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
