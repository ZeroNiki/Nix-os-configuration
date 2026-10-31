# Системная конфигурация хоста `gigabyte-nixos`

`configuration.nix` — основная системная часть (загрузчик, ядро, Nix и nh, сеть, звук, Bluetooth, DDC/CI, редактор, контейнеры и виртуализация, Steam, шрифты, пользователь, `/tmp`, scrub и снимки btrfs, тестовая VM), `hardware-configuration.nix` — диски, файловые системы и модули initrd. Графика NVIDIA вынесена в [`modules/hardware`](../../modules/hardware/README.md), рабочий стол — в [`modules/desktop`](../../modules/desktop/README.md).

Сборка, откат и переустановка — в [`Usage.md`](../../Usage.md), здесь только что и почему настроено.

## `configuration.nix`

### Загрузчик и ядро

| Опция | Значение | Зачем |
|---|---|---|
| `boot.loader.systemd-boot.enable` | `true` | systemd-boot, по пункту на каждое поколение |
| `boot.loader.efi.efiSysMountPoint` | `"/boot/efi"` | ESP смонтирован в `/boot/efi`, а не в `/boot` по умолчанию NixOS. Без этой опции `bootctl` ищет FAT в `/boot`, находит там btrfs и установка загрузчика падает |
| `boot.loader.systemd-boot.configurationLimit` | `10` | ESP — 1 ГиБ, поэтому ядра и initrd копируются максимум для 10 поколений |
| `boot.kernelPackages` | `pkgs.linuxPackages_zen` | ядро zen |
| `hardware.cpu.intel.updateMicrocode` | `true` | микрокод Intel |
| `nixpkgs.config.allowUnfree` | `true` | нужно для драйвера NVIDIA (и Steam) |
| `nix.settings.experimental-features` | `nix-command flakes` | без этого `nix flake …` после установки не работает |
| `nix.optimise.automatic` | `true` | раз в сутки (`nix-optimise.timer`) одинаковые файлы в `/nix/store` заменяются жёсткими ссылками. Результат тот же, что у `auto-optimise-store`, но сборки не ждут проверки каждого добавленного пути |
| `nix.settings.min-free` / `max-free` | 5 ГиБ / 20 ГиБ | если во время сборки на диске меньше 5 ГиБ, Nix собирает мусор, пока свободно не станет 20 ГиБ. Удаляется только то, на что нет корней: поколения, оставленные `nh clean`, не трогаются |
| `nix.channel.enable` | `false` | каналов нет, всё из flake. `nix-shell -p` и `nix shell nixpkgs#…` работают и берут nixpkgs этого flake: `lib.nixosSystem` выставляет `nixpkgs.flake.source`, из него NixOS заполняет `NIX_PATH` и реестр |

### nh и сборка мусора

