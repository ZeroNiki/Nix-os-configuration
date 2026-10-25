{ config, lib, pkgs, ... }:

let
  # Everforest Dark Medium (home/theme/everforest.nix) under the role names
  # the rest of this file uses; the colors in config.h match the same file.
  theme = import ../theme/everforest.nix;
  c = {
    bg = theme.bg0;
    bgAlt = theme.bg1;
    fg = theme.fg;
    dim = theme.grey1;
    accent = theme.green;
    urgent = theme.red;
    warn = theme.yellow;
  };

  font = "JetBrainsMono Nerd Font";

  # config.h lives next to this file, rebuild after every edit.
  dwl = (pkgs.dwl.override { configH = ./config.h; }).overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      ./patches/gaps.patch # gappx in config.h
      ./patches/keys-latin.patch # bindings keep working on the "ru" layout
      # bspwm-like tree layout, codeberg.org/dwl/dwl-patches btrtile v0.9 as is,
      # then our changes to it (gappx, Mod+h/l); settings in config.h
      ./patches/btrtile.patch
      ./patches/btrtile-local.patch
    ];
  });

  # Right side of the bar: volume, battery, clock. Redraws every 10s, or
  # immediately on `dwl-status refresh` (used by the volume keys in config.h).
  dwl-status = pkgs.writeShellApplication {
    name = "dwl-status";
    runtimeInputs = with pkgs; [ coreutils gawk wireplumber ];
    text = ''
      pidfile="''${XDG_RUNTIME_DIR:-/tmp}/dwl-status.pid"

      if [ "''${1:-}" = refresh ]; then
        kill -USR1 "$(cat "$pidfile" 2>/dev/null)" 2>/dev/null || true
        exit 0
      fi

      icon() { printf '^fg(${c.accent})%s^fg() ' "$1"; }

      volume() {
        local out vol
        out=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null) || return 0
        vol=$(awk '{ printf "%d", $2 * 100 + 0.5 }' <<<"$out")
        if [[ $out == *MUTED* ]]; then
          printf '^fg(${c.dim})󰖁 %s%%^fg()' "$vol"
        else
          printf '%s%s%%' "$(icon 󰕾)" "$vol"
        fi
      }

      battery() {
        local bat=/sys/class/power_supply/BAT0 cap status
        local levels=(󰁺 󰁺 󰁻 󰁼 󰁽 󰁾 󰁿 󰂀 󰂁 󰂂 󰁹)
        [ -r "$bat/capacity" ] || return 0
        cap=$(<"$bat/capacity")
        status=$(<"$bat/status")
        if [ "$status" = Charging ]; then
          printf '%s%s%%' "$(icon 󰂄)" "$cap"
        elif ((cap <= 15)); then
          printf '^fg(${c.urgent})󰂃 %s%%^fg()' "$cap"
        else
          printf '%s%s%%' "$(icon "''${levels[cap / 10]}")" "$cap"
        fi
      }

      echo $$ >"$pidfile"
      trap 'rm -f "$pidfile"' EXIT
      trap ':' USR1

      while :; do
        printf '%s    %s    %s\n' "$(volume)" "$(battery)" "$(date '+%a %d %b  %H:%M')"
        sleep 10 &
        sleep_pid=$!
        wait "$sleep_pid" || kill "$sleep_pid" 2>/dev/null || true
      done
    '';
  };

  # Runs as `dwl -s dwl-startup`. Its stdin is dwl's status stream, which the
  # final `exec dwlb` reads, so everything else goes to the background first.
  dwl-startup = pkgs.writeShellApplication {
    name = "dwl-startup";
    runtimeInputs = with pkgs; [ dwlb dwl-status procps dbus wl-clipboard cliphist swaybg ];
    text = ''
      # Hand the session env to D-Bus/systemd activated services (portals,
      # mako, polkit agent) -- only while dwl is the sole session: with niri
      # still running on another tty this would steal its WAYLAND_DISPLAY.
      if ! pgrep -x niri >/dev/null; then
        dbus-update-activation-environment --systemd \
          WAYLAND_DISPLAY DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE
        systemctl --user start polkit-agent.service || true
      fi

      wl-paste --watch cliphist store &

      # plain background color as the wallpaper
      swaybg -c '#${c.bg}' &

      # the status client needs the bar's socket, give dwlb a moment to start
      { sleep 1; dwl-status | dwlb -status-stdin all; } &

      exec dwlb \
        -font "${font}:size=11" \
        -vertical-padding 5 \
        -hide-vacant-tags \
        -no-active-color-title \
        -active-fg-color "#${c.bg}" -active-bg-color "#${c.accent}" \
        -occupied-fg-color "#${c.fg}" -occupied-bg-color "#${c.bg}" \
        -inactive-fg-color "#${c.fg}" -inactive-bg-color "#${c.bg}" \
        -urgent-fg-color "#${c.bg}" -urgent-bg-color "#${c.urgent}" \
        -middle-bg-color "#${c.bg}" -middle-bg-color-selected "#${c.bg}"
    '';
  };

  # Start dwl with this instead of plain `dwl` (from a tty, or later from
  # tuigreet). dwl's own stderr and that of everything it spawns goes to
  # ~/.local/state/dwl.log; the previous run is kept as dwl.log.old.
  dwl-session = pkgs.writeShellApplication {
    name = "dwl-session";
    runtimeInputs = [ dwl dwl-startup ];
    text = ''
      export XDG_CURRENT_DESKTOP=dwl
      export XDG_SESSION_DESKTOP=dwl
      export XDG_SESSION_TYPE=wayland

      log="''${XDG_STATE_HOME:-$HOME/.local/state}/dwl.log"
      mkdir -p "$(dirname "$log")"
      if [ -f "$log" ]; then mv -f "$log" "$log.old"; fi

      exec dwl -s dwl-startup 2>"$log"
    '';
  };
