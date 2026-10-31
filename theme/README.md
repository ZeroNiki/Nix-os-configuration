# Палитра Everforest и шрифт

`everforest.nix` — цвета Everforest Dark Medium (hex без `#`), общие для рамок dwl, панели, блокировки, лаунчера, уведомлений, терминала и стартовой страницы Firefox. `font.nix` — моноширинный шрифт (см. [ниже](#шрифт)).

Каталог лежит в корне репо, а не в `home/`, потому что нужен и системе (`fonts.fontconfig` в `hosts/system/configuration.nix`), и Home Manager. Модули его не импортируют: `flake.nix` делает `import` один раз и передаёт оба файла всем модулям аргументами — через `specialArgs` (NixOS) и `home-manager.extraSpecialArgs` (Home Manager):

```nix
# flake.nix
theme = import ./theme/everforest.nix;
font = import ./theme/font.nix;
args = { inherit username theme font; };

# любой модуль
{ pkgs, theme, font, ... }:
```

Палитру используют [`home/dwl/default.nix`](../home/dwl/default.nix) (панель, swaylock, fuzzel и `config.h`), [`home/desktop/common.nix`](../home/desktop/common.nix) (mako, ghostty) и [`home/firefox/default.nix`](../home/firefox/README.md) (стартовая страница получает все ключи палитры как CSS-переменные).

**`config.h`** — это C, поэтому цвета в нём записаны заглушками по ключам палитры: `COLOR(0x@bgDim@ff)`. `home/dwl/default.nix` перед сборкой заменяет каждую `@ключ@` на hex из `everforest.nix` (`builtins.replaceStrings`, как у стартовой страницы Firefox) и отдаёт результат в `pkgs.dwl.override { configH = …; }`. Так значения задаются в одном месте; обратная сторона — сам `config.h` из репо как C не скомпилируется, только через `default.nix` (тестовая сборка с `Alt` делает ту же подстановку, см. [`home/dwl`](../home/dwl/README.md#тест-без-выхода-из-сессии)).

## Цвета и где они используются

В `home/dwl/default.nix` цвета переименованы по ролям: `c.bg` = `bg0`, `c.bgAlt` = `bg1`, `c.fg` = `fg`, `c.dim` = `grey1`, `c.accent` = `green`, `c.urgent` = `red`, `c.warn` = `yellow`.

| Ключ | Hex | Роль | Где используется |
|---|---|---|---|
| `bgDim` | `#232a2e` | самый тёмный фон | `config.h`: `rootcolor` (фон без обоев), `fullscreen_bg` |
| `bg0` | `#2d353b` | основной фон (`c.bg`) | dwlb: фон тегов, середины, текст активного и срочного тега; swaylock: фон и заливка кольца; fuzzel: фон; mako: фон; ghostty: `background`; стартовая страница: фон |
| `bg1` | `#343f44` | второй фон (`c.bgAlt`) | swaylock: кольцо в ожидании; fuzzel: выделенная строка; стартовая страница: строка поиска, ссылки |
| `bg2` | `#3d484d` | | mako: `progress-color`; стартовая страница: ссылка под курсором |
| `bg3` | `#475258` | рамки | `config.h`: `bordercolor` (окно без фокуса); стартовая страница: рамка строки поиска, номера ссылок |
| `fg` | `#d3c6aa` | текст (`c.fg`) | dwlb: текст тегов; swaylock: текст; fuzzel: текст, ввод; mako: текст; стартовая страница: часы, текст |
| `grey1` | `#859289` | приглушённый (`c.dim`) | dwl-status: выключенный звук, выключенный Bluetooth; swaylock: кольцо после стирания ввода, раскладка; fuzzel: placeholder; стартовая страница: дата, placeholder |
| `red` | `#e67e80` | ошибка, срочное (`c.urgent`) | `config.h`: `urgentcolor`; dwlb: фон срочного тега; dwl-status: нет сети, батарея ≤ 15 %; swaylock: неверный пароль, Backspace; mako: рамка `critical`; стартовая страница: точка ссылки |
| `yellow` | `#dbbc7f` | предупреждение (`c.warn`) | swaylock: Caps Lock; стартовая страница: точка ссылки |
| `green` | `#a7c080` | акцент (`c.accent`) | `config.h`: `focuscolor` (окно в фокусе); dwlb: фон активного тега; dwl-status: значки; swaylock: проверка пароля, подсветка нажатий; fuzzel: промпт, совпадения, рамка; mako: рамка; стартовая страница: двоеточие часов, фокус поиска, точка ссылки |
| `orange` | `#e69875` | | стартовая страница: точка ссылки |
| `aqua` | `#83c092` | | стартовая страница: точка ссылки |
| `blue` | `#7fbbb3` | | стартовая страница: точка ссылки |
| `purple` | `#d699b6` | | стартовая страница: точка ссылки |

## Что берёт цвета не отсюда

- **ghostty** — встроенная тема `Everforest Dark Hard`, из палитры взят только `background` = `bg0`.
- **tuigreet** ([`modules/desktop/dwl.nix`](../modules/desktop/README.md)) — `--theme` принимает только имена ANSI-цветов (greeter работает на 16-цветной консоли): `border=green;title=green;prompt=green;input=white;text=white;time=gray;action=darkgray;button=yellow`. Реальный оттенок задаёт палитра консоли, а не hex из `everforest.nix`, поэтому цвета только близки к Everforest.
- **fastfetch** (`home/shell.nix`) — ANSI `green`, то есть цвет из темы терминала.

## Как поменять цвет

1. Поменять значение в `everforest.nix`. Если меняется роль (например, другой акцент), — поменять соответствие в `c = { … }` в начале `home/dwl/default.nix`.
2. В `config.h` ничего менять не нужно: заглушки подставятся при сборке. Чтобы рамки dwl взяли другой ключ палитры, поменять заглушку (`COLOR(0x@bg3@ff)` → `COLOR(0x@grey1@ff)`; последний байт — прозрачность, `ff`).
3. Применить:

   ```bash
   nh os switch
   ```

   fuzzel и swaylock берут новые цвета при следующем запуске, уже работающие mako и ghostty — после перезапуска (`makoctl reload` для mako). dwl, dwlb и `dwl-status` — после выхода из dwl и нового входа.

## Шрифт

`font.nix` — моноширинный шрифт всего рабочего стола: `mono = "Terminess Nerd Font"`. Это Terminus TTF с иконками Nerd Font (пакет `nerd-fonts.terminess-ttf`; переименован, потому что лицензия Terminus требует другого имени у изменённых версий). Аргумент `font` используют [`home/desktop/common.nix`](../home/desktop/common.nix), [`home/dwl/default.nix`](../home/dwl/default.nix), [`home/firefox/default.nix`](../home/firefox/README.md) и [`hosts/system/configuration.nix`](../hosts/system/README.md#шрифты) (`fonts.fontconfig.defaultFonts.monospace`).

У Terminus есть встроенные битмапы для 12, 14, 16, 18, 20, 22, 24, 28 и 32 px. Чётким он выглядит только на этих размерах, на остальных рисуется контурами и мажется. Поэтому размеры заданы в пикселях, где программа это позволяет:

| Программа | Размер | Как задан |
|---|---|---|
| ghostty (а значит nvim, zsh, yazi, …) | 24 px | `font-size = 18`: ghostty считает пункты при 96 dpi, 18 pt = 24 px |
| dwlb | 16 px | `-font "…:pixelsize=16"` (с `size=` dwlb считал бы при 96 dpi: 11 pt = 14,7 px) |
| fuzzel | 20 px | `font = "…:pixelsize=20"`; с `size=` fuzzel пересчитывает по физическому DPI каждого монитора (`dpi-aware=auto`) и в битмап не попадает |
| mako | 16 px | `"… 16px"` (pango понимает `px`) |
| swaylock | 28 px | `font-size = 28`, cairo считает в пикселях |
| стартовая страница Firefox | 16 / 18 / 12 px | CSS; часы — 64–128 px, контурами (пиксельный вид при этом сохраняется) |
| TTY, tuigreet | 24 px | `console.font = "ter-v24n"`, отдельный PSF-шрифт `terminus_font`, в `configuration.nix` |

Чего в Terminess нет: `⇡` и `⇣` (git ahead/behind в промпте starship) — их подставляет DejaVu Sans Mono, они чуть отличаются по стилю. Тонкого начертания тоже нет, только обычное и жирное (плюс курсив).

Сменить шрифт: поменять `mono` в `font.nix` и пакет в `fonts.packages` (`hosts/system/configuration.nix`), проверить размеры по таблице выше (у обычного векторного шрифта можно вернуться к пунктам: `size=11` у dwlb, `size=12` у fuzzel, `11` у mako). Откат на JetBrainsMono: `mono = "JetBrainsMono Nerd Font";`, пакет ещё установлен. TTY — отдельно, `console.font`.