`programs.nh` — [`nh`](https://github.com/nix-community/nh), обёртка над `nixos-rebuild` с деревом сборки и diff пакетов перед активацией:

| Опция | Значение | Зачем |
|---|---|---|
| `flake` | `"/etc/nixos"` | `NH_FLAKE`: `nh os switch` без `--flake` |
| `clean.enable` | `true` | `nh-clean.timer`, раз в неделю (`clean.dates` по умолчанию `weekly`) |
| `clean.extraArgs` | `--keep 5 --keep-since 7d` | удаляются поколения старше 7 дней, кроме последних 5, потом `/nix/store` чистится от мусора |

`nix.gc.automatic` не включён: `nh clean` делает то же самое и чистит ещё профили пользователя и GC-корни `result`; вместе они конфликтуют (NixOS выдаст предупреждение). Команды — в [`Usage.md`](../../Usage.md#сборка-и-применение-nh).

### Сеть, время, локаль

- `networking.hostName = "gigabyte-nixos"` — совпадает с именем конфигурации во flake, поэтому `nixos-rebuild --flake /etc/nixos` находит её и без `#gigabyte-nixos`.
- NetworkManager, `wifi.powersave = true`. Wi-Fi (iwlwifi) и Ethernet (r8169) драйверы ядро берёт само. Пользователь в группе `networkmanager`, подключаться без sudo:

  ```bash
  nmtui                                            # или клик по блоку сети на панели
  nmcli device wifi connect "<SSID>" password "<пароль>"
  ```

- `time.timeZone = "Asia/Tashkent"`, `i18n.defaultLocale = "en_US.UTF-8"`, дополнительно сгенерирована `ru_RU.UTF-8` (для русских man-страниц, `MANOPT` в `home/shell.nix`).
- Печать выключена: `services.printing.enable = false`.

### Swap

`zramSwap.enable = true` — сжатый swap в памяти, раздела подкачки нет (`swapDevices = [ ]` в `hardware-configuration.nix`).

### `/tmp` в памяти

`boot.tmp.useTmpfs = true` — `/tmp` монтируется как tmpfs (до половины RAM) и пуст после каждой загрузки. Сборки Nix туда не попадают: начиная с Nix 2.30 демон собирает в `/nix/var/nix/builds` (настройка `build-dir`), то есть на диске, поэтому большая сборка память не съест и `nix.settings.build-dir` задавать не нужно.

### Звук

PipeWire с `alsa` (+ 32-бит), `pulse`, `jack` и `wireplumber`, `security.rtkit` для realtime-приоритета. Громкость в сессии — медиа-клавиши (см. [`home/dwl`](../../home/dwl/README.md#медиа-клавиши)) или:

```bash
wpctl status
wpctl set-volume @DEFAULT_AUDIO_SINK@ 50%
```

### Bluetooth

`hardware.bluetooth.enable`, `powerOnBoot = false`: после загрузки адаптер выключен (меньше расход батареи), включается из [`bluetui`](https://github.com/pythops/bluetui) — TUI вроде `nmtui`, пакет в `home/apps.nix`. Он же открывается в ghostty кликом по блоку Bluetooth на панели (серый значок, пока адаптер выключен). Blueman (GUI на Python + GTK, ~0,7 ГиБ) убран. Из терминала ещё есть `bluetoothctl`.

### Яркость внешнего монитора (DDC/CI)

`hardware.i2c.enable = true` — загружает модуль `i2c-dev` (появляются `/dev/i2c-N`) и через udev отдаёт эти устройства группе `i2c` (создаётся автоматически) и пользователю за локальным сеансом. Пользователь добавлен в группу `i2c`. Через эти шины `ddcutil` меняет яркость внешнего монитора по DDC/CI; клавиши и скрипт `brightness` — в [`home/dwl`](../../home/dwl/README.md#яркость). После первого `switch` нужна перезагрузка (новая группа и модуль ядра).

```bash
ddcutil detect
ddcutil getvcp 10
```

### Shell и пользователь

- `programs.zsh.enable`, `users.defaultUserShell = pkgs.zsh`; настройка zsh — в [`home`](../../home/README.md#zsh).
- `users.users.nellaror` (имя приходит из `flake.nix` через `specialArgs.username`): обычный пользователь, группы `wheel`, `networkmanager`, `docker`, `libvirtd`, `video` (подсветка ноутбука через `brightnessctl`), `input`, `i2c` (DDC/CI, см. выше), shell — zsh.
- **Пароль в конфиге не задан** намеренно, чтобы он не попал в git. После установки его ставят через `passwd` (см. [`Usage.md`](../../Usage.md#переустановка)). Пароль, заданный `passwd`, сохраняется между пересборками.
- Системные пакеты — только `git`, всё пользовательское — в Home Manager.
- `security.polkit.enable` (агент аутентификации — в [`modules/desktop`](../../modules/desktop/README.md#polkit-агент)).

### Редактор: только neovim

- `programs.nano.enable = false` — nano, который NixOS ставит по умолчанию, убран.
- `programs.neovim` с `defaultEditor = true` (`EDITOR=nvim`), `viAlias` и `vimAlias`: `vi` и `vim` — это тот же nvim, с конфигом из `~/.dotfiles` (ссылка — в [`home/dev.nix`](../../home/README.md#neovim-из-dotfiles)), а не vim с настройками по умолчанию. Отдельного vim в системе нет.

### Docker и libvirt

- `virtualisation.docker.enable` — Docker, пользователь в группе `docker` (команды без sudo). `enableOnBoot = false`: `dockerd` не стартует при загрузке, его поднимает `docker.socket` при первом вызове `docker` (первая команда после загрузки — на секунду дольше). Контейнеры с `--restart=always` поэтому тоже поднимаются только после первого обращения к docker, а не при загрузке. Podman специально не включён рядом с Docker, чтобы не держать два рантайма; при желании блок заменяется на `virtualisation.podman`.
- `virtualisation.libvirtd.enable` + `programs.virt-manager.enable` — QEMU/KVM через libvirt, GUI `virt-manager`, пользователь в группе `libvirtd`. VirtualBox не ставится: libvirt закрывает ту же задачу без второго гипервизора.
- Vagrant (пакет — в `home/dev.nix`) работает через libvirt: пакет `vagrant` в nixpkgs уже собран с плагином `vagrant-libvirt` (`vagrant plugin list` → `vagrant-libvirt (system)`), а `VAGRANT_DEFAULT_PROVIDER=libvirt` в `home.sessionVariables` (там же) делает его провайдером по умолчанию.

```bash
docker run --rm hello-world
virsh -c qemu:///system list --all
vagrant init generic/debian12 && vagrant up   # VM в libvirt
```

### Игры

- `programs.steam` с `remotePlay.openFirewall = true` и `dedicatedServer.openFirewall = false`.
- `programs.gamemode.enable`, `programs.gamescope.enable`.
- 32-битная графика для Steam/Proton — `hardware.graphics.enable32Bit` в `modules/hardware/nvidia.nix`.
- `extraCompatPackages = [ pkgs.proton-ge-bin ]` — Proton-GE, выбирается в Steam → Свойства игры → Совместимость.
- Запуск игры на NVIDIA: в Steam → Свойства → Параметры запуска `nvidia-offload gamemoderun %command%` (без gamemode — `nvidia-offload %command%`). Без этого игра рисуется на Intel. Подробнее — [`modules/hardware`](../../modules/hardware/README.md#prime-offload-и-nvidia-offload).

### Шрифты

`noto-fonts`, `noto-fonts-cjk-sans`, `noto-fonts-color-emoji`, `nerd-fonts.terminess-ttf` (`Terminess Nerd Font` — Terminus с иконками Nerd Font: терминал, панель, лаунчер, блокировка, уведомления, стартовая страница Firefox), `nerd-fonts.jetbrains-mono` (прежний моноширинный, оставлен для отката).

- `fonts.fontconfig.defaultFonts.monospace = [ "Terminess Nerd Font" ]` — его получают программы, которые просят просто `monospace` (моноширинный текст в Firefox, GTK). Обычный (`sans-serif`) и с засечками (`serif`) не менялись.
- TTY и tuigreet на нём: `console.font = "ter-v24n"` из `pkgs.terminus_font` (PSF-версия Terminus, 12×24 px: 160×50 символов на экране ноутбука), `console.earlySetup = true` — шрифт ставится ещё в initrd.

Имя шрифта задано один раз в [`theme/font.nix`](../../theme/README.md#шрифт); `flake.nix` передаёт его сюда и в модули Home Manager аргументом `font`.

### Num Lock в консолях

`systemd.services.numlock-tty` — при загрузке, до `greetd` и `getty`, выполняет `setleds -D +num` на `/dev/tty1` … `/dev/tty6`, так что Num Lock включён и в tuigreet (он на `tty1`), и в консолях `Ctrl+Alt+F2`… `-D` делает это значением по умолчанию для консоли, поэтому оно не слетает, когда greetd или getty сбрасывают её. В самой сессии dwl Num Lock включает dwl (см. [`home/dwl`](../../home/dwl/README.md#раскладка-enru)): после входа клавиатурой управляет он, а не консоль.

```bash
systemctl status numlock-tty
```

### Тестовая VM (`virtualisation.vmVariant`)

Блок действует только для сборки VM (`nixos-rebuild build-vm` или `config.system.build.vm`), на установленную систему не влияет.

| Опция | Значение | Зачем |
|---|---|---|
| `virtualisation.memorySize` | `8192` МБ | Скрипт `run-*-vm` жёстко связывает `-m` с `memory-backend-memfd`. Если поднять память через `QEMU_OPTS="-m …"`, QEMU откажется стартовать, поэтому размер задаётся здесь |
| `virtualisation.cores` | `4` | |
| `virtualisation.qemu.options` | `[ "-vga" "none" ]` | VM проверяется через последовательную консоль (`QEMU_OPTS="-nographic"`), графического окна нет |
| `users.users.nellaror.password` | `"nixos"` | вход в VM: `nellaror` / `nixos`. Только для VM, в настоящий конфиг пароль не попадает |

KVM используется сам, если доступен (QEMU по умолчанию `accel=kvm:tcg`). Команды сборки и запуска — в [`Usage.md`](../../Usage.md#проверка-в-vm).

### `system.stateVersion`

`"24.11"` — формат данных на диске, а не версия пакетов. Не менять при обновлении nixpkgs; если поднимать, то вместе с `home.stateVersion` в `home/home.nix`.

## `hardware-configuration.nix`

Обычно его целиком генерирует `nixos-generate-config`. Здесь файл ведётся вручную: файловые системы описаны по меткам, а от генератора нужен только список модулей initrd.

### Модули

- `boot.initrd.availableKernelModules`: `nvme` (корень на NVMe), `xhci_pci`, `usb_storage`, `usbhid`, `sd_mod` (USB и клавиатура в initrd), `sdhci_pci` (кардридер).
- `boot.kernelModules = [ "kvm-intel" ]` — для libvirt/QEMU.
- `hardware.enableRedistributableFirmware = true` — прошивки Wi-Fi, Bluetooth, GPU.
- `imports = [ (modulesPath + "/installer/scan/not-detected.nix") ]` — стандартный импорт от генератора.

Список модулей initrd зависит от железа. При переустановке его сверяют с выводом `nixos-generate-config --show-hardware-config` (см. [`Usage.md`](../../Usage.md#переустановка)) и дописывают недостающие.

### Диски и btrfs

Один NVMe-диск: раздел FAT32 с меткой `EFI` и раздел btrfs с меткой `nixos`, на нём сабвольюмы.

| Точка монтирования | Устройство | Сабвольюм | Опции |
|---|---|---|---|
| `/` | `/dev/disk/by-label/nixos` | `@` | `compress=zstd`, `noatime` |
| `/home` | `/dev/disk/by-label/nixos` | `@home` | `compress=zstd`, `noatime` |
| `/nix` | `/dev/disk/by-label/nixos` | `@nix` | `compress=zstd`, `noatime` |
| `/.snapshots` | `/dev/disk/by-label/nixos` | `@snapshots` | `compress=zstd`, `noatime` |
| `/boot/efi` | `/dev/disk/by-label/EFI` | — (vfat) | `fmask=0077`, `dmask=0077` |

`/.snapshots` — сабвольюм под снимки `/home`, их делает btrbk (ниже).

**Почему по меткам, а не по UUID.** UUID появляется только при форматировании, поэтому описание по UUID пришлось бы после каждой разметки вписывать в репо заново. Метки задаются командами `mkfs` из [`Usage.md`](../../Usage.md#переустановка) (`mkfs.fat -F32 -n EFI`, `mkfs.btrfs -L nixos`), так что этот файл верен сразу после форматирования, и тот же конфиг подходит для переустановки без правок.

Чтобы смонтировать систему вручную (например, с установочной флешки), монтировать нужно сабвольюмы, а не корень btrfs:

```bash
mount -o subvol=@,compress=zstd,noatime /dev/disk/by-label/nixos /mnt
mount -o subvol=@home,compress=zstd,noatime /dev/disk/by-label/nixos /mnt/home
mount -o subvol=@nix,compress=zstd,noatime /dev/disk/by-label/nixos /mnt/nix
mount -o subvol=@snapshots,compress=zstd,noatime /dev/disk/by-label/nixos /mnt/.snapshots
mount /dev/disk/by-label/EFI /mnt/boot/efi
nixos-enter --root /mnt
```

### Scrub

`services.btrfs.autoScrub.enable = true` — раз в месяц (`btrfs-scrub-*.timer`) `btrfs scrub` перечитывает все данные и метаданные и сверяет контрольные суммы, так тихая порча на диске находится до того, как понадобится файл. Опция сама берёт по одной точке монтирования на устройство, поэтому диск проверяется один раз, а не для каждого сабвольюма.

```bash
systemctl list-timers 'btrfs-scrub*'
sudo btrfs scrub status /
```

### Снимки `/home` (btrbk)

`services.btrbk.instances.home`: каждый час (`btrbk-home.timer`) снимок сабвольюма `@home` (смонтирован в `/home`) только для чтения кладётся в `/.snapshots` (`@snapshots`) под именем `home.YYYYMMDDThhmm` (`timestamp_format = "long"`). Хранятся все снимки за последние 2 дня (`snapshot_preserve_min = "2d"`), дальше — по одному в день до 14 дней (`snapshot_preserve = "14d"`), остальные btrbk удаляет сам. Систему снимки не покрывают: её откатывают поколения NixOS.

Снимок btrfs ничего не копирует, место занимают только изменения после него. Но и удалённый из `/home` файл (например, игра Steam в `~/.local/share/Steam`) освобождает место только после того, как уйдёт последний снимок с ним, то есть через 14 дней. Если место нужно сразу — удалить старые снимки руками (`sudo btrfs subvolume delete /.snapshots/home.…`).

```bash
ls /.snapshots
cp -a /.snapshots/home.20261031T1200/nellaror/notes.md ~/   # вернуть файл
sudo btrbk -c /etc/btrbk/home.conf list snapshots
sudo btrbk -c /etc/btrbk/home.conf run -n                    # что сделал бы прогон, без изменений
```

### Прочее

- `networking.useDHCP = lib.mkDefault true` — DHCP на интерфейсах, фактически сетью управляет NetworkManager.
- Модуля для фирменного WMI Gigabyte (`gigabyte-laptop-wmi-dkms-git` на Arch: вентиляторы, подсветка клавиатуры) в nixpkgs нет. Если понадобится — собрать оверлеем и добавить в `boot.extraModulePackages`.
