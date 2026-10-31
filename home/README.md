# Home Manager: пользователь `nellaror`

Пользовательская часть системы. `home.nix` подключается из `flake.nix` как `home-manager.users.nellaror` (с `useGlobalPkgs`, `useUserPackages` и `backupFileExtension = "hm-bak"`) и импортирует остальные файлы. Аргументы `username`, `theme`, `font` приходят из `flake.nix` (`home-manager.extraSpecialArgs`).

| Путь | Что там | README |
|---|---|---|
| `home.nix` | `imports`, имя и каталог пользователя, `stateVersion`, git + delta, `xdg.enable` | этот |
| `shell.nix` | zsh, starship, fzf, zoxide, comma, bat, lsd, htop, yazi, fastfetch, CLI-утилиты | этот |
| `dev.nix` | конфиг nvim из `~/.dotfiles`, LSP и форматтеры, сборка плагинов, языки, kubectl/helm/terraform, `PATH` для pipx, провайдер vagrant | этот |
| `apps.nix` | mpv, программы по умолчанию (`xdg.mimeApps`), GUI- и TUI-программы, игры | этот |
| `desktop/common.nix` | mako, ghostty, cliphist, wpaperd, kanshi, wlsunset, playerctld, утилиты Wayland | [`desktop/README.md`](desktop/README.md) |
| `dwl/` | dwl, патчи, панель, power-меню, запуск сессии, swaylock, swayidle, fuzzel | [`dwl/README.md`](dwl/README.md) |
| `firefox/` | Firefox (`programs.firefox`), стартовая страница | [`firefox/README.md`](firefox/README.md) |

Палитра и шрифт лежат в корне репо, в [`theme/`](../theme/README.md): они нужны и системе.

`backupFileExtension = "hm-bak"`: если на месте файла, которым управляет Home Manager, уже лежит обычный файл, он переименовывается в `<имя>.hm-bak`, а не ломает активацию.

## zsh

`shell.nix`, `programs.zsh` (zsh — shell по умолчанию, включён в [`hosts/system`](../hosts/system/README.md)). `~/.zshrc` генерирует Home Manager (`dotDir` = домашний каталог, файл лежит там же, где всегда). Конфиг перенесён из `~/.dotfiles/.zshrc`, тот файл больше не подключается.

