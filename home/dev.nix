{ config, pkgs, ... }:

{
  home.sessionPath = [ "$HOME/.local/bin" ]; # pipx

  # no VirtualBox here: `vagrant up` goes to libvirt (the vagrant-libvirt
  # plugin comes with nixpkgs' vagrant, see `vagrant plugin list`)
  home.sessionVariables.VAGRANT_DEFAULT_PROVIDER = "libvirt";

  # --- Neovim config from ~/.dotfiles ---
  # nvim itself is the system's programs.neovim (hosts/system/configuration.nix,
  # also vi/vim and EDITOR). Out-of-store symlink so the config stays
  # writable: lazy.nvim rewrites lazy-lock.json, which a read-only
  # /nix/store copy would not allow.
  xdg.configFile."nvim".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.dotfiles/.config/nvim";

  home.packages = with pkgs; [
    git-lfs
    glab
    sops
    age
    claude-code

    # --- nvim: LSP servers and formatters ---
    # Installed here instead of through mason (its ensure_installed lists
    # are empty in the nvim config): binaries mason downloads are
    # dynamically linked for FHS distros and often fail to start on NixOS.
    lua-language-server
    pyright
    typescript-language-server
    clang-tools # clangd + clang-format
    bash-language-server
    yaml-language-server
    vscode-langservers-extracted # jsonls
    nixd # Nix LSP: options and packages of this flake
    nixfmt
    ruff # Python: formatter, import sorting and linter (LSP: `ruff server`)
    stylua
    prettier
    shfmt
    codespell
    # building plugins: telescope-fzf-native (make + cc), treesitter parsers
    gcc
    gnumake
    tree-sitter
    fd # telescope find_files

    nodejs
    python3
    python3Packages.pip
    pipx

    kubectl
    kubernetes-helm
    terraform
    terraform-ls
    vagrant
  ];
}
