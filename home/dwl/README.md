# Рабочий стол DWL

Композитор [dwl](https://codeberg.org/dwl/dwl) 0.9 со всем, что нужно для сессии: `config.h` (клавиши, лейауты, цвета, правила окон, клавиатура и тачпад), патчи (`patches/`), панель `dwlb` со скриптом статуса `dwl-status`, скрипт яркости `brightness`, power-меню `powermenu`, скрипты запуска `dwl-session` / `dwl-startup`, блокировка экрана `swaylock`, автоблокировка `swayidle` и лаунчер `fuzzel` (всё в `default.nix`).

Системная часть (greetd, порталы, polkit, PAM) — в [`modules/desktop`](../../modules/desktop/README.md), уведомления, терминал, обои и мониторы — в [`home/desktop`](../desktop/README.md), цвета — в [`home/theme`](../theme/README.md), патчи по отдельности — в [`patches/README.md`](patches/README.md).

| Файл | Что в нём |
|---|---|
| `config.h` | Конфиг dwl. Это C, он компилируется в бинарник: после правки нужна пересборка |
| `default.nix` | Сборка dwl с патчами, `dwl-status`, `brightness`, `powermenu`, `dwl-startup`, `dwl-session`, `dwl-session.target`, `swaylock`, `swayidle`, `fuzzel` |
| `patches/` | Патчи к dwl, порядок наложения задан в `default.nix` |

## Как запускается сессия

```
greetd → tuigreet                       modules/desktop/dwl.nix
  │  логин; F3 — выбор сессии (есть одна: dwl)
  ▼
dwl-session                             /etc/profiles/per-user/nellaror/bin/dwl-session
  │  XDG_CURRENT_DESKTOP=dwl, XDG_SESSION_DESKTOP=dwl, XDG_SESSION_TYPE=wayland
  │  ~/.local/state/dwl.log → dwl.log.old, stderr dwl → новый dwl.log
  ▼
dwl -s dwl-startup                      stdout dwl (теги, лейаут, заголовок) → stdin dwl-startup
  ▼
dwl-startup
  ├─ dbus-update-activation-environment --systemd WAYLAND_DISPLAY DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE
  ├─ systemctl --user start dwl-session.target
  │     └─ BindsTo → graphical-session.target, его WantedBy-сервисы:
  │          ├─ polkit-agent.service                       modules/desktop/dwl.nix
  │          ├─ swayidle.service                           home/dwl/default.nix
  │          ├─ cliphist.service, cliphist-images.service  home/desktop/common.nix
  │          ├─ wpaperd.service                            home/desktop/common.nix
  │          ├─ kanshi.service                             home/desktop/common.nix
  │          └─ wlsunset.service                           home/desktop/common.nix
  ├─ через 1 с, в фоне: dwl-status | dwlb -status-stdin all
  └─ exec dwlb …                        панель, читает статус dwl из stdin
```

`mako` и порталы (`xdg-desktop-portal-wlr`, `-gtk`) не входят в target: они запускаются D-Bus-активацией при первом обращении, для этого `dwl-startup` и передаёт им окружение сессии.

**Выход** (`Win+Shift+Q` или `Ctrl+Alt+Backspace`): `dwl-session` ждёт завершения dwl, потом делает `systemctl --user stop dwl-session.target` и `systemctl --user unset-environment WAYLAND_DISPLAY DISPLAY`. `graphical-session.target` имеет `StopWhenUnneeded`, а сервисы выше — `PartOf` него, поэтому они останавливаются вместе с ним и не висят с мёртвым `WAYLAND_DISPLAY` до следующего входа. greetd снова показывает tuigreet.

Из tty без greeter сессию запускают той же командой:

```bash
dwl-session
```

Проверить, что всё поднялось:

```bash
systemctl --user list-dependencies graphical-session.target
systemctl --user status dwl-session.target swayidle wpaperd kanshi cliphist polkit-agent
```

## Горячие клавиши

`Win` — клавиша с логотипом (`MODKEY` = `WLR_MODIFIER_LOGO`). ЛКМ / СКМ / ПКМ — левая, средняя, правая кнопки мыши. Таблица собрана из `keys[]` и `buttons[]` в `config.h`: 83 привязки плюс 12 `CHVT`.

Все привязки работают и на русской раскладке: `patches/keys-latin.patch` ищет клавишу всегда в первой (латинской) раскладке. Совпадение проверяется для обычного и Shift-уровня клавиши, поэтому `Win+Shift+Q` записан в `config.h` как `XKB_KEY_q` с `SHIFT`, а не как `XKB_KEY_Q`.

### Окна

| Клавиши | Действие |
|---|---|
| `Win+J` / `Win+K` | Фокус на следующее / предыдущее окно в стеке |
| `Win+Q` | Закрыть окно |
| `Win+Shift+Enter` | `zoom`: поднять окно на место мастера (в `tile`). В btrtile видимого эффекта нет: расположение задаёт дерево, а не порядок окон |
| `Win+Shift+Space` | Сделать окно плавающим / вернуть в раскладку |
| `Win+E` | Полный экран вкл/выкл |
| `Win+Shift+Up` / `Win+Shift+Down` / `Win+Shift+Left` / `Win+Shift+Right` | btrtile: поменять окно местами с ближайшим соседом в этом направлении |
| `Win+ЛКМ` | Тащить окно. Плиточное в btrtile: на время перетаскивания становится плавающим, а после отпускания встаёт в дерево рядом с окном под курсором. В остальных лейаутах окно становится плавающим и остаётся им |
| `Win+СКМ` | Плавающее / в раскладку (как `Win+Shift+Space`) |
| `Win+ПКМ` | Тащить для изменения размера. Плиточное в btrtile: двигает ближайшую границу (вертикальную или горизонтальную, смотря по тому, куда больше сдвинута мышь), окно остаётся в дереве. Плавающее, а также любое окно в других лейаутах: становится плавающим и меняет размер за правый нижний угол |

### Лейауты

| Клавиши | Действие |
|---|---|
| `Win+W` | btrtile `[B]`, по умолчанию на каждом мониторе |
| `Win+T` | tile `[]=` |
| `Win+F` | floating `><>` |
| `Win+M` | monocle `[M]`, на панели показывается как `[N]`, где N — число окон |
| `Win+H` / `Win+L` | btrtile: сдвинуть ближайшую вертикальную границу у окна в фокусе влево / вправо на 5 %. tile: ширина мастера, `mfact` −/+ 0.05 (от 0.1 до 0.9) |
| `Win+Ctrl+K` / `Win+Ctrl+J` | btrtile: сдвинуть ближайшую горизонтальную границу вверх / вниз на 5 % |
| `Win+Ctrl+T` | btrtile: повернуть деление, в котором стоит окно (рядом ↔ друг над другом) |
| `Win+Ctrl+Y` | btrtile: отзеркалить деление (половины меняются местами, пропорция сохраняется) |
| `Win+I` / `Win+D` | tile: +1 / −1 окно в мастер-области |

### Теги

У каждого монитора свои 9 тегов. На панели видны только занятые теги и текущий (`-hide-vacant-tags`).

| Клавиши | Действие |
|---|---|
| `Win+[1–9]` | Перейти на тег |
| `Win+Ctrl+[1–9]` | Добавить тег к видимым / убрать (показать несколько тегов сразу) |
| `Win+Shift+[1–9]` | Перенести окно на тег |
| `Win+Ctrl+Shift+[1–9]` | Добавить окну тег / убрать (окно видно на нескольких тегах) |
| `Win+0` | Показать все теги |
| `Win+Shift+0` | Дать окну все теги (видно везде) |
| `Win+Tab` | Вернуться к предыдущему набору тегов |

### Мониторы

| Клавиши | Действие |
|---|---|
| `Win+,` / `Win+.` | Фокус на монитор слева / справа |
| `Win+Shift+,` / `Win+Shift+.` | Перенести окно на монитор слева / справа |

### Запуск программ

| Клавиши | Действие |
|---|---|
| `Win+Enter` | Терминал: `ghostty --gtk-single-instance=false` |
| `Win+P` | Лаунчер `fuzzel` |
| `Win+V` | История буфера обмена (cliphist) в fuzzel: выбранное снова в буфере, `Esc` — ничего не менять |
| `Win+Shift+S` | Скриншот области: `grim -g "$(slurp)" - \| wl-copy`, результат в буфере обмена |
| `Print` | Скриншот всех экранов: `grim - \| wl-copy`, результат в буфере обмена |

### Система

| Клавиши | Действие |
|---|---|
| `Win+B` | Показать / скрыть панель на всех мониторах (`dwlb -toggle-visibility all`) |
| `Win+Shift+L` | Заблокировать экран (`swaylock -f`) |
| `Win+X` | Power-меню в fuzzel: lock / suspend / reboot / poweroff (`powermenu`) |
| `Win+N` | Закрыть верхнее уведомление (`makoctl dismiss`) |
| `Win+Shift+N` | «Не беспокоить» вкл/выкл (`makoctl mode -t do-not-disturb`), на панели `󰂛` |
| `Win+Shift+Q` | Выйти из dwl (завершение сессии) |
| `Ctrl+Alt+Backspace` | То же, выйти из dwl |

`Ctrl+Alt+F1` … `Ctrl+Alt+F12` — переключение на виртуальную консоль (`chvt`); вернуться в сессию — на ту консоль, где она запущена.

`Win+Space` — переключение раскладки EN/RU. Это не привязка dwl, а опция xkb `grp:win_space_toggle` (`xkb_rules` в `config.h`).

### Медиа-клавиши

| Клавиши | Действие |
|---|---|
| `XF86AudioRaiseVolume` | Громкость +5 %, не выше 100 % (`wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+`) |
| `XF86AudioLowerVolume` | Громкость −5 % |
| `XF86AudioMute` | Звук вкл/выкл |
| `XF86AudioMicMute` | Микрофон вкл/выкл (`wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle`); выключенный — красный `󰍭` на панели |
| `XF86AudioPlay` / `XF86AudioPause` | Пауза / воспроизведение (`playerctl play-pause`) |
| `XF86AudioNext` / `XF86AudioPrev` | Следующий / предыдущий трек |
| `XF86AudioStop` | Стоп |
| `XF86MonBrightnessUp` / `XF86MonBrightnessDown` | Яркость ±5 % экрана ноутбука и внешних мониторов вместе (`brightness up` / `brightness down`, см. [Яркость](#яркость)) |
| `Win+]` / `Win+[` | Яркость ±5 % только внешних мониторов (`brightness ext up` / `brightness ext down`); на русской раскладке это `Ъ` / `Х` |

Клавиши громкости, микрофона и `Win+Shift+N` после команды вызывают `dwl-status refresh` (макрос `STATUS()` в `config.h`), поэтому панель показывает новое значение сразу. `brightness` вызывает его сам.

`playerctl` идёт через `playerctld` — в плеер, активный последним (Spotify, mpv, Firefox), см. [`home/desktop`](../desktop/README.md#плееры-playerctld). Если на клавиатуре ноутбука нет отдельных медиа-клавиш или клавиши микрофона, проверить, что она шлёт, можно `wev` (`, wev`).

В `axes[]` остался пример из `config.def.h`: `Win` + колесо мыши запускает несуществующие `volume-up_EXAMPLE` / `volume-down_EXAMPLE`, то есть ничего не делает.

## Лейауты

Порядок в `layouts[]`: `[B]` btrtile (первый — значит, по умолчанию: на него указывает `monrules[]`), `[]=` tile, `><>` floating, `[M]` monocle.

### btrtile (`Win+W`)

Бинарное дерево, как в bspwm (`patches/btrtile.patch` + `patches/btrtile-local.patch`). Настройки — в начале `config.h`:

| Параметр | Значение | Смысл |
|---|---|---|
| `use_active_for_splits` | `1` | делится окно в фокусе, а не окно под курсором |
| `split_width_multiplier` | `1.0f` | окно шире, чем высота × 1.0, делится вертикальной границей (новое встаёт рядом), иначе — горизонтальной (новое встаёт снизу) |
| `force_split` | `2` | новое окно всегда справа / снизу |
| `preserve_split` | `1` | деление сохраняет направление, которое получило при создании, даже если потом область поменяла форму |
| `resize_interval_ms` | `16` | как часто применяется ресайз мышью (`Win+ПКМ`) |

- **Новое окно** делит окно в фокусе пополам по длинной стороне и встаёт справа или снизу от него. Если на текущем теге плиточных окон нет, оно занимает весь экран.
- **Закрытие окна:** его деление исчезает, а соседняя ветка (одно окно или целое поддерево) занимает всю освободившуюся область. Пропорции остальных делений не меняются.
- **Размеры:** `Win+H` / `Win+L` двигают ближайшую вертикальную границу у окна в фокусе на 5 % ширины деления, `Win+Ctrl+K` / `Win+Ctrl+J` — горизонтальную. Сначала берётся деление, в котором окно стоит с той стороны, что растёт (`Win+L` — окно слева от границы, и оно расширяется), а если такого нет — деление с другой стороны. Пропорция ограничена 5–95 %. Мышью: `Win+ПКМ` и тянуть.
- **Перестановка:** `Win+Shift+стрелки` меняют окно местами с ближайшим соседом в эту сторону (по центрам окон), `Win+Ctrl+T` поворачивает деление, `Win+Ctrl+Y` меняет его половины местами. `Win+ЛКМ` переносит окно в другое место дерева.
- **Плавающее окно** (`Win+Shift+Space`, `rules[]`, диалоги) убирается из дерева. При возврате в раскладку оно делит последнее окно в фокусе.
- Дерево одно на монитор, общее для всех тегов. Ветки, в которых на текущем теге нет видимых окон, схлопываются, поэтому каждый тег выглядит как отдельная раскладка.
- Отступы: `gappx` = 8 px от краёв экрана и между окнами (`btrtile-local.patch` берёт его из `gaps.patch`), рамка `borderpx` = 2 px.

Под другими лейаутами дерево не перестраивается: `Win+H` / `Win+L` там меняют `mfact` (функция `setfact` из `btrtile-local.patch`).

### tile (`Win+T`)

Классический dwm: мастер-область слева (`mfact` = 0.55, `nmaster` = 1 из `monrules[]`), остальные окна стопкой справа. `Win+H` / `Win+L` — ширина мастера, `Win+I` / `Win+D` — число окон в мастере, `Win+Shift+Enter` — поднять окно в мастер. С отступами `gappx` (`gaps.patch`).

### floating (`Win+F`)

Без раскладки: все окна плавающие, двигаются `Win+ЛКМ`, меняют размер `Win+ПКМ`. Прилипают к краям монитора ближе 32 px (`snap`).

### monocle (`Win+M`)

Каждое окно на весь монитор (минус `gappx`), сверху окно в фокусе, переключение `Win+J` / `Win+K`.

### Плавающие окна по правилам

`rules[]` в `config.h` делает окна плавающими при открытии. Совпадение — по подстроке в `app_id` и в заголовке:

| `app_id` | Заголовок | Окно |
|---|---|---|
| `firefox` | `Picture-in-Picture` | Картинка в картинке Firefox |
| `org.telegram.desktop` | `Media viewer` | Просмотр медиа в Telegram |
| `org.keepassxc.KeePassXC` | `Unlock Database` | Окно разблокировки KeePassXC |

Диалоги, которые сами просят плавающий режим, становятся плавающими и без правил. Узнать `app_id` окна можно во вложенном dwl (см. [Тест без выхода из сессии](#тест-без-выхода-из-сессии)): он печатает статус в терминал, и строка `<монитор> appid <id>` относится к окну в фокусе.

## Панель dwlb

Запускается из `dwl-startup` на всех мониторах, сверху, шрифтом `JetBrainsMono Nerd Font` 11. На новом мониторе бар появляется сам. Слева направо:

- **теги** — только занятые и текущий; текущий — зелёный фон, срочный (urgent) — красный;
- **символ лейаута** — `[B]`, `[]=`, `><>`, `[M]` (в monocle — `[N]`, число окон);
- **заголовок** окна в фокусе;
- **статус** справа — вывод `dwl-status`.

Клики по тегам и символу лейаута не работают: dwlb запущен без `-ipc`, для этого dwl нужен патч `dwl-ipc`, которого здесь нет. Работают только клики, заданные в тексте статуса (`^lm(…)`).

### Блоки `dwl-status`

| Блок | Что показывает | Откуда берёт | ЛКМ |
|---|---|---|---|
| «Не беспокоить» | серый `󰂛`, только пока режим включён | `makoctl mode` | — |
| Раскладка | `EN` / `RU` | файл `$XDG_RUNTIME_DIR/dwl-kblayout` (пишет dwl) | — |
| Сеть | Ethernet: `eth`. Wi-Fi: значок уровня сигнала (5 ступеней), SSID (до 12 символов), сигнал в %. Нет подключения: красный значок | `nmcli`; список Wi-Fi из кеша NetworkManager (`--rescan no`), сканирования нет | `ghostty -e nmtui` |
| Bluetooth | Нет адаптера: блока нет. Выключен: серый значок. Включён без устройств: зелёный значок. Одно устройство: его имя (до 12 символов). Несколько: их число | `bluetoothctl` (с `timeout 2`) | `blueman-manager` |
| Громкость | `N%`; без звука — серым. Если микрофон выключен, рядом красный `󰍭` | `wpctl get-volume @DEFAULT_AUDIO_SINK@` и `@DEFAULT_AUDIO_SOURCE@` | — |
| Яркость | `󰃠 N%` экрана ноутбука; при подключённом внешнем мониторе ещё `󰍹 N%` — значение, которое `brightness` выставил ему последним (монитор не опрашивается: ddcutil слишком медленный). Пока яркость монитора не меняли с этого входа, его части нет | `brightnessctl -m -c backlight`, файл `$XDG_RUNTIME_DIR/brightness/ext` | — |
| Батарея | значок по уровню (шаг 10 %) и `N%`; при зарядке свой значок; 15 % и меньше — красным | `/sys/class/power_supply/BAT0` | — |
| Часы | `Sun 25 Oct  17:40` (формат `%a %d %b  %H:%M`) | `date` | — |

Пустые блоки пропускаются, между блоками 4 пробела.

**Обновление:** строка перерисовывается раз в 10 секунд и сразу по сигналу `SIGUSR1`. Сигнал шлют `dwl-status refresh` (клавиши громкости, `brightness`, профили kanshi) и сам dwl при смене раскладки. Сеть и Bluetooth (медленные `nmcli` и `bluetoothctl`) опрашиваются не чаще раза в 10 секунд, а при перерисовке по сигналу берутся последние значения, поэтому EN/RU, громкость и яркость меняются мгновенно. PID процесса лежит в `$XDG_RUNTIME_DIR/dwl-status.pid`.

```bash
dwl-status refresh   # перерисовать панель сейчас
```

### Как добавить свой блок

Всё в `home/dwl/default.nix`, в `text` у `dwl-status`:

1. Написать функцию, которая печатает текст блока или ничего (тогда блок скрыт). Для цвета есть `icon <значок>` (значок цветом акцента) и разметка dwlb `^fg(цвет)…^fg()`; `^` в произвольном тексте надо удваивать (это делает `shorten <текст> <длина>`).
2. Добавить её вызов в список `for block in …` на нужное место.
3. Если нужна программа, добавить пакет в `runtimeInputs`.
4. Клик: обернуть текст в `^lm(команда)…^lm()`, как у сети.
5. Медленную команду опрашивать раз в 10 секунд, как `net` / `bt`, а не на каждой перерисовке.

Текст скрипта — Nix-строка `''…''`: `${c.accent}` и т. п. подставляет Nix, а `${…}` самого bash пишется как `''${…}`. Пример — средняя загрузка:

```bash
      load() {
        local l
        read -r l _ </proc/loadavg
        printf '^fg(${c.accent})load^fg() %s' "$l"
      }
```

```bash
        for block in "$(kblayout)" "$net" "$bt" "$(load)" "$(volume)" "$(backlight)" "$(battery)" "$(date '+%a %d %b  %H:%M')"; do
```

## Яркость

Скрипт `brightness` (`home/dwl/default.nix`) меняет подсветку экрана ноутбука и внешних мониторов. Лежит рядом с `dwl-status`, потому что вызывается из `config.h` и обновляет панель.

```bash
brightness up | down        # ±5 % ноутбуку и всем внешним мониторам
brightness set 40           # 40 % везде
brightness ext up | down    # только внешние мониторы (Win+] / Win+[)
brightness ext set 70
brightness detect           # забыть кеш мониторов (после включения DDC/CI в меню монитора)
```

- **Ноутбук:** `brightnessctl -c backlight`, сразу. Не ниже 1 % от максимума (`--min-value`), чтобы экран не погас совсем.
- **Внешние мониторы:** по DDC/CI (VCP-код `10`, яркость) через `ddcutil`, в фоне. Нужны `hardware.i2c.enable` и группа `i2c` ([`hosts/system`](../../hosts/system/README.md#яркость-внешнего-монитора-ddcci)). Если ни один выход, кроме `eDP`/`LVDS`/`DSI`, не подключён (`/sys/class/drm/card*-*/status`), ddcutil не запускается вовсе, задержки нет.
- **Поиск монитора:** номера шин `/dev/i2c-N` берутся из `ddcutil detect --terse` (только блоки `Display N`, `Invalid display` пропускаются) и кешируются в `$XDG_RUNTIME_DIR/brightness/displays` вместе со списком подключённых разъёмов. Изменился список (монитор подключили, отключили, сменили разъём) — при следующем нажатии `detect` выполняется заново, независимо от kanshi. Не ответил монитор на `getvcp`/`setvcp` — кеш тоже сбрасывается.
- **Фон и блокировка:** нажатие только дописывает свой шаг в `$XDG_RUNTIME_DIR/brightness/pending` (`ABS REL`: значение из `set` и сумма шагов после него, под коротким `flock`) и запускает фоновый обработчик. Обработчик берёт `flock -n` на `worker.lock`; если он занят, процесс сразу выходит — уже работающий подхватит изменение. Работающий забирает всю сумму, один раз читает текущую яркость (`getvcp 10`), выставляет итоговое значение (`setvcp 10 N --noverify`, без проверки чтением) и повторяет, пока `pending` не пуст. Двадцать быстрых нажатий дают два-три вызова `setvcp`, а не двадцать; одинаковое значение (упёрлись в 100 %) не отправляется.
- В конце — `dwl-status refresh`: сразу после нажатия (ноутбук) и ещё раз, когда монитор получил новое значение (`brightness/ext`).

**Монитор не реагирует:**

```bash
ddcutil detect          # виден ли монитор: блок "Display 1" с "I2C bus: /dev/i2c-N"
ddcutil getvcp 10       # текущая яркость
ls -l /dev/i2c-*        # группа i2c; если устройств нет — модуль i2c-dev не загружен
id                      # есть ли группа i2c (после добавления нужен перелогин/перезагрузка)
```

- `Invalid display` / `DDC communication failed` — в меню самого монитора выключен DDC/CI, включить и выполнить `brightness detect`.
- Монитор на разъёме NVIDIA (на этом ноутбуке HDMI-A-2; номер `cardN` у разъёма может меняться между загрузками, скрипт на него не опирается): DDC через проприетарный драйвер работает, но бывает медленным или теряет команды. Проверить `ddcutil getvcp 10 --sleep-multiplier 2`; если помогает — дописать `--sleep-multiplier=2` в `ddc=(ddcutil)` в скрипте. В загрузке `intel-only` NVIDIA выключена, монитор на её разъёмах не работает вовсе.
- Вывод `ddcutil` при ошибках скрипт скрывает; запускать команды выше вручную.

## Раскладка EN/RU

- Раскладки `us,ru`, переключение `Win+Space` (`xkb_rules` в `config.h`: `.layout = "us,ru"`, `.options = "grp:win_space_toggle"`). Раскладка общая для всех окон.
- `patches/kblayout-local.patch`: смена раскладки приходит в dwl событием модификаторов. Если активная группа xkb изменилась, dwl пишет имя из `kblayout_names[]` (`EN`, `RU`, в порядке `.layout`) в `$XDG_RUNTIME_DIR/dwl-kblayout` (через временный файл и `rename`, чтобы не прочитать недописанный файл), берёт PID из `$XDG_RUNTIME_DIR/dwl-status.pid` и шлёт ему `SIGUSR1`, если `/proc/<pid>/comm` — `dwl-status`. При старте dwl сразу пишет первую раскладку.
- `dwl-status` по сигналу перерисовывает строку, функция `kblayout` читает файл.

```
Win+Space → xkb меняет группу → dwl: kblayout()
   ├─ $XDG_RUNTIME_DIR/dwl-kblayout ← "RU"
   └─ kill -USR1 $(cat $XDG_RUNTIME_DIR/dwl-status.pid)
                     └─ dwl-status: перерисовка → dwlb
```

Добавить третью раскладку: дописать её в `.layout` и имя в `kblayout_names[]` в том же порядке (без имени в панели будет название раскладки из xkb).

## Обои

Сервис `wpaperd` (`services.wpaperd` в `home/desktop/common.nix`):

- картинки из `~/Pictures/Wallpapers`, случайная (`sorting = "random"`), новая каждые 5 минут (`duration = "5m"`), отдельно для каждого монитора, включая подключённые позже;
- `mode = "center"`: картинка масштабируется, чтобы закрыть экран, лишнее обрезается, без растяжения;
- пустая папка — wpaperd ждёт файлов; нет папки — работает без обоев (виден `rootcolor` из `config.h`), пока не перезапустить сервис.

```bash
wpaperctl next              # следующая картинка
wpaperctl previous          # предыдущая
wpaperctl toggle-pause      # остановить / продолжить смену
wpaperctl get               # какие картинки сейчас стоят
systemctl --user restart wpaperd
```

Поменять папку, интервал, порядок или режим: `settings.any` в `home/desktop/common.nix`, затем `sudo nixos-rebuild switch --flake /etc/nixos#gigabyte-nixos`. `any` — настройки для всех мониторов; для отдельного монитора можно добавить секцию с его именем (`settings."eDP-1" = { … };`).

## Мониторы

- dwl сам включает и ставит новый монитор по `monrules[]` (одно правило для всех: масштаб 1, btrtile, позиция — автоматически).
- `kanshi` (`services.kanshi` в `home/desktop/common.nix`) применяет профили:

| Профиль | Выходы |
|---|---|
| `laptop` | `eDP-1` в `0,0` |
| `desk` | `eDP-1` 1920×1200@165 в `0,0` + HCS PXG27QV2 (`criteria = "HCS PXG27QV2 0x00000001"`, любой разъём) 2560×1440@144 справа в `1920,0`; масштаб 1 у обоих |
| `external` | `eDP-1` в `0,0` + любой другой выход (`*`) справа в `1920,0`, масштаб 1, режим по умолчанию для монитора |

Экран ноутбука — `eDP-1`, 1920×1200, отсюда `1920` в позиции внешнего. `desk` стоит перед `external`, иначе `*` перехватил бы и этот монитор. Режим по умолчанию (preferred) у PXG27QV2 — 60 Гц, поэтому частота задана явно; у `eDP-1` тоже, чтобы не съехать на 60. Все профили после применения вызывают `dwl-status refresh`: dwlb ставит бар на новый монитор сам, но текст статуса там появляется только со следующей строкой `dwl-status`.

Частота в `mode` — в том виде, как её печатает `wlr-randr`, округлённая до тысячных: kanshi хранит частоты в мГц и из режимов с нужным разрешением берёт ближайший, отличающийся меньше чем на 0,05 Гц. `2560x1440@144.002Hz` — это ровно `144.001999` (144002 мГц), `@144Hz` тоже попал бы в него (разница 2 мГц), а 120 и 60 не совпадут никогда. Если подходящего режима нет, kanshi пишет в журнал `doesn't support mode` и профиль не применяется.

Adaptive Sync (VRR) в `desk` не включён: `drm_info` показывает у `HDMI-A-2` на NVIDIA `vrr_capable = 0`. dwl 0.9 (wlroots 0.20) передаёт `adaptive_sync` из kanshi в драйвер, но для разъёма без VRR wlroots отклоняет всю конфигурацию целиком, то есть с `adaptiveSync = true` не применились бы ни 144 Гц, ни масштаб. Проверить разъём (монитор по другому кабелю/порту может выглядеть иначе):

```bash
nix shell nixpkgs#drm_info -c drm_info /dev/dri/card1 | grep -B2 -A1 vrr_capable
```

Если там `vrr_capable` = 1 — добавить `adaptiveSync = true;` к монитору в `desk`; при мерцании убрать строку или разово `wlr-randr --output HDMI-A-2 --adaptive-sync disabled`.

Чего профили не покрывают: два внешних монитора одновременно (ни один профиль не совпадёт, kanshi ничего не меняет, мониторы ставит dwl) и закрытую крышку (профиля без `eDP-1` нет, экран ноутбука остаётся включённым).

Добавить профиль для конкретного монитора:

```bash
wlr-randr   # имена выходов (DP-1, HDMI-A-2, …), строка описания в кавычках, режимы, масштаб
```

В `services.kanshi.settings` добавить профиль **перед** `external`: kanshi проверяет профили по порядку и берёт первый, у которого совпали все выходы, а `*` в `external` совпадает с любым монитором. В `criteria` можно указать имя выхода или строку «производитель модель серийный номер» из `wlr-randr`, тогда профиль не зависит от разъёма. Пример (монитор и режим условные):

```nix
      {
        profile.name = "desk";
        profile.exec = "dwl-status refresh";
        profile.outputs = [
          { criteria = "eDP-1"; status = "disable"; }
          { criteria = "Dell Inc. DELL U2720Q XXXXXXX"; position = "0,0"; scale = 1.5; mode = "3840x2160@60Hz"; }
        ];
      }
```

Затем `sudo nixos-rebuild switch --flake /etc/nixos#gigabyte-nixos`. Без пересборки:

```bash
kanshictl switch external         # применить профиль вручную
kanshictl reload                  # перечитать конфиг kanshi (текущий профиль остаётся, пока он подходит)
systemctl --user restart kanshi
wlr-randr --output HDMI-A-2 --pos 1920,0 --mode 2560x1440@144.001999Hz --scale 1   # разово, до следующего события kanshi
```

Клавиши: `Win+,` / `Win+.` — фокус на монитор, `Win+Shift+,` / `Win+Shift+.` — перенести окно. У каждого монитора свои теги, лейаут и дерево btrtile.

Часть разъёмов ноутбука подключена к NVIDIA, а в загрузке `intel-only` она отключена — см. [`modules/hardware`](../../modules/hardware/README.md#внешний-монитор-и-видеокарта).

## Блокировка экрана

`Win+Shift+L` → `swaylock -f` (пакет `swaylock-effects`, настройки в `programs.swaylock`, PAM-запись `security.pam.services.swaylock` в `modules/desktop/dwl.nix` — без неё пароль не проверится). `-f`: команда возвращается сразу после блокировки.

Вид: размытый скриншот рабочего стола с виньеткой, внутри кольца часы `ЧЧ:ММ` и дата, кольцо видно ещё до первого нажатия. Во время ввода под кольцом серым показана раскладка. Пустой пароль игнорируется, число неудачных попыток выводится.

| Цвет кольца | Состояние |
|---|---|
| тёмно-серое (`bg1`) | ожидание ввода; при наборе на кольце вспыхивает зелёный сегмент, при Backspace — красный |
| серое (`grey1`) | ввод стёрт |
| зелёное (`green`) | пароль проверяется |
| красное (`red`) | неверный пароль (текст тоже красный) |
| жёлтое (`yellow`) | включён Caps Lock |

## Простой и сон

`services.swayidle` (в `default.nix`, стартует с `graphical-session.target`):

| Когда | Что |
|---|---|
| 5 минут без ввода | блокировка (`swaylock -f`) |
| 10 минут без ввода | мониторы выключаются (`wlopm --off '*'`, протокол wlr-output-power-management), любое движение или клавиша включают их |
| перед сном (`before-sleep`) | блокировка: крышка, `systemctl suspend`, power-меню. `-w` заставляет logind ждать, пока `swaylock -f` заблокирует экран, поэтому ноутбук не просыпается разблокированным |
| после сна (`after-resume`) | мониторы включаются |
| `loginctl lock-session` (`lock`) | блокировка |

Если экран уже заблокирован, второй swaylock не запускается (`pgrep -x swaylock`). Видео в mpv и Firefox держит idle inhibitor (dwl его поддерживает), пока оно идёт — таймеры не срабатывают. `wlopm` вызывается через маленький скрипт `screens`, чтобы `'*'` не пришлось экранировать внутри `ExecStart`.

Поменять время — `timeouts` в `services.swayidle`. Временно выключить:

```bash
systemctl --user stop swayidle    # до следующего входа или start
journalctl --user -u swayidle
```

## Power-меню

`Win+X` → `powermenu`: fuzzel в режиме dmenu со строками `lock`, `suspend`, `reboot`, `poweroff`. `Esc` — ничего не делать. `suspend` блокирует экран сам, через `before-sleep` у swayidle. Выход из dwl — по-прежнему `Win+Shift+Q`.

## Как менять конфиг

Репозиторий — `/etc/nixos`. dwl не читает конфиг при запуске: `config.h` компилируется в бинарник, поэтому любая правка требует пересборки и перезапуска dwl.

```bash
$EDITOR /etc/nixos/home/dwl/config.h
nixos-rebuild build --flake /etc/nixos#gigabyte-nixos         # проверить, что собирается
sudo nixos-rebuild switch --flake /etc/nixos#gigabyte-nixos   # применить
```

После `switch` запущенный dwl остаётся старым: выйти (`Win+Shift+Q`) и войти снова через tuigreet. Новые файлы (например, новый патч) flake видит только после `git add`.

Логи: `~/.local/state/dwl.log` — stderr dwl и всего, что он запустил; лог прошлого запуска — `~/.local/state/dwl.log.old` (полезен, если dwl упал и пришлось перелогиниться). Уровень логирования — `log_level` в `config.h` (сейчас `WLR_ERROR`).

```bash
less ~/.local/state/dwl.log.old
```

### Тест без выхода из сессии

Вложенный dwl запускается окном внутри текущего. Внешний dwl перехватывает все свои `Win`-привязки, поэтому тестовую сборку собирают с `MODKEY` = `Alt` (замена `WLR_MODIFIER_LOGO` → `WLR_MODIFIER_ALT` в копии `config.h`). Собирается из текущего содержимого рабочей копии с теми же патчами, что в `default.nix` (если меняли список патчей — поправить и здесь):

```bash
nix build --impure -o /tmp/dwl-nested --expr '
let
  repo = /etc/nixos;
  pkgs = (builtins.getFlake (toString repo)).nixosConfigurations.gigabyte-nixos.pkgs;
  patches = map (p: repo + "/home/dwl/patches/${p}")
    [ "gaps.patch" "keys-latin.patch" "btrtile.patch" "btrtile-local.patch" "kblayout-local.patch" ];
in
(pkgs.dwl.override {
  configH = pkgs.runCommand "config.h" { } "sed s/WLR_MODIFIER_LOGO/WLR_MODIFIER_ALT/ ${repo + "/home/dwl/config.h"} > $out";
}).overrideAttrs (old: { patches = (old.patches or [ ]) ++ patches; })'

/tmp/dwl-nested/bin/dwl -s 'ghostty --gtk-single-instance=false'
```

Внутри: `Alt+Enter` — терминал, `Alt+Shift+Q` — закрыть вложенный dwl. Осторожно: `Ctrl+Alt+Backspace` и `Ctrl+Alt+F1…F12` ловит **внешний** dwl, первая завершит основную сессию. Вложенный dwl пишет свою раскладку в тот же `$XDG_RUNTIME_DIR/dwl-kblayout` и сигналит тому же `dwl-status`, так что индикатор основной панели может показать раскладку вложенного; исправится при следующем `Win+Space`. Статус (теги, `appid`, `title`) вложенный dwl печатает в терминал, из которого запущен.

## Частые проблемы

**Ошибка компиляции в `config.h`.** `nixos-rebuild` сообщает, что не собралась `…-dwl-0.9.drv`, и показывает только хвост лога. Полный лог и строка с ошибкой (`config.h` копируется в сборку как есть, номера строк совпадают с файлом в репо):

```bash
nix log /nix/store/<хеш>-dwl-0.9.drv | grep -n -A3 'config.h:[0-9]*'
# или собрать с полным логом сразу
nixos-rebuild build --flake /etc/nixos#gigabyte-nixos -L 2>&1 | grep -A3 'config.h:[0-9]*'
```

Путь к `.drv` есть в сообщении об ошибке. Частые причины: пропущенная запятая в `keys[]`, функция, которой нет без соответствующего патча (`setfact`, `swapclients` и т. д. объявлены в патчах btrtile), опечатка в имени `XKB_KEY_…`.

**Патч не применяется** (в логе `Hunk #N FAILED at …`, обычно после `nix flake update` с новой версией dwl) — см. [`patches/README.md`](patches/README.md#если-патч-перестал-применяться).

**Сервис сессии не стартовал** (нет обоев, не применился профиль монитора, нет окна polkit):

```bash
systemctl --user status dwl-session.target graphical-session.target
systemctl --user status wpaperd kanshi cliphist cliphist-images polkit-agent
journalctl --user -b -u kanshi -u wpaperd
systemctl --user restart kanshi   # перезапуск одного сервиса
```

Если `dwl-session.target` неактивен, сервисы не запустятся: проверить `~/.local/state/dwl.log` на ошибки `dwl-startup`.

**Игра на Vulkan зависает на внешнем мониторе** (окно не обновляется, процесс висит в `vkQueuePresentKHR`; на экране ноутбука та же игра работает). Было с Minecraft 26.3 на NVIDIA и PXG27QV2 в `HDMI-A-2`, разъёме NVIDIA, при старом профиле `external`: масштаб 1.25 и режим по умолчанию 60 Гц. Помогли масштаб 1 и родные 144 Гц — `wlr-randr --output HDMI-A-2 --scale 1`, затем `--mode 2560x1440@144.001999Hz`; какая из двух правок решила проблему, не проверено. Теперь это делает профиль `desk`. Для другого монитора на NVIDIA — свой профиль с его родной частотой и масштабом 1 (см. [Мониторы](#мониторы)). Проверить текущее состояние:

```bash
wlr-randr | grep -E '^[A-Za-z]|current|Scale'
```

**Пустой статус на панели:** `pgrep -a dwl-status` — запущен ли скрипт; он стартует через 1 секунду после `dwlb` и пишет ошибки в `dwl.log`.
