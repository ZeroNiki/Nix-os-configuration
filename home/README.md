# Home Manager: пользователь `nellaror`

`home.nix` — пользовательская часть системы: shell, git, CLI-утилиты, Neovim/Vim из `~/.dotfiles`, LSP и форматтеры, пакеты. Подключается из `flake.nix` как `home-manager.users.nellaror` (с `useGlobalPkgs`, `useUserPackages` и `backupFileExtension = "hm-bak"`).

| Путь | Что там | README |
|---|---|---|
| `home.nix` | этот файл: shell, git, утилиты, пакеты | этот |
| `desktop/common.nix` | mako, ghostty, cliphist, wpaperd, kanshi, утилиты Wayland | [`desktop/README.md`](desktop/README.md) |
| `dwl/` | dwl, патчи, панель, запуск сессии, swaylock, fuzzel | [`dwl/README.md`](dwl/README.md) |
| `theme/everforest.nix` | палитра | [`theme/README.md`](theme/README.md) |

`backupFileExtension = "hm-bak"`: если на месте файла, которым управляет Home Manager, уже лежит обычный файл, он переименовывается в `<имя>.hm-bak`, а не ломает активацию.

## zsh

`programs.zsh` (zsh — shell по умолчанию, включён в [`hosts/system`](../hosts/system/README.md)). `~/.zshrc` генерирует Home Manager (`dotDir` = домашний каталог, файл лежит там же, где всегда). Конфиг перенесён из `~/.dotfiles/.zshrc`, тот файл больше не подключается.

- Автодополнение, `autosuggestion`, `syntaxHighlighting` — опциями Home Manager, не плагинами oh-my-zsh.
- oh-my-zsh с плагинами `git` (алиасы `gst`, `gco`, … ) и `copyfile` (`copyfile <файл>` — содержимое в буфер обмена).
- Промпт powerlevel10k (`pkgs.zsh-powerlevel10k`). Настройки — в `~/.p10k.zsh`, который не в репо; подключается, если существует. Instant prompt выключен (`POWERLEVEL9K_INSTANT_PROMPT=off`).

  ```bash
  p10k configure   # мастер настройки, перезаписывает ~/.p10k.zsh
  ```

- Переменные: `TERM=xterm-256color`, `MANPAGER="less -R"`, `MANOPT="-L ru_RU.UTF-8"` (man по-русски, где есть перевод; локаль `ru_RU.UTF-8` для этого сгенерирована в `configuration.nix`). В `PATH` добавлен `~/.local/bin` (для `pipx`).

### Алиасы

| Алиас | Команда |
|---|---|
| `v` | `vim` |
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
| `bat` | замена `cat` (алиас) |
| `lsd` | `enableZshIntegration = false`: её алиасы `ls`/`ll`/`la`/`lt` конфликтуют с алиасами выше |
| `htop`, `tmux` | с настройками по умолчанию |
| `yazi` | файловый менеджер, обёртка `y` |
| `fastfetch` | маленький логотип NixOS, ключи `os`, `kernel`, `uptime`, `pkgs`, `wm`, `term`, `shell`, `memory`, цвета ANSI (красит тема терминала) |

Конфиги всех этих программ генерирует Home Manager. Их нельзя раскладывать `stow` из `~/.dotfiles`: stow откажется перезаписывать сгенерированные ссылки, а два источника одного конфига будут конфликтовать.

## Neovim и Vim из `~/.dotfiles`

```nix
xdg.configFile."nvim".source = config.lib.file.mkOutOfStoreSymlink ".../.dotfiles/.config/nvim";
home.file.".vimrc".source    = config.lib.file.mkOutOfStoreSymlink ".../.dotfiles/.vimrc";
```

`~/.config/nvim` и `~/.vimrc` — симлинки прямо на файлы в `~/.dotfiles`, а не копии в `/nix/store`.