- Автодополнение, `autosuggestion`, `syntaxHighlighting` — опциями Home Manager.
- Промпт — starship (см. ниже). oh-my-zsh не загружается; из него остались только алиасы плагина `git` (`gst`, `ga`, `gc`, `gp`, `gco`, …): `initContent` подключает `lib/git.zsh` и `plugins/git/git.plugin.zsh` прямо из пакета `oh-my-zsh`. Вместо плагина `copyfile` — функция `copyfile <файл>` (содержимое в буфер обмена через `wl-copy`).
- `TERM` не задаётся: его ставит терминал (`xterm-ghostty`). Раньше здесь был `TERM=xterm-256color`, и nvim терял undercurl, протокол клавиатуры kitty и часть цветов. По ssh ghostty сам копирует свой terminfo на хост или подставляет `xterm-256color` (`ssh-terminfo`, `ssh-env` в [`desktop`](desktop/README.md#терминал-ghostty)).
- Переменные: `MANPAGER="less -R"`, `MANOPT="-L ru_RU.UTF-8"` (man по-русски, где есть перевод; локаль `ru_RU.UTF-8` для этого сгенерирована в `configuration.nix`), `VAGRANT_DEFAULT_PROVIDER=libvirt` (в `home.sessionVariables`). В `PATH` добавлен `~/.local/bin` (для `pipx`).

### Промпт: starship

`programs.starship` повторяет раскладку прежнего `~/.p10k.zsh` (стиль Pure): каталог и git (ветка серым, состояние красным: `!` изменено, `+` в индексе, `?` новые файлы, `✘` удалено, `=` конфликт; `⇡⇣` и `≡` — голубым) слева, справа на той же строке — время команды дольше 3 с, активный virtualenv, `user@host` (только по ssh и под root), на второй строке — `❯` (красный после ошибки). Цвета ANSI, их красит тема ghostty.

Шелл без oh-my-zsh и p10k стартует быстрее: `zsh -i -c exit` — 0,11–0,13 с против 0,18–0,20 с (замер на этой машине, instant prompt p10k был выключен). Starship прижился, переключатель на oh-my-zsh + powerlevel10k из конфига убран; вернуть его можно из истории git (`git log -S 'prompt = "starship"' -- home/home.nix`).

### Алиасы

| Алиас | Команда |
|---|---|
| `v` | `nvim` |
| `nv` | `nvim` |
| `cat` | `bat` |
| `ls` | `lsd` |
| `l` | `lsd -lh` |
| `la` | `lsd -lah` |
| `du` | `dust` |
| `df` | `duf` |
| `k` | `kubectl` |
| `h` | `helm` |
| `mkdir` | `mkdir -p` |
| `c` | `clear` |
| `fetch` | `fastfetch` |

`y` — не алиас, а функция-обёртка yazi (`programs.yazi.shellWrapperName = "y"`): открывает yazi и после выхода делает `cd` в каталог, где он был закрыт.

## Git и CLI-утилиты

git и delta — в `home.nix`, остальное — в `shell.nix`.

| Программа | Настройка |
|---|---|
| `git` | `user.name`, `user.email`, `init.defaultBranch = "main"` |
| `delta` | пейджер для diff в git (`enableGitIntegration`) |
| `fzf` | `--height 40% --layout=reverse --border`, превью через `bat`; интеграция с zsh по умолчанию (`Ctrl+T`, `Ctrl+R`, `Alt+C`) |
| `zoxide` | `z <часть пути>`, `zi` — выбор через fzf |
| `nix-index` + `comma` | `, <команда>` — запустить программу из nixpkgs без установки; на неизвестную команду zsh подсказывает, в каком пакете она есть. База готовая, из input `nix-index-database` (обновляется вместе с `flake.lock`), локально ничего не индексируется |
| `bat` | замена `cat` (алиас) |
| `lsd` | `enableZshIntegration = false`: её алиасы `ls`/`ll`/`la`/`lt` конфликтуют с алиасами выше |
| `htop`, `tmux` | с настройками по умолчанию |
| `yazi` | файловый менеджер, обёртка `y` |
| `fastfetch` | маленький логотип NixOS, ключи `os`, `kernel`, `uptime`, `pkgs`, `wm`, `term`, `shell`, `memory`, цвета ANSI (красит тема терминала) |

```bash
, cowsay hi        # скачать и запустить без установки
nix-locate bin/ffmpeg   # в каком пакете файл
```

Конфиги всех этих программ генерирует Home Manager, `stow` больше не используется (и не установлен).

## Neovim из `~/.dotfiles`

Сам nvim ставит система: `programs.neovim` в [`hosts/system`](../hosts/system/README.md#редактор-только-neovim), там же `EDITOR=nvim` и `vi`/`vim` → nvim; nano и vim убраны. Здесь, в `dev.nix`, — только ссылка на конфиг:

```nix
xdg.configFile."nvim".source = config.lib.file.mkOutOfStoreSymlink ".../.dotfiles/.config/nvim";
```

`~/.config/nvim` — симлинк прямо на каталог в `~/.dotfiles`, а не копия в `/nix/store`. `vi` и `vim` — тот же nvim, поэтому тоже с этим конфигом. `~/.vimrc` не подключается, `~/.dotfiles/.vimrc` не удалён.

**Почему не обычный `source = ./путь`:** тогда конфиг копируется в `/nix/store`, а он только для чтения. lazy.nvim переписывает `lazy-lock.json` при каждом обновлении плагинов и не смог бы этого сделать. С `mkOutOfStoreSymlink` правки в `~/.dotfiles` действуют сразу, без пересборки.

Обратная сторона: `~/.dotfiles` не входит в этот репо. На новой машине его нужно склонировать отдельно, иначе ссылки будут вести в никуда. Сам dotfiles-репозиторий здесь не документируется.

## LSP и форматтеры из Nix, а не из mason

LSP-серверы и форматтеры для nvim ставятся пакетами в `home.packages` (`dev.nix`), списки `ensure_installed` у mason в конфиге nvim пустые.

**Почему:** mason скачивает готовые бинарники, собранные для обычных (FHS) дистрибутивов: они динамически слинкованы и ищут библиотеки и загрузчик по путям вроде `/lib64`, которых в NixOS нет, поэтому часто не запускаются. Пакеты из nixpkgs собраны под NixOS и просто лежат в `PATH`.

| Назначение | Пакеты |
|---|---|
| LSP | `lua-language-server`, `pyright`, `ruff` (`ruff server`, линтер Python), `typescript-language-server`, `clang-tools` (clangd + clang-format), `bash-language-server`, `yaml-language-server`, `vscode-langservers-extracted` (jsonls), `terraform-ls`, `nixd` |
| Форматтеры, линтеры | `stylua`, `ruff` (Python: сортировка импортов и форматирование вместо `isort` + `black`), `nixfmt`, `prettier`, `shfmt`, `codespell` |
| Сборка плагинов | `gcc`, `gnumake` (telescope-fzf-native, парсеры treesitter), `tree-sitter`; `fd` — для `find_files` в telescope |

`nixd` в конфиге nvim (`lua/config/plugins/lsp.lua` в `~/.dotfiles`) настроен на этот flake: пакеты — из `inputs.nixpkgs`, опции — NixOS из `nixosConfigurations.gigabyte-nixos` и Home Manager из его `home-manager.users`, поэтому автодополнение и hover соответствуют ревизии из `flake.lock`. В conform: `python = { "ruff_organize_imports", "ruff_format" }`, `nix = { "nixfmt" }`.

Новый LSP: найти пакет и добавить его в `home.packages` в `dev.nix`, в конфиге nvim — включить сервер без установки через mason.

```bash
nix search --inputs-from /etc/nixos nixpkgs <имя>
```

## mpv

`apps.nix`, `programs.mpv` со скриптом `mpvScripts.mpris`: mpv виден по MPRIS, и медиа-клавиши (`playerctl`, см. [`dwl`](dwl/README.md#медиа-клавиши)) управляют им так же, как Spotify и Firefox.

## Программы по умолчанию

`xdg.mimeApps` в `apps.nix` — Home Manager пишет `~/.config/mimeapps.list` (`xdg-open`, ссылки из программ, «Открыть с помощью»):

| Типы | Программа |
|---|---|
| `application/pdf` | zathura (`org.pwmt.zathura-pdf-mupdf.desktop`) |
| `image/png`, `jpeg`, `gif`, `webp`, `bmp`, `tiff`, `svg+xml`, `avif`, `heif`, `jxl` | `imv` |
| `video/mp4`, `x-matroska`, `webm`, `quicktime`, `x-msvideo`, `mpeg`, `ogg` | `mpv` |
| `text/html`, `x-scheme-handler/http(s)` | Firefox |
| `x-scheme-handler/tg`, `ton`, `tonsite` | Telegram |
| `x-scheme-handler/discord` | vesktop |
| `x-scheme-handler/claude-cli` | Claude Code |

Схемы Telegram, vesktop и Claude Code перенесены из прежнего `mimeapps.list`, который записали сами программы. `xdg.configFile."mimeapps.list".force = true`: программы иногда переписывают этот файл сами, и тогда при следующей активации Home Manager его просто заменит, а не остановится на занятом `mimeapps.list.hm-bak`. Поэтому новые ассоциации добавляются только в `apps.nix`.

```bash
xdg-mime query default application/pdf
xdg-open file.pdf
```

## Пакеты

`home.packages` разнесены по файлам:

| Файл | Группа | Пакеты |
|---|---|---|
| `shell.nix` | CLI / TUI | `ripgrep`, `duf`, `dust`, `jq`, `tree`, `glow`, `rsync`, `wget`, `socat`, `sshpass`, `strace`, `smartmontools` |
| `dev.nix` | Разработка | `git-lfs`, `glab`, `sops`, `age`, `claude-code` |
| `dev.nix` | nvim: LSP, форматтеры, сборка | см. таблицу выше |
| `dev.nix` | Языки | `nodejs`, `python3`, `python3Packages.pip`, `pipx` |
| `dev.nix` | DevOps | `kubectl`, `kubernetes-helm` (алиасы `k`, `h`), `terraform`, `terraform-ls`, `vagrant` (с `vagrant-libvirt`, провайдер по умолчанию — libvirt) |
| `apps.nix` | GUI | `vesktop` (Discord с нативным Wayland), `telegram-desktop`, `obsidian`, `keepassxc`, `zathura`, `syncthing`, `imv` (картинки), `spotify` (официальный клиент; виден по MPRIS для медиа-клавиш); `mpv` — через `programs.mpv`, Firefox — через `programs.firefox` в [`firefox/`](firefox/README.md) |
| `apps.nix` | TUI | `bluetui` (Bluetooth, открывается и кликом по панели) |
| `apps.nix` | Игры (пользовательское) | `protontricks`, `mangohud`, `prismlauncher`; Steam, gamemode, gamescope — системные, в [`hosts/system`](../hosts/system/README.md) |

Чего здесь нет намеренно:

- **minikube** — не нужен, убран (вместе с ним ушёл и `lib.hiPrio` у `kubectl`: minikube нёс свой, более старый `kubectl`).
- **spotify-player** (и другие клиенты на librespot: ncspot, spotifyd) — вход работает, но Spotify не выдаёт этому аккаунту ключи расшифровки (`audio key error`, [librespot#1649](https://github.com/librespot-org/librespot/issues/1649)), и звука нет. Поэтому стоит официальный `spotify`.
- **plocate** — без `services.locate` его база не создавалась; файлы ищет `fd` (`dev.nix`).
- **neovim** — ставится системой (см. [выше](#neovim-из-dotfiles)).

Утилиты Wayland (`grim`, `slurp`, `wl-clipboard`, `brightnessctl`, `wlr-randr`, `playerctl`) — в [`desktop/common.nix`](desktop/README.md#утилиты), dwl, `dwlb`, `dwl-status`, `dwl-session`, `powermenu` — в [`dwl/default.nix`](dwl/README.md).

`syncthing` здесь только пакет (`apps.nix`): сервис не включён, запускать вручную (`syncthing`).

Добавить или убрать пакет — правка списка в нужном файле, затем:

```bash
nh os switch
```

## stateVersion

`home.stateVersion = "24.11"`. Не менять при обновлениях пакетов; если поднимать — вместе с `system.stateVersion` в `hosts/system/configuration.nix` (см. [`Usage.md`](../Usage.md#переустановка)).
