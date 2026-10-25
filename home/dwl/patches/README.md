# Патчи к dwl

Патчи, которые `home/dwl/default.nix` накладывает на `pkgs.dwl` (сейчас dwl 0.9 из nixpkgs) поверх патчей самого nixpkgs. Настройки, которые патчи добавляют, задаются в [`../config.h`](../config.h); как это выглядит в работе — в [`../README.md`](../README.md).

## Список

| Порядок | Файл | Откуда | Что делает |
|---|---|---|---|
| 1 | `gaps.patch` | свой (источник в репо не записан) | Отступы `gappx` для `tile` и `monocle` |
| 2 | `keys-latin.patch` | свой (источник в репо не записан) | Привязки ищутся в латинской раскладке |
| 3 | `btrtile.patch` | [dwl-patches](https://codeberg.org/dwl/dwl-patches/src/branch/main/patches/btrtile), коммит `8a28588`, «btrtile: update for v0.9» (julmajustus), без изменений | Лейаут btrtile — дерево как в bspwm |
| 4 | `btrtile-local.patch` | свой, `[local]` в заголовке | Подгонка btrtile под этот конфиг |
| 5 | `kblayout-local.patch` | свой, `[local]` в заголовке | Индикатор раскладки EN/RU для панели |

### `gaps.patch`

Меняет `tile()` и `monocle()` в `dwl.c`: окна отстоят на `gappx` от краёв экрана и друг от друга (в `tile` — и между мастером и стопкой). Сама переменная `gappx` (8 px) объявлена в `config.h`, патч её только использует. Это не патч `gaps` из dwl-patches: тот добавляет переключаемое поле `m->gaps` (на него рассчитан `#ifdef BTRTILE_GAPS` в btrtile), здесь его нет.

### `keys-latin.patch`

В `keypress()` раскладка для поиска привязки всегда `0` вместо текущей (`xkb_state_key_get_layout`). Первая раскладка в `xkb_rules` — `us`, поэтому `Win+Q` и остальные привязки срабатывают и на `ru`. Как и без патча, проверяются обычный и Shift-уровни клавиши.

### `btrtile.patch`

Добавляет `btrtile.h` (дерево `LayoutNode`, вставка и удаление окон, расчёт областей, `setratio_h` / `setratio_v`, `swapclients`, `swapsplit`, `togglesplit`) и правки в `dwl.c`: дерево у каждого монитора (`Monitor.root`), лист у каждого окна (`Client.node`), перетаскивание и ресайз плиточных окон мышью без перевода в плавающие. Также меняет `config.def.h`, но тот не используется: nixpkgs подставляет наш `config.h` (`configH`). Настройки (`use_active_for_splits`, `force_split`, `preserve_split`, `split_width_multiplier`, `resize_interval_ms`, `enum Direction`) обязаны быть в `config.h`, иначе сборка падает.

### `btrtile-local.patch`

- Отступы: `half_gap()` / `outer_gap()` берут `gappx` из `gaps.patch` вместо `#ifdef BTRTILE_GAPS` и `m->gaps` из upstream-патча gaps.
- Проверка «активен ли btrtile» по функции (`arrange == btrtile`), а не по символу `"|w|"` — в `config.h` символ другой, `[B]`.
- `resize_split()` ничего не делает под другими лейаутами: там дерево устаревшее.
- `moveresize()`: перетаскивание мышью «на месте» только под btrtile; в остальных лейаутах окно, как в обычном dwl, становится плавающим.
- Новая функция `setfact` для `Win+H` / `Win+L`: `setratio_h` под btrtile, `setmfact` под остальными.

### `kblayout-local.patch`

Функция `kblayout()`, вызывается при старте и на каждое событие модификаторов основной клавиатурной группы (смена раскладки приходит именно так). Если группа xkb изменилась: пишет `kblayout_names[группа]` в `$XDG_RUNTIME_DIR/<kblayout_file>` через `.tmp` + `rename`, читает PID из `$XDG_RUNTIME_DIR/<kblayout_pidfile>` и шлёт `SIGUSR1`, если `/proc/<pid>/comm` равен `kblayout_comm`. Все четыре значения — в `config.h` (`EN`/`RU`, `dwl-kblayout`, `dwl-status.pid`, `dwl-status`). Патч `kblayout` из dwl-patches не подошёл: он есть только для 0.7/0.8 и ещё переключает раскладку отдельно для каждого окна.

## Порядок и почему он важен

Порядок задаёт список `patches` в `default.nix`. Каждый патч снят с дерева, где уже наложены предыдущие. Это видно по строкам `index` для `dwl.c` (проверено наложением на исходник dwl 0.9):

```
dwl 0.9          4cfd0fd
+ gaps           2173923
+ keys-latin     88b001a
+ btrtile        a93e78a   (в самом патче index 4cfd0fd..: он снят с чистого dwl и ложится со сдвигом строк)
+ btrtile-local  30d8bd1   (в патче index a93e78a..30d8bd1)
+ kblayout-local 58c4a88   (в патче index 30d8bd1..58c4a88)
```

- `btrtile-local.patch` правит `btrtile.h` и строки `dwl.c`, которые добавляет `btrtile.patch`, поэтому только после него.
- `btrtile-local.patch` и `gaps.patch` берут одну и ту же `gappx` из `config.h`, чтобы отступы были одинаковыми во всех лейаутах. Текстово они не пересекаются, но `btrtile-local.patch` снят поверх `gaps.patch`.
- `kblayout-local.patch` снят поверх всех остальных: номера строк в его хунках — от уже пропатченного `dwl.c`.

Новый патч добавлять в конец списка и снимать с дерева, где уже наложены все остальные. Новый файл flake увидит только после `git add`.

## Если патч перестал применяться

Обычно после `nix flake update`, когда в nixpkgs приходит новая версия dwl. В логе сборки (`nix log /nix/store/<хеш>-dwl-<версия>.drv`) будет `Hunk #N FAILED at …` и имя файла.

1. Посмотреть, что за версия пришла:

   ```bash
   nix eval --raw --inputs-from /etc/nixos nixpkgs#dwl.version
   ```

2. Наложить патчи по очереди на чистый исходник и найти первый сломанный:

   ```bash
   src=$(nix build --no-link --print-out-paths --inputs-from /etc/nixos nixpkgs#dwl.src)
   work=$(mktemp -d)
   cp -r "$src"/. "$work" && chmod -R u+w "$work" && cd "$work"
   git init -q && git add -A && git commit -qm upstream
   for p in gaps keys-latin btrtile btrtile-local kblayout-local; do
     patch -p1 --no-backup-if-mismatch < /etc/nixos/home/dwl/patches/$p.patch || { echo "FAILED: $p"; break; }
     git add -A && git commit -qm "$p"
   done
   ```

3. Починить:
   - `btrtile.patch` — взять версию под новый dwl из [dwl-patches](https://codeberg.org/dwl/dwl-patches/src/branch/main/patches/btrtile) целиком, без ручных правок (правки живут в `btrtile-local.patch`), и записать коммит dwl-patches в коммит репо.
   - свои патчи (`gaps`, `keys-latin`, `*-local`) — откатить неудачную попытку (`git checkout . && git clean -fd`), внести изменения вручную по `.rej` или по старому патчу, затем снять заново:

     ```bash
     git diff > /etc/nixos/home/dwl/patches/<имя>.patch
     ```

     Строку описания `[local] …` в начале `btrtile-local.patch` и `kblayout-local.patch` сохранить (`patch` пропускает текст перед первым `diff`). После этого `git commit -qam <имя>` и продолжить со следующего патча: все последующие снимаются с дерева, где уже лежит исправленный.

4. Проверить сборку и тестовым вложенным dwl (см. [`../README.md`](../README.md#тест-без-выхода-из-сессии)), затем:

   ```bash
   nixos-rebuild build --flake /etc/nixos#gigabyte-nixos
   ```

Если в новой версии dwl переименовали функцию, которую вызывает патч, ошибка будет не `Hunk FAILED`, а ошибка компиляции в `dwl.c` / `btrtile.h` — смотреть тот же лог.
