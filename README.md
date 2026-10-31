# NixOS на ноутбуке Gigabyte

Flake с конфигурацией NixOS для ноутбука Gigabyte (Intel Raptor Lake с Iris Xe + NVIDIA RTX 4060 в режиме PRIME offload): минималистичный Wayland-рабочий стол на [dwl](https://codeberg.org/dwl/dwl) с панелью dwlb, пользовательская часть — через Home Manager. Репозиторий лежит в `/etc/nixos`.

Сборка, откат, где что менять, проверка в VM и переустановка — в [`Usage.md`](Usage.md). Аудит системы на Arch, с которого начиналась миграция, удалён как устаревший; он есть в истории git (`git log --all -- docs/arch-migration-audit.md`).

## Что внутри

| Часть | Что |
|---|---|
| Ядро, загрузка, диск | ядро zen (`linuxPackages_zen`), systemd-boot, ESP в `/boot/efi`, btrfs с сабвольюмами (ежемесячный scrub, ежечасные снимки `/home` через btrbk), zram вместо раздела подкачки, `/tmp` в tmpfs |
| Nix | flakes без каналов, `nh` для сборки и еженедельной чистки, дедупликация store по таймеру, `min-free`/`max-free`, `,` (comma) с готовой базой nix-index |
| Графика | Intel рисует всё, NVIDIA просыпается по `nvidia-offload` |
| Вход | greetd + tuigreet; Num Lock включён с загрузки (консоли и dwl) |
| Рабочий стол | dwl 0.9 с патчами (лейаут btrtile как в bspwm, отступы, индикатор раскладки), dwlb + `dwl-status`, fuzzel (лаунчер, история буфера, power-меню), swaylock + swayidle, mako, wpaperd, kanshi, cliphist, wlsunset, playerctld |
| Терминал и shell | ghostty, zsh + starship, единственный редактор — neovim (`vi`, `vim`, `EDITOR`) |
| Тема | Everforest Dark Medium |
| Прочее | PipeWire, Bluetooth (bluetui), Docker, libvirt, Steam |

## Устройство flake

- **inputs:** `nixpkgs` (`nixos-unstable`), `home-manager` и `nix-index-database` (оба с `inputs.nixpkgs.follows = "nixpkgs"`, то есть на той же ревизии nixpkgs). Версии зафиксированы в `flake.lock`.
- **outputs:** только `nixosConfigurations.gigabyte-nixos` (имя совпадает с hostname, поэтому `nh` и `nixos-rebuild` находят её без `#…`).
- `flake.nix` один раз задаёт `username = "nellaror"` и импортирует палитру и шрифт из [`theme/`](theme/README.md); все три передаются во все модули аргументами (`username`, `theme`, `font`) через `specialArgs` (системные) и `home-manager.extraSpecialArgs` (Home Manager). Модули не импортируют тему по относительным путям.
- Home Manager подключён модулем NixOS, а не отдельной командой: `home-manager.useGlobalPkgs` (тот же `pkgs`, что у системы, с `allowUnfree`), `useUserPackages` (пакеты пользователя в `/etc/profiles/per-user/nellaror`), `backupFileExtension = "hm-bak"`. Пересобирается вместе с системой одной командой (`nh os switch`). Модуль Home Manager из `nix-index-database` подключён через `home-manager.sharedModules`.

### Что откуда импортируется

```
flake.nix                                 theme/everforest.nix, theme/font.nix → аргументы theme, font
└─ nixosConfigurations.gigabyte-nixos
   ├─ hosts/system/configuration.nix        система: загрузка, Nix, сеть, звук, редактор, btrfs, пользователь, сервисы
   ├─ hosts/system/hardware-configuration.nix  диски, initrd
   ├─ modules/hardware/nvidia.nix           Intel + NVIDIA (PRIME offload)
   ├─ modules/desktop/dwl.nix               greetd, сессия dwl, polkit, порталы
   └─ home-manager.users.nellaror = home/home.nix   git, xdg (+ nix-index-database.homeModules.nix-index)
      ├─ home/shell.nix                     zsh, starship, fzf, zoxide, comma, bat, lsd, yazi, fastfetch, CLI-утилиты
      ├─ home/dev.nix                       nvim из ~/.dotfiles, LSP и форматтеры, языки, kubectl/helm/terraform
      ├─ home/apps.nix                      GUI и TUI-программы, mpv, программы по умолчанию, игры
      ├─ home/desktop/common.nix            mako, ghostty, cliphist, wpaperd, kanshi, wlsunset, playerctld
      ├─ home/dwl/default.nix               dwl + патчи, dwlb, dwl-status, powermenu, запуск сессии, swaylock, swayidle, fuzzel
      │  ├─ home/dwl/config.h               цвета — заглушки @ключ@ из theme
      │  └─ home/dwl/patches/*.patch
      └─ home/firefox/default.nix           programs.firefox, стартовая страница
```

## Документация

| README | О чём |
|---|---|
| [`hosts/system/README.md`](hosts/system/README.md) | загрузчик, ядро, Nix и nh, сеть, звук, Bluetooth, редактор, Docker/libvirt/vagrant, Steam, шрифты, пользователь, zram, `/tmp`, тестовая VM; диски, btrfs, scrub, снимки `/home`, метки |
| [`modules/hardware/README.md`](modules/hardware/README.md) | NVIDIA: PRIME offload, `nvidia-offload`, busId, внешние мониторы |
| [`modules/desktop/README.md`](modules/desktop/README.md) | greetd + tuigreet, `dwl-session.target`, polkit, порталы, PAM для swaylock |
| [`home/README.md`](home/README.md) | разбиение на `home.nix` / `shell.nix` / `dev.nix` / `apps.nix`; zsh и starship, git, CLI-утилиты, comma, nvim из `~/.dotfiles`, LSP из Nix, программы по умолчанию, пакеты |
| [`home/dwl/README.md`](home/dwl/README.md) | **рабочий стол**: запуск сессии, все горячие клавиши, лейауты, панель, раскладка, обои, мониторы, блокировка, как менять конфиг, частые проблемы |
| [`home/dwl/patches/README.md`](home/dwl/patches/README.md) | патчи dwl: откуда, что делают, порядок, что делать при поломке |
| [`home/desktop/README.md`](home/desktop/README.md) | mako, ghostty, cliphist, wpaperd, kanshi, wlsunset, playerctld, утилиты Wayland |
| [`theme/README.md`](theme/README.md) | палитра Everforest и шрифт: как попадают в модули и где какой цвет |
| [`Usage.md`](Usage.md) | сборка через nh, сборка мусора, откат, где что менять, игры на NVIDIA, проверка в VM, переустановка |

## Быстрые команды

```bash
cd /etc/nixos

nix flake check                        # проверка вычисления конфигурации
nh os build                            # собрать, не применяя (показывает diff пакетов)
nh os switch                           # собрать и применить
sudo nixos-rebuild switch --rollback   # вернуть предыдущее поколение

nh os switch --update                  # nix flake update + switch
nh clean all --keep 5                  # почистить store сейчас (раз в неделю это делает таймер)
```

`nh` берёт flake из `NH_FLAKE=/etc/nixos`. Без него — `nixos-rebuild build --flake /etc/nixos` и т. д.; hostname совпадает с именем конфигурации, поэтому `#gigabyte-nixos` не нужен.

- Flake видит только файлы, известные git: новый файл (модуль, патч) нужно `git add`, иначе сборка его не найдёт.
- Правки dwl (`home/dwl/config.h`, патчи, `default.nix`) вступают в силу после выхода из dwl (`Win+Shift+Q`) и нового входа.
- После `nix flake update` сначала `nixos-rebuild build`: на unstable часто переименовывают опции и пакеты, а патчи dwl могут перестать применяться ([что делать](home/dwl/patches/README.md#если-патч-перестал-применяться)).
- Вместе с изменениями конфига коммитится и `flake.lock`, чтобы каждая версия конфига соответствовала набору пакетов, с которым её проверяли.

## Где что менять

Таблица типовых правок «что хочу → какой файл» — в [`Usage.md`](Usage.md#где-что-менять).
