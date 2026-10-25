# System Audit Report: Arch -> Minimal NixOS Transition

> Источник: `system-audit.txt` (снято 2026-10-24, Arch Linux, ядро `linux-zen`).
> Цель: фундамент для минималистичной ("suckless-style") конфигурации NixOS на флейках с Home Manager. Текущий стек — Niri + Noctalia, целевой — переход на DWL.

---

## 1. Hardware & Driver Requirements

### Платформа
- **Ноутбук:** Gigabyte (идентифицируется в PCI как CLEVO/KAPOK — типичный Gigabyte/Clevo ODM-рефер).
- **CPU:** Intel Raptor Lake-P (6P+8E cores), встроенная графика Iris Xe.
- **GPU (дискретная):** NVIDIA GeForce **RTX 4060 Max-Q / Mobile** (AD107M, 8 GB VRAM).
- **Сеть:** Intel iwlwifi (Wi-Fi) + Realtek RTL8111/8168/8211 (Ethernet, сейчас без линка).
- **Накопитель:** Kingston OM8PGP4 NVMe (DRAM-less SSD).
- **Аудио:** Intel cAVS (встроенный) + NVIDIA HDA (через HDMI/DP от RTX).
- **Прочее:** Thunderbolt 4 (USB-C), SD-card reader (O2 Micro), gigabyte-laptop-wmi (фирменная WMI-плата, сейчас через `gigabyte-laptop-wmi-dkms-git`).

### Гибридная графика: режим работы

Сейчас используется связка Intel Iris Xe (основной вывод) + NVIDIA через `nvidia-open-dkms`, модуль `nvidia_drm` загружен, но процессы на GPU почти не висят (только композитор `niri` с 2 MiB). Это классический **PRIME Offload** паттерн, а не Sync — для ноутбука с Wayland-композитором на intel-выводе это правильный выбор (экономия батареи, NVIDIA просыпается по требованию).

Рекомендация для NixOS:

```nix
hardware.nvidia = {
  modesetting.enable = true;
  open = true;               # соответствует nvidia-open-dkms из Arch
  package = config.boot.kernelPackages.nvidiaPackages.stable;
  powerManagement.enable = true;       # важно для мобильного GPU (суспенд/резюм)
  powerManagement.finegrained = true;  # динамическое power-gating GPU при простое
  prime = {
    offload.enable = true;
    offload.enableOffloadCmd = true;   # даёт команду `nvidia-offload`
    intelBusId  = "PCI:0:2:0";   # уточнить через `lspci | grep VGA`
    nvidiaBusId = "PCI:1:0:0";
  };
};
hardware.graphics.enable = true;       # замена hardware.opengl.*
services.xserver.videoDrivers = [ "nvidia" ]; # нужен даже под Wayland для модуля ядра
```

Если позже понадобится постоянный доступ к NVIDIA (например, для DWL без хорошего offload-тулинга) — рассмотреть `prime.sync.enable` вместо offload, но для текущего сценария (батарея + Wayland-композитор на Intel) offload предпочтителен.

### Ядро и модули

- Текущее ядро: **`linux-zen`** (сохранить через `boot.kernelPackages = pkgs.linuxPackages_zen;`).
- `nvidia_uvm`, `nvidia_drm`, `nvidia_modeset` — грузятся автоматически NixOS NVIDIA-модулем, явно прописывать не нужно.
- `i915` / `xe` — Intel-модули, в NixOS включаются автоматически при `hardware.graphics.enable`; `xe` — экспериментальный драйвер Intel, можно форсировать через `boot.kernelParams = [ "i915.force_probe=*" ];`, если потребуется (сейчас оба модуля загружены параллельно — не критично).
- `igen6_edac`, `intel_vsec`, `mei_me`, `intel-lpss`, `intel-spi` — штатные модули ядра, подхватываются автоматически, не требуют явной конфигурации.
- Фирменные модули: `gigabyte-laptop-wmi-dkms-git` → в NixOS нет готового модуля в nixpkgs; потребуется **оверлей/flake-input** с собственным выводом ядра (`boot.extraModulePackages`) или поиск форка на NUR.
- `intel-ucode` → `hardware.cpu.intel.updateMicrocode = true;`.
- `auto-cpufreq` → есть пакет в nixpkgs (`services.auto-cpufreq.enable = true;`), либо заменить на встроенный `services.power-profiles-daemon` / `services.tlp` (выбрать одно, не мешать с другим).

### Диски и точки монтирования

