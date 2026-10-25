# NixOS на ноутбуке Gigabyte

Flake с конфигурацией NixOS для ноутбука Gigabyte (Intel Raptor Lake с Iris Xe + NVIDIA RTX 4060 в режиме PRIME offload): минималистичный Wayland-рабочий стол на [dwl](https://codeberg.org/dwl/dwl) с панелью dwlb, пользовательская часть — через Home Manager. Репозиторий лежит в `/etc/nixos`.

Установка, проверка в VM, обновления и откат — в [`Usage.md`](Usage.md). Аудит старой системы на Arch, с которого начиналась миграция, — исторический документ: [`docs/arch-migration-audit.md`](docs/arch-migration-audit.md).

## Что внутри

| Часть | Что |
|---|---|
| Ядро, загрузка | ядро zen (`linuxPackages_zen`), systemd-boot, ESP в `/boot/efi`, btrfs с сабвольюмами, zram вместо раздела подкачки |
| Графика | Intel рисует всё, NVIDIA просыпается по `nvidia-offload`; аварийный пункт загрузки `intel-only` |
| Вход | greetd + tuigreet |
| Рабочий стол | dwl 0.9 с патчами (лейаут btrtile как в bspwm, отступы, индикатор раскладки), dwlb + `dwl-status`, fuzzel, swaylock, mako, wpaperd, kanshi, cliphist |
| Терминал и shell | ghostty, zsh + oh-my-zsh + powerlevel10k |
| Тема | Everforest Dark Medium |
| Прочее | PipeWire, Bluetooth, Docker, libvirt, Steam |

## Устройство flake

- **inputs:** `nixpkgs` (`nixos-unstable`) и `home-manager` (с `inputs.nixpkgs.follows = "nixpkgs"`, то есть на той же ревизии nixpkgs). Версии зафиксированы в `flake.lock`.
- **outputs:** `nixosConfigurations.gigabyte-nixos` и `nixosConfigurations.default` — псевдоним на ту же конфигурацию.
- `username = "nellaror"` задаётся один раз в `flake.nix` и передаётся во все модули через `specialArgs` (системные) и `home-manager.extraSpecialArgs` (Home Manager).
- Home Manager подключён модулем NixOS, а не отдельной командой: `home-manager.useGlobalPkgs` (тот же `pkgs`, что у системы, с `allowUnfree`), `useUserPackages` (пакеты пользователя в `/etc/profiles/per-user/nellaror`), `backupFileExtension = "hm-bak"`. Пересобирается вместе с системой одной командой `nixos-rebuild`.

### Что откуда импортируется

```
flake.nix
└─ nixosConfigurations.gigabyte-nixos
   ├─ hosts/system/configuration.nix        система: загрузка, сеть, звук, пользователь, сервисы
   ├─ hosts/system/hardware-configuration.nix  диски, initrd
   ├─ modules/hardware/nvidia.nix           Intel + NVIDIA, intel-only
   ├─ modules/desktop/dwl.nix               greetd, сессия dwl, polkit, порталы
   └─ home-manager.users.nellaror = home/home.nix
      ├─ home/desktop/common.nix            mako, ghostty, cliphist, wpaperd, kanshi
      │  └─ home/theme/everforest.nix
      └─ home/dwl/default.nix               dwl + патчи, dwlb, dwl-status, запуск сессии, swaylock, fuzzel
         ├─ home/dwl/config.h
         ├─ home/dwl/patches/*.patch
         └─ home/theme/everforest.nix
```

## Документация

| README | О чём |
|---|---|
| [`hosts/system/README.md`](hosts/system/README.md) | загрузчик, ядро, сеть, звук, Bluetooth, Docker/libvirt, Steam, шрифты, пользователь, zram, тестовая VM; диски, btrfs, метки |
| [`modules/hardware/README.md`](modules/hardware/README.md) | NVIDIA: PRIME offload, `nvidia-offload`, busId, `intel-only`, внешние мониторы |
| [`modules/desktop/README.md`](modules/desktop/README.md) | greetd + tuigreet, `dwl-session.target`, polkit, порталы, PAM для swaylock |
| [`home/README.md`](home/README.md) | zsh, git, CLI-утилиты, nvim/vim из `~/.dotfiles`, LSP из Nix, пакеты |
| [`home/dwl/README.md`](home/dwl/README.md) | **рабочий стол**: запуск сессии, все горячие клавиши, лейауты, панель, раскладка, обои, мониторы, блокировка, как менять конфиг, частые проблемы |
| [`home/dwl/patches/README.md`](home/dwl/patches/README.md) | патчи dwl: откуда, что делают, порядок, что делать при поломке |
| [`home/desktop/README.md`](home/desktop/README.md) | mako, ghostty, cliphist, wpaperd, kanshi, утилиты Wayland |
| [`home/theme/README.md`](home/theme/README.md) | палитра Everforest и где какой цвет |
| [`Usage.md`](Usage.md) | установка, проверка в VM, обновление, откат |

## Быстрые команды

```bash
cd /etc/nixos

nix flake check                                              # проверка вычисления конфигурации
nixos-rebuild build --flake /etc/nixos#gigabyte-nixos        # собрать, не применяя
sudo nixos-rebuild switch --flake /etc/nixos#gigabyte-nixos  # собрать и применить
sudo nixos-rebuild switch --rollback                         # вернуть предыдущее поколение

nix flake update                                             # обновить nixpkgs и home-manager (flake.lock)
sudo nix-collect-garbage -d                                  # удалить старые поколения и мусор из /nix/store
```

Hostname совпадает с именем конфигурации, поэтому `--flake /etc/nixos` без `#gigabyte-nixos` тоже работает.

- Flake видит только файлы, известные git: новый файл (модуль, патч) нужно `git add`, иначе сборка его не найдёт.
- Правки dwl (`home/dwl/config.h`, патчи, `default.nix`) вступают в силу после выхода из dwl (`Win+Shift+Q`) и нового входа.
- После `nix flake update` сначала `nixos-rebuild build`: на unstable часто переименовывают опции и пакеты, а патчи dwl могут перестать применяться ([что делать](home/dwl/patches/README.md#если-патч-перестал-применяться)).
- Вместе с изменениями конфига коммитится и `flake.lock`, чтобы каждая версия конфига соответствовала набору пакетов, с которым её проверяли.

## Где что менять

Таблица типовых правок «что хочу → какой файл» — в [`Usage.md`, раздел 2.3](Usage.md#23-common-day-to-day-edits-and-where-they-live).
