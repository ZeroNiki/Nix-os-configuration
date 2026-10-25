# Палитра Everforest

`everforest.nix` — цвета Everforest Dark Medium (hex без `#`), общие для панели, блокировки, лаунчера, уведомлений и терминала. Файл импортируют [`../dwl/default.nix`](../dwl/default.nix) и [`../desktop/common.nix`](../desktop/common.nix).

> **`config.h` повторяет нужные ему цвета вручную** (это C, импортировать Nix он не может). При смене палитры править оба места: `everforest.nix` и `rootcolor` / `bordercolor` / `focuscolor` / `urgentcolor` / `fullscreen_bg` в [`../dwl/config.h`](../dwl/config.h). Затем пересобрать и перезайти в dwl.

## Цвета и где они используются

В `dwl/default.nix` цвета переименованы по ролям: `c.bg` = `bg0`, `c.bgAlt` = `bg1`, `c.fg` = `fg`, `c.dim` = `grey1`, `c.accent` = `green`, `c.urgent` = `red`, `c.warn` = `yellow`.

| Ключ | Hex | Роль | Где используется |
|---|---|---|---|
| `bgDim` | `#232a2e` | самый тёмный фон | `config.h`: `rootcolor` (фон без обоев), `fullscreen_bg` |
| `bg0` | `#2d353b` | основной фон (`c.bg`) | dwlb: фон тегов, середины, текст активного и срочного тега; swaylock: фон и заливка кольца; fuzzel: фон; mako: фон; ghostty: `background` |
| `bg1` | `#343f44` | второй фон (`c.bgAlt`) | swaylock: кольцо в ожидании; fuzzel: выделенная строка |
| `bg2` | `#3d484d` | | mako: `progress-color` |
| `bg3` | `#475258` | рамки | `config.h`: `bordercolor` (окно без фокуса) |
| `fg` | `#d3c6aa` | текст (`c.fg`) | dwlb: текст тегов; swaylock: текст; fuzzel: текст, ввод; mako: текст |
| `grey1` | `#859289` | приглушённый (`c.dim`) | dwl-status: выключенный звук, выключенный Bluetooth; swaylock: кольцо после стирания ввода, раскладка; fuzzel: placeholder |
| `red` | `#e67e80` | ошибка, срочное (`c.urgent`) | `config.h`: `urgentcolor`; dwlb: фон срочного тега; dwl-status: нет сети, батарея ≤ 15 %; swaylock: неверный пароль, Backspace; mako: рамка `critical` |
| `yellow` | `#dbbc7f` | предупреждение (`c.warn`) | swaylock: Caps Lock |
| `green` | `#a7c080` | акцент (`c.accent`) | `config.h`: `focuscolor` (окно в фокусе); dwlb: фон активного тега; dwl-status: значки; swaylock: проверка пароля, подсветка нажатий; fuzzel: промпт, совпадения, рамка; mako: рамка |
| `orange` | `#e69875` | | не используется |
| `aqua` | `#83c092` | | не используется |
| `blue` | `#7fbbb3` | | не используется |
| `purple` | `#d699b6` | | не используется |

## Что берёт цвета не отсюда

- **`config.h`** — копии значений, см. выше. Комментарий над цветами в `config.h` перечисляет, какие ключи повторены (`bgDim`, `bg3`, `green`, `red`).
- **ghostty** — встроенная тема `Everforest Dark Hard`, из палитры взят только `background` = `bg0`.
- **tuigreet** (`modules/desktop/dwl.nix`) — `--theme` принимает только имена ANSI-цветов (greeter работает на 16-цветной консоли): `border=green;title=green;prompt=green;input=white;text=white;time=gray;action=darkgray;button=yellow`. Реальный оттенок задаёт палитра консоли, а не hex из `everforest.nix`, поэтому цвета только близки к Everforest.
- **fastfetch** (`home/home.nix`) — ANSI `green`, то есть цвет из темы терминала.

## Как поменять цвет

1. Поменять значение в `everforest.nix`. Если меняется роль (например, другой акцент), — поменять соответствие в `c = { … }` в начале `dwl/default.nix`.
2. Если цвет есть в `config.h` (`bgDim`, `bg3`, `green`, `red`), поменять и там: `COLOR(0xRRGGBBAA)`, последний байт — прозрачность, `ff`.
3. Применить:

   ```bash
   sudo nixos-rebuild switch --flake /etc/nixos#gigabyte-nixos
   ```

   fuzzel и swaylock берут новые цвета при следующем запуске, уже работающие mako и ghostty — после перезапуска (`makoctl reload` для mako). dwl, dwlb и `dwl-status` — после выхода из dwl и нового входа.
