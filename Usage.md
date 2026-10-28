# Использование

Как жить с этим flake: сборка, откат, где что менять, проверка в VM, переустановка. Что и почему настроено — в README каждого каталога (список в [`README.md`](README.md#документация)).

`/etc/nixos` — сам git-репозиторий, владелец `nellaror`: правки и `git` без sudo, sudo нужно только для активации (`nh` спрашивает его сам).

## Сборка и применение: nh

[`nh`](https://github.com/nix-community/nh) — обёртка над `nixos-rebuild`: показывает дерево сборки и в конце diff пакетов (что добавилось, удалилось, сменило версию); с `--ask` перед активацией спрашивает подтверждение. Путь к flake берёт из `NH_FLAKE=/etc/nixos` (`programs.nh.flake` в `hosts/system/configuration.nix`), поэтому `--flake` не нужен.

```bash
nh os build              # собрать, не применяя (бывший nixos-rebuild build)
nh os switch             # собрать и применить, новый пункт в меню загрузки
nh os test               # применить только до перезагрузки, без пункта в меню
nh os switch --ask       # показать diff и спросить, прежде чем применять
nh os switch --update    # nix flake update + switch одной командой

nh search <пакет>        # поиск в nixpkgs
nh clean all --keep 5    # почистить вручную, не дожидаясь таймера
```

Обычные команды тоже работают:

```bash
nix flake check
nixos-rebuild build --flake /etc/nixos
sudo nixos-rebuild switch --flake /etc/nixos
```

- Flake видит только файлы, известные git: новый файл (модуль, патч) — `git add`, иначе сборка его не найдёт.
- После `nix flake update` сначала `nh os build`: на unstable переименовывают опции и пакеты, патчи dwl могут перестать применяться ([что делать](home/dwl/patches/README.md#если-патч-перестал-применяться)). Ошибка вида `'X' has been renamed to 'Y'` — поправить имя.
- `flake.lock` коммитится вместе с конфигом: каждая версия конфига соответствует набору пакетов, с которым её проверяли.
- Правки dwl (`home/dwl/config.h`, патчи, `default.nix`) действуют после выхода из dwl (`Win+Shift+Q`) и нового входа.

### Сборка мусора

`programs.nh.clean`: раз в неделю `nh-clean.timer` удаляет поколения старше 7 дней, кроме последних 5, и чистит `/nix/store` (`--keep 5 --keep-since 7d`). `nix.settings.auto-optimise-store` заменяет одинаковые файлы в store жёсткими ссылками прямо при добавлении.

```bash
systemctl list-timers nh-clean
nix-env --list-generations -p /nix/var/nix/profiles/system
```

## Откат

Каждый `switch` добавляет поколение, ничего не перезаписывается. Если новая сессия сломалась — перезагрузиться и выбрать предыдущее поколение в меню systemd-boot (их там до 10). Из работающей системы:

```bash
sudo nixos-rebuild switch --rollback
```

Графика не стартует совсем: `Ctrl+Alt+F2` — консоль, или пункт `intel-only` в меню загрузки (без драйвера NVIDIA, см. [`modules/hardware`](modules/hardware/README.md#пункт-загрузки-intel-only)).

## Где что менять

| Хочу | Файл |
|---|---|
| Добавить / убрать пакет | `home/home.nix` (`home.packages`); разово запустить без установки — `, <команда>` |
| Shell, промпт, алиасы, git | `home/home.nix` (`programs.zsh`, `programs.starship`) |
| Программы по умолчанию (PDF, картинки, видео, браузер) | `home/home.nix` (`xdg.mimeApps`) |
| Системный сервис (docker, libvirt, bluetooth, …), nh и сборка мусора | `hosts/system/configuration.nix` |
| Режим NVIDIA PRIME (offload ↔ sync) | `modules/hardware/nvidia.nix` |
| Клавиши dwl, лейауты, отступы, правила окон, цвета рамок | `home/dwl/config.h` |
| Патчи dwl | `home/dwl/patches/` + список `patches` в `home/dwl/default.nix` |
| Панель (`dwl-status`), power-меню, автоблокировка (swayidle), swaylock, fuzzel, запуск сессии | `home/dwl/default.nix` |
| Уведомления, терминал, обои, мониторы (kanshi), ночной режим, cliphist, playerctld | `home/desktop/common.nix` |
| Палитра Everforest | `home/theme/everforest.nix`; `config.h` повторяет нужные цвета вручную |
| Экран входа, порталы, polkit-агент, переменные Wayland | `modules/desktop/dwl.nix` |

## Игры на NVIDIA

По умолчанию всё рисует Intel. Чтобы игра шла на RTX 4060 — в Steam → Свойства игры → Параметры запуска:

```
nvidia-offload gamemoderun %command%
```

`nvidia-offload` выставляет переменные PRIME offload, `gamemoderun` включает gamemode. Proton-GE выбирается там же, в «Совместимость» (`programs.steam.extraCompatPackages`). Проверить, что игра на NVIDIA: `nvidia-smi` во время игры, или `MANGOHUD=1` в тех же параметрах.

## Проверка в VM

Собрать и запустить всю систему в QEMU, ничего не трогая на диске (`virtualisation.vmVariant` в `configuration.nix`: 8 ГБ, 4 ядра, вход `nellaror` / `nixos`):

```bash
nixos-rebuild build-vm --flake /etc/nixos
QEMU_OPTS="-nographic" ./result/bin/run-gigabyte-nixos-vm
```

Графики в VM нет (проверка через последовательную консоль), см. [`hosts/system`](hosts/system/README.md#тестовая-vm-virtualisationvmvariant).

## Переустановка

С установочного образа NixOS. Сначала — резервная копия `/home`.

1. **Разметка.** Один NVMe: ESP ~1 ГиБ и btrfs на остальном. Метки `EFI` и `nixos` обязательны — по ним монтирует `hardware-configuration.nix`.

   ```bash
   gdisk /dev/nvme0n1          # p1: +1G, EF00; p2: остальное, 8300
   mkfs.fat -F32 -n EFI /dev/nvme0n1p1
   mkfs.btrfs -L nixos /dev/nvme0n1p2

   mount /dev/nvme0n1p2 /mnt
   for v in @ @home @nix @snapshots; do btrfs subvolume create /mnt/$v; done
   umount /mnt

   o=compress=zstd,noatime
   mount -o subvol=@,$o LABEL=nixos /mnt
   mkdir -p /mnt/{boot/efi,home,nix,.snapshots}
   mount -o subvol=@home,$o LABEL=nixos /mnt/home
   mount -o subvol=@nix,$o LABEL=nixos /mnt/nix
   mount -o subvol=@snapshots,$o LABEL=nixos /mnt/.snapshots
   mount LABEL=EFI /mnt/boot/efi
   ```

2. **Конфиг.** Склонировать репо и сверить модули initrd с тем, что нашёл генератор:

   ```bash
   nix-shell -p git --run "git clone https://github.com/ZeroNiki/Nix-os-configuration.git /mnt/etc/nixos"
   nixos-generate-config --root /mnt --show-hardware-config > /tmp/hw.nix
   diff /tmp/hw.nix /mnt/etc/nixos/hosts/system/hardware-configuration.nix
   ```

   Разница в `fileSystems` (UUID против меток) ожидаема. Если в `/tmp/hw.nix` есть модули из `boot.initrd.availableKernelModules`, которых нет в репо, — дописать их.

3. **Установка и пароль.** Пароль пользователя в конфиге не задан намеренно, без `passwd` войти не получится:

   ```bash
   nixos-install --flake /mnt/etc/nixos#gigabyte-nixos
   nixos-enter --root /mnt -c 'passwd nellaror'
   reboot
   ```

4. **После первого входа.** Склонировать `~/.dotfiles` (оттуда конфиг nvim), создать `~/Pictures/Wallpapers` и положить туда картинки (`systemctl --user restart wpaperd`).

`system.stateVersion` и `home.stateVersion` (`"24.11"`) при переустановке не трогать; если поднимать — оба вместе, на работающей системе.

Смонтировать установленную систему с флешки для починки — сабвольюмы, а не корень btrfs: команды в [`hosts/system`](hosts/system/README.md#диски-и-btrfs).
