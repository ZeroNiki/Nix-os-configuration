# Общие части рабочего стола

`common.nix` — то, что не зависит от композитора: уведомления (`mako`), терминал (`ghostty`), история буфера обмена (`cliphist`), обои (`wpaperd`), профили мониторов (`kanshi`) и утилиты Wayland. Подключается из [`../home.nix`](../home.nix), сам dwl — в [`../dwl`](../dwl/README.md).

Цвета берутся из [`../theme/everforest.nix`](../theme/README.md).

## Уведомления: mako

`services.mako`. Запускается D-Bus-активацией при первом уведомлении (не через `graphical-session.target`).

| Параметр | Значение |
|---|---|
| `default-timeout` | 5000 мс |
| `font` | `JetBrainsMono Nerd Font 11` |
| фон / текст / рамка | `bg0` / `fg` / `green` |
| `progress-color` | `over` `bg2` |
| `urgency=critical` | рамка `red` |

```bash
makoctl dismiss       # закрыть верхнее уведомление
makoctl dismiss -a    # закрыть все
makoctl restore       # вернуть последнее закрытое
```

## Терминал: ghostty

`programs.ghostty` с `enableZshIntegration`. Единственный терминал в системе: `Win+Enter`, клик по блоку сети на панели (`ghostty -e nmtui`), `terminal` в fuzzel.

- Тема — встроенная `Everforest Dark Hard`, фон заменён на `bg0` (Everforest Dark Medium в ghostty нет). Остальные цвета терминала — из темы ghostty, не из `everforest.nix`.
- `JetBrainsMono Nerd Font`, 18, отступы 12 px, мигающий блочный курсор, курсор мыши прячется при наборе, 10000 строк истории, закрытие без подтверждения.
- `shell-integration-features = "cursor,sudo,title"`.
- Переход между сплитами: `Alt+H` / `Alt+J` / `Alt+K` / `Alt+L` (влево / вниз / вверх / вправо).

Настройки перенесены из `~/.dotfiles/.config/ghostty/config` без строки `theme`, сам файл из dotfiles не используется: `~/.config/ghostty/config` генерирует Home Manager.

## История буфера обмена: cliphist

`services.cliphist.enable` создаёт два пользовательских сервиса — `cliphist` (текст) и `cliphist-images` (картинки): `wl-paste --watch` складывает всё скопированное в историю. Запускаются с `graphical-session.target`.

Клавиши для выбора из истории в `config.h` нет. Вручную, через fuzzel:

```bash
cliphist list | fuzzel --dmenu | cliphist decode | wl-copy
cliphist wipe   # очистить историю
```

## Обои: wpaperd

`services.wpaperd`, настройки в `settings.any`: папка `~/Pictures/Wallpapers`, случайная картинка раз в 5 минут, отдельно на каждый монитор, `mode = "center"`. Как управлять и что менять — в [`../dwl/README.md`](../dwl/README.md#обои).

## Мониторы: kanshi

`services.kanshi`, три профиля: `laptop` (только `eDP-1`), `desk` (`eDP-1` + HCS PXG27QV2 справа, 2560×1440@144, масштаб 1) и `external` (`eDP-1` + любой другой монитор справа, масштаб 1). Все вызывают `dwl-status refresh`. Подробно, с добавлением своего профиля, — в [`../dwl/README.md`](../dwl/README.md#мониторы).

## Утилиты

`home.packages` в `common.nix`:

| Пакет | Зачем |
|---|---|
| `grim` | скриншоты: `Print` (все экраны), `Win+Shift+S` (область) |
| `slurp` | выбор области для `Win+Shift+S` |
| `wl-clipboard` | `wl-copy` / `wl-paste`: скриншоты кладутся в буфер обмена |
| `brightnessctl` | яркость: `XF86MonBrightnessUp` / `XF86MonBrightnessDown` |
| `wlr-randr` | список выходов (имена, режимы, масштаб) для профилей kanshi и ручной настройки |

Скриншот в файл, а не в буфер (команды в `config.h` пишут только в буфер):

```bash
grim ~/Pictures/screenshot-$(date +%F-%H%M%S).png
grim -g "$(slurp)" ~/Pictures/area-$(date +%F-%H%M%S).png
```

## Как запускаются сервисы

`cliphist`, `cliphist-images`, `wpaperd` и `kanshi` — `WantedBy=graphical-session.target`, который поднимает `dwl-session.target` при входе в dwl (схема — в [`../dwl/README.md`](../dwl/README.md#как-запускается-сессия)). При выходе из dwl они останавливаются.

```bash
systemctl --user status cliphist cliphist-images wpaperd kanshi
journalctl --user -b -u wpaperd
```