```
nvme0n1
├─ nvme0n1p1  vfat   /boot/efi   (FAT32, 2 GB free)
└─ nvme0n1p2  btrfs  /           (588 GB free, 38% used, subvol=/)
```

fstab использует `rw,relatime,ssd,discard=async,space_cache=v2,subvol=/` — явных отдельных subvolumes (`@home`, `@snapshots` и т.п.) не создано, всё живёт в корневом subvol.

NixOS-эквивалент (`hardware-configuration.nix`, генерируется `nixos-generate-config`, но для справки):

```nix
fileSystems."/" = {
  device = "/dev/disk/by-uuid/b8edfcad-4b21-457b-87ec-135cd8f9d8f6";
  fsType = "btrfs";
  options = [ "subvol=/" "ssd" "discard=async" "space_cache=v2" ];
};
fileSystems."/boot/efi" = {
  device = "/dev/disk/by-uuid/048D-515B";
  fsType = "vfat";
};
```

Рекомендация на будущее (не обязательна для миграции): при переустановке на NixOS стоит сразу разбить btrfs на subvolumes (`@`, `@home`, `@nix`, `@snapshots`) — упростит снапшоттинг и rollback независимо от Nix generations.

---

## 2. Essential System Services

| Текущий systemd-сервис (Arch) | Назначение | NixOS-аналог |
|---|---|---|
| `NetworkManager.service` + `-wait-online` + `-dispatcher` | Сеть (Wi-Fi/Ethernet) | `networking.networkmanager.enable = true;` |
| `systemd-resolved.service` | DNS-резолвинг | `services.resolved.enable = true;` (или оставить NM-встроенный) |
| `systemd-timesyncd.service` | Синхронизация времени | `services.timesyncd.enable = true;` (включен по умолчанию) |
| `bluetooth.service` | Bluetooth-стек | `hardware.bluetooth.enable = true;` + `services.blueman.enable` (опц., GUI) |
| `nvidia-persistenced.service` | Удержание состояния NVIDIA-драйвера | включается автоматически через `hardware.nvidia.*` в NixOS |
| `sddm.service` | Display/login manager | `services.displayManager.sddm.enable = true;` **либо** заменить на `greetd` (см. ниже — у вас уже стоит `greetd`+`tuigreet`, выбрать один) |
| `cronie.service` | Cron-планировщик | `services.cron.enable = true;` (или сразу systemd-timers — Nix-идиоматичнее) |
| `libvirt`-группа (`virtqemud`, `virtnetworkd`, `virtstoraged` сокеты) | Виртуализация (QEMU/KVM) | `virtualisation.libvirtd.enable = true;` |
| `docker` (пакет, сервис не в списке enabled, но установлен) | Контейнеризация | `virtualisation.docker.enable = true;` |
| PipeWire (не отдельный systemd unit, user-level) | Аудио/видео сервер | `services.pipewire = { enable = true; alsa.enable = true; pulse.enable = true; jack.enable = true; }; security.rtkit.enable = true;` |
| `AmneziaVPN.service` | VPN (обфусцированный WireGuard) | нет готового NixOS-модуля — AUR-бинарник; придётся паковать вручную или запускать AppImage/Flatpak-эквивалент |
| `ceserver.service` | Cheat Engine network server (для отладки игр) | нишевый — не NixOS-модуль, systemd user unit вручную при необходимости |

### Лишнее / кандидаты на отключение
- Дублирующиеся display/session managers: в системе одновременно установлены **sddm** (enabled) и **greetd + tuigreet** (установлен, но не enabled) — на NixOS выбрать **один**. Для suckless/DWL-направления **greetd+tuigreet** логичнее (минимализм, TTY-like), но пока активен Niri+Noctalia удобнее остаться на sddm или сразу перейти на greetd.
- `virtqemud`/`virtnetworkd`/`virtstoraged` сокеты — активируются лениво через `virtualisation.libvirtd`, отдельно включать не нужно.
- `ceserver` — специфичный тул для читерства в играх через сеть; переносить в NixOS только если реально нужен remote-debug для Cheat Engine.

---

## 3. Package Mapping (Arch -> NixOS)

### CLI / TUI & Dev Tools