**Почему не обычный `source = ./путь`:** тогда конфиг копируется в `/nix/store`, а он только для чтения. lazy.nvim переписывает `lazy-lock.json` при каждом обновлении плагинов и не смог бы этого сделать. С `mkOutOfStoreSymlink` правки в `~/.dotfiles` действуют сразу, без пересборки.

Обратная сторона: `~/.dotfiles` не входит в этот репо. На новой машине его нужно склонировать отдельно, иначе ссылки будут вести в никуда. Сам dotfiles-репозиторий здесь не документируется.

## LSP и форматтеры из Nix, а не из mason

LSP-серверы и форматтеры для nvim ставятся пакетами в `home.packages`, списки `ensure_installed` у mason в конфиге nvim пустые.

**Почему:** mason скачивает готовые бинарники, собранные для обычных (FHS) дистрибутивов: они динамически слинкованы и ищут библиотеки и загрузчик по путям вроде `/lib64`, которых в NixOS нет, поэтому часто не запускаются. Пакеты из nixpkgs собраны под NixOS и просто лежат в `PATH`.

| Назначение | Пакеты |
|---|---|
| LSP | `lua-language-server`, `pyright`, `typescript-language-server`, `clang-tools` (clangd + clang-format), `bash-language-server`, `yaml-language-server`, `vscode-langservers-extracted` (jsonls), `terraform-ls` |
| Форматтеры, линтеры | `stylua`, `isort`, `black`, `prettier`, `shfmt`, `codespell` |
| Сборка плагинов | `gcc`, `gnumake` (telescope-fzf-native, парсеры treesitter), `tree-sitter`; `fd` — для `find_files` в telescope |

Новый LSP: найти пакет и добавить его в `home.packages`, в конфиге nvim — включить сервер без установки через mason.

```bash
nix search --inputs-from /etc/nixos nixpkgs <имя>
```

## Пакеты

Всё в `home.packages`, по группам, как в файле:

| Группа | Пакеты |
|---|---|
| CLI / TUI | `ripgrep`, `duf`, `dust`, `jq`, `tree`, `git-lfs`, `glab`, `stow`, `tree-sitter`, `glow`, `sops`, `age`, `rsync`, `wget`, `socat`, `sshpass`, `strace`, `smartmontools`, `plocate`, `neovim`, `claude-code`, `cpufetch` |
| nvim: LSP, форматтеры, сборка | см. таблицу выше |
| Языки | `nodejs`, `python3`, `python3Packages.pip`, `pipx` |
| DevOps | `kubectl` (через `lib.hiPrio`: minikube несёт свой, более старый `kubectl`, и без приоритета пакеты конфликтуют), `kubernetes-helm`, `minikube`, `terraform`, `terraform-ls`, `vagrant` |
| GUI | `firefox`, `vesktop` (Discord с нативным Wayland), `telegram-desktop`, `obsidian`, `keepassxc`, `zathura`, `syncthing`, `obs-studio` |
| Игры (пользовательское) | `protontricks`, `mangohud`; Steam, gamemode, gamescope — системные, в [`hosts/system`](../hosts/system/README.md) |

Утилиты Wayland (`grim`, `slurp`, `wl-clipboard`, `brightnessctl`, `wlr-randr`) — в [`desktop/common.nix`](desktop/README.md#утилиты), dwl, `dwlb`, `dwl-status`, `dwl-session` — в [`dwl/default.nix`](dwl/README.md).

`syncthing` здесь только пакет: сервис не включён, запускать вручную (`syncthing`).

Добавить или убрать пакет — правка списка, затем:

```bash
sudo nixos-rebuild switch --flake /etc/nixos#gigabyte-nixos
```

## stateVersion

`home.stateVersion = "24.11"`. Не менять при обновлениях пакетов; если поднимать — вместе с `system.stateVersion` в `hosts/system/configuration.nix` (см. [`Usage.md`](../Usage.md#13-generate-hardware-info-then-put-this-flake-where-the-installer-expects-it)).
