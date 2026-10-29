# Home Manager: пользователь `nellaror`

`home.nix` — пользовательская часть системы: shell и промпт, git, CLI-утилиты, comma, Neovim из `~/.dotfiles`, LSP и форматтеры, mpv, программы по умолчанию, пакеты. Подключается из `flake.nix` как `home-manager.users.nellaror` (с `useGlobalPkgs`, `useUserPackages` и `backupFileExtension = "hm-bak"`).

| Путь | Что там | README |
|---|---|---|
| `home.nix` | этот файл: shell, git, утилиты, пакеты | этот |
| `desktop/common.nix` | mako, ghostty, cliphist, wpaperd, kanshi, wlsunset, playerctld, утилиты Wayland | [`desktop/README.md`](desktop/README.md) |
| `dwl/` | dwl, патчи, панель, power-меню, запуск сессии, swaylock, swayidle, fuzzel | [`dwl/README.md`](dwl/README.md) |
| `firefox/` | Firefox (`programs.firefox`), стартовая страница | [`firefox/README.md`](firefox/README.md) |
| `theme/everforest.nix`, `theme/font.nix` | палитра, моноширинный шрифт | [`theme/README.md`](theme/README.md) |

`backupFileExtension = "hm-bak"`: если на месте файла, которым управляет Home Manager, уже лежит обычный файл, он переименовывается в `<имя>.hm-bak`, а не ломает активацию.

## zsh

`programs.zsh` (zsh — shell по умолчанию, включён в [`hosts/system`](../hosts/system/README.md)). `~/.zshrc` генерирует Home Manager (`dotDir` = домашний каталог, файл лежит там же, где всегда). Конфиг перенесён из `~/.dotfiles/.zshrc`, тот файл больше не подключается.

