# Системная конфигурация хоста `gigabyte-nixos`

`configuration.nix` — основная системная часть (загрузчик, ядро, сеть, звук, Bluetooth, DDC/CI, контейнеры и виртуализация, Steam, шрифты, пользователь, тестовая VM), `hardware-configuration.nix` — диски, файловые системы и модули initrd. Графика NVIDIA вынесена в [`modules/hardware`](../../modules/hardware/README.md), рабочий стол — в [`modules/desktop`](../../modules/desktop/README.md).

Установка и обслуживание — в [`Usage.md`](../../Usage.md), здесь только что и почему настроено.

## `configuration.nix`

### Загрузчик и ядро

| Опция | Значение | Зачем |
|---|---|---|
| `boot.loader.systemd-boot.enable` | `true` | systemd-boot, по пункту на каждое поколение |
| `boot.loader.efi.efiSysMountPoint` | `"/boot/efi"` | ESP смонтирован в `/boot/efi`, а не в `/boot` по умолчанию NixOS. Без этой опции `bootctl` ищет FAT в `/boot`, находит там btrfs и установка загрузчика падает |
| `boot.loader.systemd-boot.configurationLimit` | `10` | ESP — 1 ГиБ, поэтому ядра и initrd копируются максимум для 10 поколений |
| `boot.kernelPackages` | `pkgs.linuxPackages_zen` | ядро zen, как было на Arch |
| `hardware.cpu.intel.updateMicrocode` | `true` | микрокод Intel |
| `nixpkgs.config.allowUnfree` | `true` | нужно для драйвера NVIDIA (и Steam) |
| `nix.settings.experimental-features` | `nix-command flakes` | без этого `nix flake …` после установки не работает |