| Arch (pacman/AUR) | NixOS package / flake |
|---|---|
| `neovim` | `neovim` |
| `tmux` | `tmux` |
| `zsh` | `zsh` (+ `programs.zsh.enable = true;`) |
| `fzf` | `fzf` |
| `ripgrep` | `ripgrep` |
| `bat` | `bat` |
| `lsd` | `lsd` |
| `duf` | `duf` |
| `dust` | `dust` |
| `zoxide` | `zoxide` |
| `jq` | `jq` |
| `tree` | `tree` |
| `htop` / `btop` | `htop` / `btop` |
| `git`, `git-delta`, `git-lfs` | `git`, `git-delta`, `git-lfs` |
| `glab` | `glab` |
| `stow` | `stow` |
| `tree-sitter-cli` | `tree-sitter` |
| `yazi` | `yazi` |
| `glow` | `glow` |
| `sops`, `age` | `sops`, `age` (ключевые для secrets management в самом Nix-репо) |
| `rsync`, `wget`, `socat`, `sshpass` | `rsync`, `wget`, `socat`, `sshpass` |
| `strace` | `strace` |
| `nodejs`, `npm` | `nodejs`, `nodePackages.npm` |
| `python310`, `python-pip`, `python-pipx` | `python310`, `python310Packages.pip`, `pipx` |
| `cmake`, `base-devel` | `cmake`, `stdenv` + `gcc`/`gnumake` по необходимости |
| `kubectl`, `helm`, `minikube` | `kubectl`, `kubernetes-helm`, `minikube` |
| `terraform`, `terraform-ls-bin` | `terraform`, `terraform-ls` |
| `vagrant` | `vagrant` |
| `postman-bin`, `newman` | `postman`, `newman` |
| `claude-code` | `claude-code` (есть в nixpkgs/community overlay) |
| `opencode` | есть в nixpkgs (новый пакет) либо flake-input |
| `sdcv`, `stardict-oed` | `sdcv` (словари — отдельный data-пакет) |
| `plocate` | `plocate` |
| `smartmontools` | `smartmontools` |
| `cronie` | не нужен отдельно — использовать `services.cron` либо systemd-timers |

**TUI-игрушки/fetch-утилиты** (минимализм — можно оставить как "nice to have", не блотварь):
`fastfetch`, `cpufetch`, `nitch`, `cmatrix`, `asciiquarium`, `pipes.sh`, `cbonsai`, `tty-clock`, `clock-tui`, `lolcat`, `no-more-secrets` — все есть в nixpkgs 1:1 по имени, добавляются по желанию, в "суровом" минимальном профиле можно вынести в отдельный опциональный `home-manager`-модуль `fun-tui.nix`.

### GUI & Work/Study

| Arch | NixOS |
|---|---|
| `firefox` | `firefox` |
| `discord` (+ `vesktop`) | `discord` или `vesktop` (vesktop легче и Wayland-native — для suckless-подхода предпочтительнее) |
| `telegram-desktop` | `telegram-desktop` |
| `rocketchat-desktop` | `rocketchat-desktop` (AUR-only → NUR/оверлей, либо веб-версия через Firefox PWA) |
| `obsidian` | `obsidian` |
| `keepassxc` | `keepassxc` |
| `libreoffice-fresh` | `libreoffice-fresh` (тяжёлый — оценить, нужен ли полный пакет или `libreoffice-still`) |
| `zathura` (+`-cb`,`-djvu`,`-pdf-mupdf`) | `zathura` с `zathura-pdf-mupdf`, `zathura-djvu`, `zathura-cb` — идеальный suckless-ридер, оставить как основной PDF-вьюер |
| `ghostty` | `ghostty` — терминал, отлично вписывается в suckless-эстетику |
| `kitty` | `kitty` (дублирует ghostty — решить, какой терминал первичный) |
| `tabby`, `termius` | `tabby`, `termius` (оба — SSH-клиенты с GUI, явная избыточность с `ghostty`+`ssh`; оставить один, если нужен GUI SSH-менеджер) |
| `obs-studio` | `obs-studio` |
| `flameshot` | `flameshot`, но под Wayland логичнее `grim`+`slurp`+`satty` (уже есть в списке) — **flameshot можно дропнуть** в пользу grim/slurp/satty |
| `syncthing` | `syncthing` |
| `rustdesk` | `rustdesk` |

### Gaming Infrastructure

