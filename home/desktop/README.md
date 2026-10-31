# Общие части рабочего стола

`common.nix` — то, что не зависит от композитора: уведомления (`mako`), терминал (`ghostty`), история буфера обмена (`cliphist`), обои (`wpaperd`), профили мониторов (`kanshi`), ночной режим (`wlsunset`), управление плеерами (`playerctld`) и утилиты Wayland. Подключается из [`../home.nix`](../home.nix), сам dwl — в [`../dwl`](../dwl/README.md).

Цвета и шрифт — аргументы `theme` и `font` из [`theme/`](../../theme/README.md).

## Уведомления: mako

`services.mako`. Запускается D-Bus-активацией при первом уведомлении (не через `graphical-session.target`).

| Параметр | Значение |
|---|---|
| `default-timeout` | 5000 мс |
| `font` | `Terminess Nerd Font 16px` (в пикселях, см. [`theme`](../../theme/README.md#шрифт)) |
| фон / текст / рамка | `bg0` / `fg` / `green` |
| `progress-color` | `over` `bg2` |
| `urgency=critical` | рамка `red` |
| `mode=do-not-disturb` | `invisible=1`: в режиме «не беспокоить» уведомления не показываются (но копятся, `makoctl history`) |
| `mode=do-not-disturb urgency=critical` | `invisible=0`: критические видны и в этом режиме |

Секции в файле идут по алфавиту, и вторая `mode=…` оказывается ниже первой, поэтому для критических побеждает она.

| Клавиши | Действие |
|---|---|
| `Win+N` | закрыть верхнее уведомление (`makoctl dismiss`) |
| `Win+Shift+N` | «не беспокоить» вкл/выкл (`makoctl mode -t do-not-disturb`); пока включено, на панели серый `󰂛` |

```bash
makoctl dismiss -a    # закрыть все
makoctl restore       # вернуть последнее закрытое
makoctl mode          # текущие режимы
```

## Терминал: ghostty

`programs.ghostty` с `enableZshIntegration`. Единственный терминал в системе: `Win+Enter`, клик по блоку сети на панели (`ghostty -e nmtui`), `terminal` в fuzzel.

- Тема — встроенная `Everforest Dark Hard`, фон заменён на `bg0` (Everforest Dark Medium в ghostty нет). Остальные цвета терминала — из темы ghostty, не из `everforest.nix`.
- `Terminess Nerd Font`, 18 pt (= 24 px при 96 dpi, по которым ghostty считает размер), отступы 12 px, мигающий блочный курсор, курсор мыши прячется при наборе, 10000 строк истории, закрытие без подтверждения.
- `shell-integration-features = "cursor,sudo,title,ssh-env,ssh-terminfo"`. `ssh-terminfo` при первом `ssh` на хост ставит туда terminfo `xterm-ghostty`, `ssh-env` подставляет `TERM=xterm-256color`, если поставить не вышло. Поэтому `TERM` в zsh больше не переопределяется (см. [`../README.md`](../README.md#zsh)).
- Переход между сплитами: `Alt+H` / `Alt+J` / `Alt+K` / `Alt+L` (влево / вниз / вверх / вправо).

Настройки перенесены из `~/.dotfiles/.config/ghostty/config` без строки `theme`, сам файл из dotfiles не используется: `~/.config/ghostty/config` генерирует Home Manager.

## История буфера обмена: cliphist

`services.cliphist.enable` создаёт два пользовательских сервиса — `cliphist` (текст) и `cliphist-images` (картинки): `wl-paste --watch` складывает всё скопированное в историю. Запускаются с `graphical-session.target`.

`Win+V` — история в fuzzel: выбранная запись снова попадает в буфер обмена, `Esc` оставляет буфер как есть (команда в `config.h`):

```bash
s=$(cliphist list | fuzzel --dmenu --prompt 'clip: ') && printf '%s\n' "$s" | cliphist decode | wl-copy
cliphist wipe   # очистить историю
```

## Обои: wpaperd

`services.wpaperd`, настройки в `settings.any`: папка `~/Pictures/Wallpapers`, случайная картинка раз в 5 минут, отдельно на каждый монитор, `mode = "center"`. Как управлять и что менять — в [`../dwl/README.md`](../dwl/README.md#обои).

## Мониторы: kanshi

`services.kanshi`, три профиля: `laptop` (только `eDP-1`), `desk` (`eDP-1` + HCS PXG27QV2 справа, 2560×1440@144, масштаб 1) и `external` (`eDP-1` + любой другой монитор справа, масштаб 1). Все вызывают `dwl-status refresh`. Подробно, с добавлением своего профиля, — в [`../dwl/README.md`](../dwl/README.md#мониторы).

## Ночной режим: wlsunset

`services.wlsunset`: от заката до рассвета экран теплее (4000 K, днём 6500 K), с плавным переходом в сумерках. Время заката и рассвета считается по координатам Ташкента (`latitude = 41.3`, `longitude = 69.3`, как `time.timeZone`). Работает через `wlr-gamma-control`, который dwl поддерживает.

```bash
systemctl --user stop wlsunset    # выключить до следующего входа
systemctl --user start wlsunset
```

## Плееры: playerctld

`services.playerctld` — демон, который запоминает, какой MPRIS-плеер был активен последним. Без него `playerctl` берёт первый попавшийся; с ним медиа-клавиши (`playerctl play-pause`, `next`, `previous`, см. [`../dwl/README.md`](../dwl/README.md#медиа-клавиши)) идут в тот плеер, с которым работали последним: Spotify, mpv (со скриптом `mpris`, `programs.mpv` в `apps.nix`), Firefox.

```bash
playerctl -l              # видимые плееры
playerctl metadata        # что играет
```

## Утилиты

`home.packages` в `common.nix`:

| Пакет | Зачем |
|---|---|
| `grim` | скриншоты: `Print` (все экраны), `Win+Shift+S` (область) |
| `slurp` | выбор области для `Win+Shift+S` |
| `wl-clipboard` | `wl-copy` / `wl-paste`: скриншоты кладутся в буфер обмена |
| `brightnessctl` | яркость: `XF86MonBrightnessUp` / `XF86MonBrightnessDown` |
| `wlr-randr` | список выходов (имена, режимы, масштаб) для профилей kanshi и ручной настройки |
| `playerctl` | медиа-клавиши, через `playerctld` |

Скриншот в файл, а не в буфер (команды в `config.h` пишут только в буфер):

```bash
grim ~/Pictures/screenshot-$(date +%F-%H%M%S).png
grim -g "$(slurp)" ~/Pictures/area-$(date +%F-%H%M%S).png
```

## Как запускаются сервисы

`cliphist`, `cliphist-images`, `wpaperd`, `kanshi` и `wlsunset` — `WantedBy=graphical-session.target`, который поднимает `dwl-session.target` при входе в dwl (схема — в [`../dwl/README.md`](../dwl/README.md#как-запускается-сессия)). При выходе из dwl они останавливаются. `playerctld` от сессии не зависит: он `WantedBy=default.target` и работает всё время, пока пользователь залогинен.

```bash
systemctl --user status cliphist cliphist-images wpaperd kanshi wlsunset playerctld
journalctl --user -b -u wpaperd
```