В меню systemd-boot у каждого поколения есть ещё пункт `intel-only` — см. [`modules/hardware`](../../modules/hardware/README.md#пункт-загрузки-intel-only).

### Сеть, время, локаль

- `networking.hostName = "gigabyte-nixos"` — совпадает с именем конфигурации во flake, поэтому `nixos-rebuild --flake /etc/nixos` находит её и без `#gigabyte-nixos`.
- NetworkManager, `wifi.powersave = true`. Wi-Fi (iwlwifi) и Ethernet (r8169) драйверы ядро берёт само. Пользователь в группе `networkmanager`, подключаться без sudo:

  ```bash
  nmtui                                            # или клик по блоку сети на панели
  nmcli device wifi connect "<SSID>" password "<пароль>"
  ```

- `time.timeZone = "Asia/Tashkent"`, `i18n.defaultLocale = "en_US.UTF-8"`, дополнительно сгенерирована `ru_RU.UTF-8` (для русских man-страниц, `MANOPT` в `home/home.nix`).
- Печать выключена: `services.printing.enable = false`.

### Swap

`zramSwap.enable = true` — сжатый swap в памяти, раздела подкачки нет (`swapDevices = [ ]` в `hardware-configuration.nix`).

### Звук

PipeWire с `alsa` (+ 32-бит), `pulse`, `jack` и `wireplumber`, `security.rtkit` для realtime-приоритета. Громкость в сессии — медиа-клавиши (см. [`home/dwl`](../../home/dwl/README.md#медиа-клавиши)) или:

```bash
wpctl status
wpctl set-volume @DEFAULT_AUDIO_SINK@ 50%
```

### Bluetooth

`hardware.bluetooth.enable`, `powerOnBoot = true` (адаптер включается при загрузке), `services.blueman.enable` — GUI `blueman-manager`, он же открывается кликом по блоку Bluetooth на панели. Из терминала — `bluetoothctl`.

### Яркость внешнего монитора (DDC/CI)

`hardware.i2c.enable = true` — загружает модуль `i2c-dev` (появляются `/dev/i2c-N`) и через udev отдаёт эти устройства группе `i2c` (создаётся автоматически) и пользователю за локальным сеансом. Пользователь добавлен в группу `i2c`. Через эти шины `ddcutil` меняет яркость внешнего монитора по DDC/CI; клавиши и скрипт `brightness` — в [`home/dwl`](../../home/dwl/README.md#яркость). После первого `switch` нужна перезагрузка (новая группа и модуль ядра).

```bash
ddcutil detect
ddcutil getvcp 10
```

### Shell и пользователь

- `programs.zsh.enable`, `users.defaultUserShell = pkgs.zsh`; настройка zsh — в [`home`](../../home/README.md#zsh).
- `users.users.nellaror` (имя приходит из `flake.nix` через `specialArgs.username`): обычный пользователь, группы `wheel`, `networkmanager`, `docker`, `libvirtd`, `video` (подсветка ноутбука через `brightnessctl`), `input`, `i2c` (DDC/CI, см. выше), shell — zsh.
- **Пароль в конфиге не задан** намеренно, чтобы он не попал в git. После установки его ставят через `passwd` (см. [`Usage.md`](../../Usage.md#15-install), раздел 1.5). Пароль, заданный `passwd`, сохраняется между пересборками.
- Системные пакеты — только `git` и `vim`, всё пользовательское — в Home Manager.
- `security.polkit.enable` (агент аутентификации — в [`modules/desktop`](../../modules/desktop/README.md#polkit-агент)).

### Docker и libvirt

- `virtualisation.docker.enable` — Docker, пользователь в группе `docker` (команды без sudo). Podman специально не включён рядом с Docker, чтобы не держать два рантайма; при желании блок заменяется на `virtualisation.podman`.
- `virtualisation.libvirtd.enable` + `programs.virt-manager.enable` — QEMU/KVM через libvirt, GUI `virt-manager`, пользователь в группе `libvirtd`. VirtualBox не ставится: libvirt закрывает ту же задачу без второго гипервизора.

```bash
docker run --rm hello-world
virsh -c qemu:///system list --all
```

### Игры

- `programs.steam` с `remotePlay.openFirewall = true` и `dedicatedServer.openFirewall = false`.
- `programs.gamemode.enable`, `programs.gamescope.enable`.
- 32-битная графика для Steam/Proton — `hardware.graphics.enable32Bit` в `modules/hardware/nvidia.nix`.
- Запуск игры на NVIDIA: в Steam → Свойства → Параметры запуска `nvidia-offload %command%` (подробнее — [`modules/hardware`](../../modules/hardware/README.md#prime-offload-и-nvidia-offload)). С gamemode: `nvidia-offload gamemoderun %command%`.

### Шрифты

`noto-fonts`, `noto-fonts-cjk-sans`, `noto-fonts-color-emoji`, `nerd-fonts.jetbrains-mono` (`JetBrainsMono Nerd Font` — шрифт панели, терминала, лаунчера, блокировки и уведомлений).

### Тестовая VM (`virtualisation.vmVariant`)

Блок действует только для сборки VM (`nixos-rebuild build-vm` или `config.system.build.vm`), на установленную систему не влияет.

| Опция | Значение | Зачем |
|---|---|---|
| `virtualisation.memorySize` | `8192` МБ | Скрипт `run-*-vm` жёстко связывает `-m` с `memory-backend-memfd`. Если поднять память через `QEMU_OPTS="-m …"`, QEMU откажется стартовать, поэтому размер задаётся здесь |
| `virtualisation.cores` | `4` | |
| `virtualisation.qemu.options` | `[ "-vga" "none" ]` | VM проверяется через последовательную консоль (`QEMU_OPTS="-nographic"`), графического окна нет |
| `users.users.nellaror.password` | `"nixos"` | вход в VM: `nellaror` / `nixos`. Только для VM, в настоящий конфиг пароль не попадает |

KVM используется сам, если доступен (QEMU по умолчанию `accel=kvm:tcg`). Команды сборки и запуска — в [`Usage.md`](../../Usage.md#0-before-you-touch-partitions--validate-the-config-first-zero-risk), раздел 0.

### `system.stateVersion`

`"24.11"` — формат данных на диске, а не версия пакетов. Не менять при обновлении nixpkgs; если поднимать, то вместе с `home.stateVersion` в `home/home.nix`.

## `hardware-configuration.nix`

Обычно его целиком генерирует `nixos-generate-config`. Здесь файл ведётся вручную: файловые системы описаны по меткам, а от генератора нужен только список модулей initrd.

### Модули

- `boot.initrd.availableKernelModules`: `nvme` (корень на NVMe), `xhci_pci`, `usb_storage`, `usbhid`, `sd_mod` (USB и клавиатура в initrd), `sdhci_pci` (кардридер).
- `boot.kernelModules = [ "kvm-intel" ]` — для libvirt/QEMU.
- `hardware.enableRedistributableFirmware = true` — прошивки Wi-Fi, Bluetooth, GPU.
- `imports = [ (modulesPath + "/installer/scan/not-detected.nix") ]` — стандартный импорт от генератора.

Список модулей initrd зависит от железа. При переустановке его сверяют с выводом `nixos-generate-config --show-hardware-config` (см. [`Usage.md`](../../Usage.md#13-generate-hardware-info-then-put-this-flake-where-the-installer-expects-it), раздел 1.3) и дописывают недостающие.

### Диски и btrfs

Один NVMe-диск: раздел FAT32 с меткой `EFI` и раздел btrfs с меткой `nixos`, на нём сабвольюмы.

| Точка монтирования | Устройство | Сабвольюм | Опции |
|---|---|---|---|
| `/` | `/dev/disk/by-label/nixos` | `@` | `compress=zstd`, `noatime` |
| `/home` | `/dev/disk/by-label/nixos` | `@home` | `compress=zstd`, `noatime` |
| `/nix` | `/dev/disk/by-label/nixos` | `@nix` | `compress=zstd`, `noatime` |
| `/.snapshots` | `/dev/disk/by-label/nixos` | `@snapshots` | `compress=zstd`, `noatime` |
| `/boot/efi` | `/dev/disk/by-label/EFI` | — (vfat) | `fmask=0077`, `dmask=0077` |

`/.snapshots` — только сабвольюм под снимки: инструмент снапшотов (snapper, btrbk) в конфиге не настроен.

**Почему по меткам, а не по UUID.** UUID появляется только при форматировании, поэтому описание по UUID пришлось бы после каждой разметки вписывать в репо заново. Метки задаются командами `mkfs` из `Usage.md` (`mkfs.fat -F32 -n EFI`, `mkfs.btrfs -L nixos`), так что этот файл верен сразу после форматирования, и тот же конфиг подходит для переустановки без правок.

Чтобы смонтировать систему вручную (например, с установочной флешки), монтировать нужно сабвольюмы, а не корень btrfs:

```bash
mount -o subvol=@,compress=zstd,noatime /dev/disk/by-label/nixos /mnt
mount -o subvol=@home,compress=zstd,noatime /dev/disk/by-label/nixos /mnt/home
mount -o subvol=@nix,compress=zstd,noatime /dev/disk/by-label/nixos /mnt/nix
mount -o subvol=@snapshots,compress=zstd,noatime /dev/disk/by-label/nixos /mnt/.snapshots
mount /dev/disk/by-label/EFI /mnt/boot/efi
nixos-enter --root /mnt
```

### Прочее

- `networking.useDHCP = lib.mkDefault true` — DHCP на интерфейсах, фактически сетью управляет NetworkManager.
- Модуля для фирменного WMI Gigabyte (`gigabyte-laptop-wmi-dkms-git` на Arch: вентиляторы, подсветка клавиатуры) в nixpkgs нет. Если понадобится — собрать оверлеем и добавить в `boot.extraModulePackages`.