| Arch | NixOS |
|---|---|
| `steam` | `programs.steam.enable = true;` (включает Proton, Steam Runtime) |
| `gamemode`, `lib32-gamemode` | `programs.gamemode.enable = true;` |
| `gamescope` | `gamescope` (+ `programs.gamescope.enable = true;` для session-интеграции) |
| `mangohud` | `programs.mangohud.enable = true;` |
| `protontricks` | `protontricks` |
| `protonup-qt` | `protonup-qt` (AUR-only → проверить nixpkgs/NUR) |
| `vulkan-tools` | `vulkan-tools` |
| `prismlauncher` | `prismlauncher` (Minecraft) |
| `osu-lazer` | `osu-lazer-bin` в nixpkgs |
| `qemu-full`/`qemu-desktop`, `virt-manager`, `virt-viewer`, `virtualbox` | `virtualisation.libvirtd.enable`, `virt-manager`, `virt-viewer`; **virtualbox параллельно с libvirt/qemu — избыточно**, выбрать один гипервизор |

### Явно лишнее / blotware-кандидаты на дроп при миграции
- `gameconqueror`, `scanmem`, `cheat-engine-zh` — нишевые memory-editing тулы, брать только если активно используются для конкретных игр.
- `android-file-transfer`, `android-tools`, `mtpfs`, `gvfs-mtp` — нужны только если реально подключаете Android-устройство по MTP; иначе дроп.
- `hakuneko-desktop-nightly`, `kcc`, `mcat-bin` — манга/комикс-тулы, нишевые, оставить по желанию пользователя.
- `openrgb` — RGB-подсветка, оставить если есть ARGB-периферия.
- `timeshift` — избыточен при btrfs+NixOS generations (NixOS сам по себе снапшотит систему через generations; для данных — `btrfs snapshot` напрямую или `snapper`).
- `virtualbox` vs `libvirt/qemu` — дублирование гипервизоров, см. выше.
- `kitty` vs `ghostty`, `tabby`/`termius` vs обычный `ssh` — дублирующийся функционал терминалов/SSH-клиентов.
- `flameshot` vs `grim`+`slurp`+`satty` — Wayland-native стек предпочтительнее под Niri/DWL.
- `yay-bin`, `yay-bin-debug`, `paru` — AUR-хелперы, в NixOS не нужны вообще (заменяются flake inputs / overlays / NUR).
- `debootstrap` — нужен только если реально собираете chroot Debian-окружения; иначе дроп.
- `cheat-engine-zh`, `ceserver` — если не используется активно для реверса игр, дроп.

---

## 4. Compositor & Display Stack

### Текущий стек: Niri + Noctalia
- **Niri** — scrollable-tiling Wayland-композитор (аналог PaperWM), не suckless сам по себе, но модульный и конфигурируется декларативно (KDL-конфиг).
- **Noctalia** — shell/panel-оболочка для Niri (замена waybar+rofi-связки единым Quickshell-проектом).
- Параллельно установлены **Hyprland + hyprlock + hyprpaper + kwin** — следы экспериментов с другими композиторами; **для чистой NixOS-конфигурации стоит оставить только активно используемый** (Niri), остальные дропнуть как шум.
- **sddm** vs **greetd+tuigreet** — тоже дублирование, см. раздел 2.

### Фундамент для будущего перехода на DWL
DWL (dwm для Wayland) требует куда более "ручного" набора компонентов, чем Niri+Noctalia — в этом и суть suckless-подхода: каждый кусок стека — отдельный независимый бинарник, а не единый shell.

Чтобы заложить фундамент уже сейчас, стоит строить **модульный `home-manager`**, где компоненты стека не завязаны жёстко на Niri, а переиспользуемы под DWL:

| Функция | Текущее (Niri+Noctalia) | Переносимо на DWL без изменений? |
|---|---|---|
| Portal (screen-share, file-picker) | `xdg-desktop-portal-gnome` / `-hyprland` | нужен `xdg-desktop-portal-wlr` для DWL — **сменить провайдера портала** |
| Status bar | Noctalia (встроенный) | нет — под DWL взять `waybar` (уже установлен) или писать свой dwl-style statusbar |
| App launcher | встроенный в Noctalia / `wofi` | да — `rofi`/`fuzzel`/`wofi` универсальны, уже есть `rofi` и `wofi` (дублируют друг друга, выбрать один) |
| Screenshot | `grim`+`slurp`+`satty` | да, 1:1 переносится |
| Clipboard | `wl-clipboard` | да, + добавить `cliphist` для истории (сейчас не установлен — рекомендация) |
| Idle/lock | `hyprlock` (Hypr-специфичный) | нет — заменить на `swaylock` или минималистичный DWL-совместимый лоcker |
| Notifications | встроено в Noctalia | нет — под DWL нужен отдельный `mako` или `dunst` (сейчас явного notification daemon в списке пакетов нет, только `libnotify` как клиентская либа — **добавить `mako`**) |
| Polkit agent | `polkit-kde-agent` | да, универсален, либо заменить на более легкий `polkit-gnome` |
| Wallpaper | `hyprpaper` (Hypr-специфичный) + `matugen`/`pywal` (генерация палитры) | заменить на `swaybg` для DWL-совместимости |
| Output management | `kanshi` | да, протокол-агностичный, переносится |
| Brightness/OSD | `brightnessctl`, `swayosd`, `light`, `ddcutil` | да, все CLI-инструменты независимы от композитора |
| Idle inhibit / power menu | нет явного (возможно внутри Noctalia) | под DWL нужен отдельный `wlogout` или скрипт |