- Автодополнение, `autosuggestion`, `syntaxHighlighting` — опциями Home Manager.
- Промпт — starship (см. ниже). oh-my-zsh не загружается; из него остались только алиасы плагина `git` (`gst`, `ga`, `gc`, `gp`, `gco`, …): `initContent` подключает `lib/git.zsh` и `plugins/git/git.plugin.zsh` прямо из пакета `oh-my-zsh`. Вместо плагина `copyfile` — функция `copyfile <файл>` (содержимое в буфер обмена через `wl-copy`).
- `TERM` не задаётся: его ставит терминал (`xterm-ghostty`). Раньше здесь был `TERM=xterm-256color`, и nvim терял undercurl, протокол клавиатуры kitty и часть цветов. По ssh ghostty сам копирует свой terminfo на хост или подставляет `xterm-256color` (`ssh-terminfo`, `ssh-env` в [`desktop`](desktop/README.md#терминал-ghostty)).
- Переменные: `MANPAGER="less -R"`, `MANOPT="-L ru_RU.UTF-8"` (man по-русски, где есть перевод; локаль `ru_RU.UTF-8` для этого сгенерирована в `configuration.nix`), `VAGRANT_DEFAULT_PROVIDER=libvirt` (в `home.sessionVariables`). В `PATH` добавлен `~/.local/bin` (для `pipx`).

### Промпт: starship и откат на powerlevel10k

`programs.starship` повторяет раскладку прежнего `~/.p10k.zsh` (стиль Pure): каталог и git (ветка серым, состояние красным: `!` изменено, `+` в индексе, `?` новые файлы, `✘` удалено, `=` конфликт; `⇡⇣` и `≡` — голубым) слева, справа на той же строке — время команды дольше 3 с, активный virtualenv, `user@host` (только по ssh и под root), на второй строке — `❯` (красный после ошибки). Цвета ANSI, их красит тема ghostty.

Шелл без oh-my-zsh и p10k стартует быстрее: `zsh -i -c exit` — 0,11–0,13 с против 0,18–0,20 с (замер на этой машине, instant prompt p10k был выключен).

Откат — одна строка в начале `home.nix`:

```nix
prompt = "p10k";   # было "starship"
```

Тогда возвращаются oh-my-zsh (плагины `git`, `copyfile`), powerlevel10k и `~/.p10k.zsh` (файл не удалялся), starship выключается. Если starship прижился — ветку `p10k` и `~/.p10k.zsh` можно удалить.

### Алиасы

| Алиас | Команда |
|---|---|
| `v` | `vim` (системный, без конфига) |
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

```nix
xdg.configFile."nvim".source = config.lib.file.mkOutOfStoreSymlink ".../.dotfiles/.config/nvim";
```

`~/.config/nvim` — симлинк прямо на каталог в `~/.dotfiles`, а не копия в `/nix/store`. `~/.vimrc` больше не подключается: `vim` (системный пакет) остаётся запасным редактором с настройками по умолчанию, `~/.dotfiles/.vimrc` не удалён.

**Почему не обычный `source = ./путь`:** тогда конфиг копируется в `/nix/store`, а он только для чтения. lazy.nvim переписывает `lazy-lock.json` при каждом обновлении плагинов и не смог бы этого сделать. С `mkOutOfStoreSymlink` правки в `~/.dotfiles` действуют сразу, без пересборки.

Обратная сторона: `~/.dotfiles` не входит в этот репо. На новой машине его нужно склонировать отдельно, иначе ссылки будут вести в никуда. Сам dotfiles-репозиторий здесь не документируется.

## LSP и форматтеры из Nix, а не из mason

LSP-серверы и форматтеры для nvim ставятся пакетами в `home.packages`, списки `ensure_installed` у mason в конфиге nvim пустые.

**Почему:** mason скачивает готовые бинарники, собранные для обычных (FHS) дистрибутивов: они динамически слинкованы и ищут библиотеки и загрузчик по путям вроде `/lib64`, которых в NixOS нет, поэтому часто не запускаются. Пакеты из nixpkgs собраны под NixOS и просто лежат в `PATH`.

| Назначение | Пакеты |
|---|---|
| LSP | `lua-language-server`, `pyright`, `ruff` (`ruff server`, линтер Python), `typescript-language-server`, `clang-tools` (clangd + clang-format), `bash-language-server`, `yaml-language-server`, `vscode-langservers-extracted` (jsonls), `terraform-ls`, `nixd` |
| Форматтеры, линтеры | `stylua`, `ruff` (Python: сортировка импортов и форматирование вместо `isort` + `black`), `nixfmt`, `prettier`, `shfmt`, `codespell` |
| Сборка плагинов | `gcc`, `gnumake` (telescope-fzf-native, парсеры treesitter), `tree-sitter`; `fd` — для `find_files` в telescope |

`nixd` в конфиге nvim (`lua/config/plugins/lsp.lua` в `~/.dotfiles`) настроен на этот flake: пакеты — из `inputs.nixpkgs`, опции — NixOS из `nixosConfigurations.gigabyte-nixos` и Home Manager из его `home-manager.users`, поэтому автодополнение и hover соответствуют ревизии из `flake.lock`. В conform: `python = { "ruff_organize_imports", "ruff_format" }`, `nix = { "nixfmt" }`.

Новый LSP: найти пакет и добавить его в `home.packages`, в конфиге nvim — включить сервер без установки через mason.

```bash
nix search --inputs-from /etc/nixos nixpkgs <имя>
```

## mpv

`programs.mpv` со скриптом `mpvScripts.mpris`: mpv виден по MPRIS, и медиа-клавиши (`playerctl`, см. [`dwl`](dwl/README.md#медиа-клавиши)) управляют им так же, как Spotify и Firefox.

## Программы по умолчанию

`xdg.mimeApps` — Home Manager пишет `~/.config/mimeapps.list` (`xdg-open`, ссылки из программ, «Открыть с помощью»):

| Типы | Программа |
|---|---|
| `application/pdf` | zathura (`org.pwmt.zathura-pdf-mupdf.desktop`) |
| `image/png`, `jpeg`, `gif`, `webp`, `bmp`, `tiff`, `svg+xml`, `avif`, `heif`, `jxl` | `imv` |
| `video/mp4`, `x-matroska`, `webm`, `quicktime`, `x-msvideo`, `mpeg`, `ogg` | `mpv` |
| `text/html`, `x-scheme-handler/http(s)` | Firefox |
| `x-scheme-handler/tg`, `ton`, `tonsite` | Telegram |
| `x-scheme-handler/discord` | vesktop |
| `x-scheme-handler/claude-cli` | Claude Code |

Схемы Telegram, vesktop и Claude Code перенесены из прежнего `mimeapps.list`, который записали сами программы. `xdg.configFile."mimeapps.list".force = true`: программы иногда переписывают этот файл сами, и тогда при следующей активации Home Manager его просто заменит, а не остановится на занятом `mimeapps.list.hm-bak`. Поэтому новые ассоциации добавляются только в `home.nix`.

```bash
xdg-mime query default application/pdf
xdg-open file.pdf
```

## Пакеты

Всё в `home.packages`, по группам, как в файле:

| Группа | Пакеты |
|---|---|
| CLI / TUI | `ripgrep`, `duf`, `dust`, `jq`, `tree`, `git-lfs`, `glab`, `tree-sitter`, `glow`, `sops`, `age`, `rsync`, `wget`, `socat`, `sshpass`, `strace`, `smartmontools`, `plocate`, `neovim`, `claude-code` |
| nvim: LSP, форматтеры, сборка | см. таблицу выше |
| Языки | `nodejs`, `python3`, `python3Packages.pip`, `pipx` |
| DevOps | `kubectl` (через `lib.hiPrio`: minikube несёт свой, более старый `kubectl`, и без приоритета пакеты конфликтуют), `kubernetes-helm`, `minikube`, `terraform`, `terraform-ls`, `vagrant` (с `vagrant-libvirt`) |
| GUI | `vesktop` (Discord с нативным Wayland), `telegram-desktop`, `obsidian`, `keepassxc`, `zathura`, `syncthing`, `spotify`, `imv` (картинки); `mpv` — через `programs.mpv`, Firefox — через `programs.firefox` в [`firefox/`](firefox/README.md) |
| Игры (пользовательское) | `protontricks`, `mangohud`; Steam, gamemode, gamescope — системные, в [`hosts/system`](../hosts/system/README.md) |

Утилиты Wayland (`grim`, `slurp`, `wl-clipboard`, `brightnessctl`, `wlr-randr`, `playerctl`) — в [`desktop/common.nix`](desktop/README.md#утилиты), dwl, `dwlb`, `dwl-status`, `dwl-session`, `powermenu` — в [`dwl/default.nix`](dwl/README.md).

`syncthing` здесь только пакет: сервис не включён, запускать вручную (`syncthing`).

Добавить или убрать пакет — правка списка, затем:

```bash
nh os switch
```

## stateVersion

`home.stateVersion = "24.11"`. Не менять при обновлениях пакетов; если поднимать — вместе с `system.stateVersion` в `hosts/system/configuration.nix` (см. [`Usage.md`](../Usage.md#переустановка)).
