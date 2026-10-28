# Системная часть рабочего стола

`dwl.nix` — то, что для dwl нужно настроить на уровне системы: экран входа (greetd + tuigreet), запись сессии dwl, polkit-агент, gnome-keyring и dconf, PAM для swaylock, XDG-порталы и переменные окружения Wayland. Сам dwl, панель и скрипты запуска — пользовательские пакеты в [`home/dwl`](../../home/dwl/README.md).

## Экран входа: greetd + tuigreet

`services.greetd` запускает `tuigreet` от пользователя `greeter`. Выбран вместо sddm: один маленький бинарник с текстовым интерфейсом, без Qt.

Флаги `tuigreet`:

| Флаг | Что делает |
|---|---|
| `--time` | часы на экране входа |
| `--remember` | помнит последнего пользователя |
| `--remember-session` | помнит последнюю выбранную сессию |
| `--sessions <…>/share/wayland-sessions` | список сессий из `services.displayManager.sessionData.desktops` |
| `--cmd /etc/profiles/per-user/nellaror/bin/dwl-session` | сессия по умолчанию, пока ничего не выбрано |
| `--theme '…'` | цвета, см. ниже |

Клавиши tuigreet: `F3` — выбор сессии (в списке одна: `dwl`), `F2` — ввести команду вместо сессии, `F12` — меню питания (выключение, перезагрузка).

**Тема.** Greeter работает на 16-цветной консоли, поэтому `--theme` принимает только имена ANSI-цветов. Они подобраны близко к акцентам Everforest из dwl, но точный оттенок задаёт палитра консоли:

| Элемент | Цвет |
|---|---|
| `border`, `title`, `prompt` | `green` |
| `input`, `text` | `white` |
| `time` | `gray` |
| `action` | `darkgray` |
| `button` | `yellow` |

Поменять тему или флаги — строка `command` в `services.greetd.settings.default_session`. Логи greeter:

```bash
journalctl -b -u greetd
```

### Сессия dwl в списке tuigreet

`dwlDesktopSession` — пакет с одним файлом `share/wayland-sessions/dwl.desktop`:

```ini
[Desktop Entry]
Name=dwl
Exec=/etc/profiles/per-user/nellaror/bin/dwl-session
Type=Application
```

Он добавлен в `services.displayManager.sessionPackages` (с `passthru.providedSessions = [ "dwl" ]`, которого требует эта опция), и NixOS собирает его в `sessionData.desktops`, откуда tuigreet читает список. `Exec` указывает в профиль пользователя, потому что `dwl-session` ставит Home Manager, а не система. Что делает `dwl-session` дальше — в [`home/dwl`](../../home/dwl/README.md#как-запускается-сессия).

## `dwl-session.target` и `graphical-session.target`

У dwl нет своей интеграции с systemd, поэтому она сделана как `sway-session.target` в Home Manager (сам target объявлен в [`home/dwl/default.nix`](../../home/dwl/default.nix)):

- `dwl-startup` (запускается dwl через `-s`) делает `systemctl --user start dwl-session.target`;
- `dwl-session.target` имеет `BindsTo=graphical-session.target`, `Wants=` и `After=graphical-session-pre.target`, то есть поднимает стандартный `graphical-session.target`;
- все пользовательские сервисы с `WantedBy=graphical-session.target` стартуют вместе с ним: `polkit-agent` из этого модуля, `swayidle` из [`home/dwl`](../../home/dwl/README.md#простой-и-сон), `cliphist`, `cliphist-images`, `wpaperd`, `kanshi`, `wlsunset` из [`home/desktop`](../../home/desktop/README.md);
- после выхода из dwl `dwl-session` останавливает `dwl-session.target`; `graphical-session.target` имеет `StopWhenUnneeded`, а сервисы — `PartOf` него, поэтому останавливаются и они.

Так любой сервис, который Home Manager или NixOS привязывают к `graphical-session.target`, работает в dwl без дополнительной настройки.

## Polkit-агент

`systemd.user.services.polkit-agent` — `polkit-gnome-authentication-agent-1` из `polkit_gnome`. Окно для ввода пароля, когда программа просит права через polkit (virt-manager, blueman, монтирование дисков). `WantedBy`, `PartOf`, `After` — `graphical-session.target`, `Restart=on-failure`.

Раньше здесь был агент KDE (`kdePackages.polkit-kde-agent-1`): ради одного окна он тянул Qt6 и KDE Frameworks. Агент GNOME — одно GTK-окно, а GTK в системе и так есть. `security.polkit.enable` — в `hosts/system/configuration.nix`.

```bash
systemctl --user status polkit-agent
```

## gnome-keyring и dconf

- `services.gnome.gnome-keyring.enable` — хранилище секретов (Secret Service) для vesktop, obsidian, telegram, firefox. Разблокируется при входе через PAM паролем пользователя. Заодно даёт `gcr-ssh-agent`.
- `programs.dconf.enable` — бэкенд GSettings, без него GTK-программы не сохраняют настройки.

Раньше это включал модуль прежнего композитора, теперь задано явно.

## PAM для swaylock

```nix
security.pam.services.swaylock = { };
```

swaylock (`Win+Shift+L`) проверяет пароль через PAM, и без собственной записи в PAM разблокировать экран нельзя. Настройки swaylock — в [`home/dwl`](../../home/dwl/README.md#блокировка-экрана).

## XDG-порталы

`xdg.portal` с `wlr.enable` (`xdg-desktop-portal-wlr`) и `xdg-desktop-portal-gtk`:

| Интерфейс | Портал |
|---|---|
| `org.freedesktop.impl.portal.Screenshot` | `wlr` |
| `org.freedesktop.impl.portal.ScreenCast` | `wlr` — демонстрация экрана в браузере, OBS, Discord |
| всё остальное (`default`) | `gtk` — диалоги выбора файлов и т. п. |

Таблица задана для `config.dwl` (по `XDG_CURRENT_DESKTOP=dwl`, его ставит `dwl-session`) и такая же — для `config.common`, на случай программ, запущенных без этой переменной. Порталы запускаются D-Bus-активацией, окружение сессии им передаёт `dwl-startup` (`dbus-update-activation-environment --systemd …`).

## Переменные окружения

| Переменная | Зачем |
|---|---|
| `NIXOS_OZONE_WL=1` | Electron/Chromium-программы (vesktop, obsidian, …) работают через Wayland напрямую, а не через Xwayland |
| `MOZ_ENABLE_WAYLAND=1` | Firefox через Wayland |

Заданы в `environment.sessionVariables`, применяются после нового входа.