**Рекомендация:** уже на этапе Niri держать все вспомогательные Wayland-утилиты (grim, slurp, wl-clipboard, cliphist, kanshi, brightnessctl, mako) как отдельные `home-manager` модули, не зависящие от самого композитора. Тогда переход на DWL — это замена одного модуля (`niri.nix` → `dwl.nix` + свой statusbar/launcher-конфиг), а не пересборка всего стека.

---

## 5. NixOS Configuration Architecture Proposal

```
nix-os/
├── flake.nix                     # входная точка: inputs (nixpkgs, home-manager, niri, dwl?), outputs (nixosConfigurations, homeConfigurations)
├── flake.lock
│
├── hosts/
│   └── laptop-gigabyte/          # имя хоста ноутбука
│       ├── default.nix           # сборка конфигурации хоста: импортирует hardware + modules
│       ├── hardware-configuration.nix   # авто-генерируется nixos-generate-config, НЕ редактировать руками
│       └── disko.nix             # (опц.) декларативное описание разметки диска, если используется disko
│
├── modules/
│   ├── nixos/
│   │   ├── boot.nix              # linux-zen, microcode, kernelParams
│   │   ├── nvidia.nix            # hardware.nvidia.* + prime offload
│   │   ├── networking.nix        # NetworkManager, resolved
│   │   ├── audio.nix             # pipewire + rtkit
│   │   ├── bluetooth.nix
│   │   ├── virtualisation.nix    # docker + libvirtd
│   │   ├── gaming.nix            # steam, gamemode, gamescope
│   │   ├── fonts.nix             # noto-fonts, jetbrains-mono-nerd
│   │   └── users.nix             # основной пользователь, zsh как shell
│   │
│   └── home-manager/
│       ├── shell/
│       │   ├── zsh.nix
│       │   └── cli-tools.nix     # bat, lsd, fzf, ripgrep, zoxide, yazi...
│       ├── dev/
│       │   ├── neovim.nix
│       │   ├── git.nix
│       │   └── k8s-devops.nix    # kubectl, helm, terraform, docker-compose
│       ├── wayland-common/        # компоненты, переносимые между Niri и DWL
│       │   ├── portals.nix
│       │   ├── clipboard.nix     # wl-clipboard + cliphist
│       │   ├── screenshot.nix    # grim + slurp + satty
│       │   ├── notifications.nix # mako
│       │   ├── idle-lock.nix
│       │   └── osd.nix           # swayosd, brightnessctl
│       ├── compositor/
│       │   ├── niri.nix          # текущий активный композитор + noctalia
│       │   └── dwl.nix           # заготовка на будущее (неактивна до перехода)
│       ├── terminal/
│       │   └── ghostty.nix       # единый терминал (решить: ghostty vs kitty)
│       ├── apps/
│       │   ├── browsers.nix      # firefox
│       │   ├── communication.nix # discord/vesktop, telegram
│       │   ├── productivity.nix  # obsidian, keepassxc, zathura
│       │   └── media.nix         # mpv, spotify
│       └── gaming.nix            # mangohud, protontricks (user-level настройки)
│
├── secrets/
│   └── sops/                     # sops-nix конфигурация, ключи через age
│
└── README.md
```

**Принципы:**
- `modules/home-manager/wayland-common/` — ядро suckless-фундамента: эти модули не знают, какой композитор активен, и одинаково работают под Niri и будущим DWL.
- `modules/home-manager/compositor/` — единственное место, которое меняется при переходе Niri → DWL; переключение делается одной строкой импорта в `hosts/laptop-gigabyte/default.nix`.
- `hosts/` держит только хост-специфичное (железо, диск); вся логика — в `modules/`, что позволяет легко добавить второй хост в будущем.
- Секреты (VPN-конфиги AmneziaVPN, API-токены Postman/Terraform) — через `sops-nix`, не хардкодить в репозитории.