in
{
  home.packages = [
    dwl
    pkgs.dwlb # also used by the Mod+b binding in config.h
    dwl-status
    dwl-session
  ];

  # Lock screen (Mod+Shift+l in config.h; PAM entry in modules/desktop/dwl.nix):
  # blurred screenshot of the desktop with a clock inside the ring, which
  # turns accent while typing, red on a wrong password, yellow on Caps Lock.
  programs.swaylock = {
    enable = true;
    package = pkgs.swaylock-effects;
    settings = {
      screenshots = true;
      effect-scale = "0.5"; # blur a half-size copy: much faster, looks the same
      effect-blur = "7x3";
      effect-vignette = "0.5:0.5";
      fade-in = "0.2";

      clock = true;
      timestr = "%H:%M";
      datestr = "%a, %d %b";
      font = font;
      font-size = 26;

      indicator = true;
      indicator-idle-visible = true; # keep the clock up before any key press
      indicator-caps-lock = true;
      indicator-radius = 110;
      indicator-thickness = 7;
      line-uses-inside = true;
      separator-color = "00000000";
      ignore-empty-password = true;
      show-failed-attempts = true;

      color = c.bg;
      inside-color = "${c.bg}cc";
      inside-clear-color = "${c.bg}cc";
      inside-ver-color = "${c.bg}cc";
      inside-wrong-color = "${c.bg}cc";
      inside-caps-lock-color = "${c.bg}cc";

      ring-color = c.bgAlt;
      ring-clear-color = c.dim;
      ring-ver-color = c.accent;
      ring-wrong-color = c.urgent;
      ring-caps-lock-color = c.warn;

      key-hl-color = c.accent;
      bs-hl-color = c.urgent;
      caps-lock-key-hl-color = c.warn;
      caps-lock-bs-hl-color = c.urgent;

      text-color = c.fg;
      text-clear-color = c.fg;
      text-ver-color = c.accent;
      text-wrong-color = c.urgent;
      text-caps-lock-color = c.warn;

      # us/ru indicator under the ring
      layout-bg-color = "00000000";
      layout-border-color = "00000000";
      layout-text-color = c.dim;
    };
  };

  # Launcher (Mod+p), themed to match the bar. Also what niri's default
  # config.kdl launches on Mod+D.
  programs.fuzzel = {
    enable = true;
    settings = {
      main = {
        font = "${font}:size=12";
        terminal = "ghostty -e";
        width = 40;
        lines = 10;
        horizontal-pad = 20;
        vertical-pad = 12;
        inner-pad = 6;
      };
      colors = {
        background = "${c.bg}f2";
        text = "${c.fg}ff";
        prompt = "${c.accent}ff";
        placeholder = "${c.dim}ff";
        input = "${c.fg}ff";
        match = "${c.accent}ff";
        selection = "${c.bgAlt}ff";
        selection-text = "${c.fg}ff";
        selection-match = "${c.accent}ff";
        border = "${c.accent}ff";
      };
      border = {
        width = 2;
        radius = 0;
      };
    };
  };
}
