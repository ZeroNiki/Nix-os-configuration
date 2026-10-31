# Monospace font of the whole desktop: ghostty, dwlb, fuzzel, mako,
# swaylock, the Firefox start page and fontconfig's "monospace". flake.nix
# passes it to every module as the `font` argument (home/desktop/common.nix,
# home/dwl/default.nix, home/firefox/default.nix, hosts/system/configuration.nix);
# the TTY uses the PSF build of Terminus (console.font there).
#
# Terminess = Terminus TTF with the Nerd Font icons (renamed, as Terminus'
# license asks of modified versions). It carries embedded bitmaps for 12, 14,
# 16, 18, 20, 22, 24, 28 and 32 px and is crisp only at those sizes, so
# sizes are set in pixels where the program allows it.
{
  mono = "Terminess Nerd Font";
}
