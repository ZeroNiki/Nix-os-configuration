# Firefox и стартовая страница

`default.nix` — `programs.firefox` и стартовая страница. Подключается из [`../home.nix`](../home.nix) (`imports`).

| Путь | Что там |
|---|---|
| `default.nix` | `programs.firefox`, политика `Homepage`, новая вкладка через autoconfig, установка страницы через `home.file` |
| `startpage/index.html` | страница: HTML + CSS + немного JS, без внешних зависимостей |

## Firefox

Firefox ставится через `programs.firefox`, а не через `home.packages`: политики (`policies`) зашиваются в обёртку пакета (`lib/firefox/distribution/policies.json`), поэтому пакет должен быть один — тот, что собирает модуль.

- **Профиль не трогается.** `profiles` не заданы, значит Home Manager не пишет `profiles.ini` и ничего не кладёт в каталог профиля; закладки, расширения и настройки остаются как были.
- **`configPath = ~/.config/mozilla/firefox`.** Firefox уже хранит профиль там (XDG), а Home Manager при `home.stateVersion` < 26.05 по умолчанию считает, что профиль в `~/.mozilla/firefox`, и выдаёт предупреждение. С явным путём предупреждения нет, а обёртка выставляет `MOZ_APP_DATA=~/.config/mozilla/firefox` — каталог, где лежит `profiles.ini`, то есть тот же профиль.

## Стартовая страница

Крупные часы, приветствие по времени суток (утро 5–12, день 12–18, вечер 18–23, ночь), дата, строка поиска и сетка ссылок. Шрифт — моноширинный из [`theme/font.nix`](../../theme/README.md#шрифт) (аргумент `font`), как в панели и терминале (в `index.html` — заглушка `@font@`).

| Клавиша | Действие |
|---|---|
| `/` | фокус в строку поиска |
| `Enter` | поиск; если введено что-то похожее на адрес (`example.org`, `localhost:8080/x`), он открывается напрямую |
| `Esc` | очистить строку и убрать фокус |
| `1`–`8` | открыть ссылку с этим номером (когда фокус не в строке поиска) |

Firefox при открытии окна обычно ставит фокус в адресную строку, тогда `/` и цифры попадают туда: сначала щёлкнуть по странице.

### Как устроено

- **Цвета** — из [`theme/everforest.nix`](../../theme/README.md) (аргумент `theme`). В `index.html` вместо hex стоят заглушки `@bg0@`, `@green@`, … (по ключам палитры), `default.nix` подставляет значения через `builtins.replaceStrings`. Поэтому сам `startpage/index.html` из репо открывать бесполезно: смотреть установленную копию.
- **Установка** — `home.file."~/.local/share/startpage/index.html"` (`${config.xdg.dataHome}/startpage/index.html`), ссылка в `/nix/store`.
- **Домашняя страница** — `programs.firefox.policies.Homepage.URL = "file://…/index.html"`, `Locked = false`. Страница становится домашней (кнопка «Домой», `Alt+Home`). Что открывать при запуске (домашнюю страницу или прошлую сессию), не задаётся: остаётся выбор из настроек Firefox.
- **Новая вкладка** — ни настройки, ни политики для адреса новой вкладки в Firefox нет (`browser.newtab.url` убрали в Firefox 41). Его задаёт autoconfig: `programs.firefox.package = pkgs.firefox.override { extraPrefsFiles = [ … ]; }` дописывает в `mozilla.cfg` обёртки скрипт, который при запуске выставляет `AboutNewTab.newTabURL` (модуль `resource:///modules/AboutNewTab.sys.mjs`). `mozilla.cfg` в Firefox выполняется без песочницы, а `AboutNewTab.init()` переопределённый адрес не сбрасывает (проверено на Firefox 158). Через `extraPrefsFiles`, а не `extraPrefs`, потому что `extraPrefs` вставляется в shell-heredoc, и `$` в нём раскрывался бы. Если в новой версии Firefox модуль переедет, вкладка станет стандартной, а ошибка попадёт в консоль браузера (`Ctrl+Shift+J`).

### Ссылки и поиск

В начале `<script>` в `index.html`:

```js
const LINKS = [
  { name: "GitHub", url: "https://github.com" },
  // ...
];

const SEARCH = "https://duckduckgo.com/?q=%s"; // %s заменяется запросом
```

Показываются первые 8 ссылок (4 колонки, на узком окне — 2). Цвет точки у ссылки идёт по кругу: `green`, `aqua`, `blue`, `purple`, `yellow`, `orange`, `red`. Длинное имя обрезается многоточием.

Применить правки:

```bash
nh os switch
```

Затем обновить страницу в Firefox. Изменение политики (`Homepage`) — после перезапуска Firefox; проверить: `about:policies`.
