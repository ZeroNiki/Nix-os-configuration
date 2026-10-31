{ config, lib, pkgs, theme, font, ... }:

let
  # Everforest Dark Medium (theme/everforest.nix) under the role names
  # the rest of this file uses.
  c = {
    bg = theme.bg0;
    bgAlt = theme.bg1;
    fg = theme.fg;
    dim = theme.grey1;
    accent = theme.green;
    urgent = theme.red;
    warn = theme.yellow;
  };

  # config.h lives next to this file, rebuild after every edit. Its colors
  # are @key@ placeholders for the palette keys (@bgDim@ -> 232a2e), filled
  # in here like the Firefox start page's; line numbers stay the same.
  configH = pkgs.writeText "config.h" (builtins.replaceStrings
    (lib.mapAttrsToList (key: _: "@${key}@") theme)
    (lib.attrValues theme) # same (sorted) key order
    (builtins.readFile ./config.h));

  dwl = (pkgs.dwl.override { inherit configH; }).overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      ./patches/gaps.patch # gappx in config.h
      ./patches/keys-latin.patch # bindings keep working on the "ru" layout
      # bspwm-like tree layout, codeberg.org/dwl/dwl-patches btrtile v0.9 as is,
      # then our changes to it (gappx, Mod+h/l); settings in config.h
      ./patches/btrtile.patch
      ./patches/btrtile-local.patch
      # EN/RU for dwl-status on every layout switch, settings in config.h
      ./patches/kblayout-local.patch
      # Num Lock on at startup, numlock in config.h
      ./patches/numlock-local.patch
    ];
  });

  # Connected outputs other than the laptop panel, one per line (card2-HDMI-A-2).
  # Plain sysfs reads, so `brightness` and the bar can afford it on every call.
  drmExternals = ''
    externals() {
      local s n
      for s in /sys/class/drm/card*-*/status; do
        [ -r "$s" ] && [ "$(<"$s")" = connected ] || continue
        n=''${s%/status}
        n=''${n##*/}
        case $n in *-eDP-* | *-LVDS-* | *-DSI-*) ;; *) echo "$n" ;; esac
      done
    }
  '';

  # Right side of the bar: do-not-disturb (only while on), keyboard layout,
  # network, Bluetooth, volume (+ a muted microphone), brightness, battery, clock. Redraws every 10s, or immediately on SIGUSR1: from
  # `dwl-status refresh` (the volume and brightness keys in config.h) and from dwl itself on
  # a layout switch (patches/kblayout-local.patch). Clicking the network
  # block opens nmtui, the Bluetooth one bluetui (both in ghostty).
  dwl-status = pkgs.writeShellApplication {
    name = "dwl-status";
    runtimeInputs = with pkgs; [ coreutils gawk gnused wireplumber networkmanager bluez brightnessctl mako ];
    text = ''
      pidfile="''${XDG_RUNTIME_DIR:-/tmp}/dwl-status.pid"
      kbfile="''${XDG_RUNTIME_DIR:-/tmp}/dwl-kblayout"
      extfile="''${XDG_RUNTIME_DIR:-/tmp}/brightness/ext"

      if [ "''${1:-}" = refresh ]; then
        kill -USR1 "$(cat "$pidfile" 2>/dev/null)" 2>/dev/null || true
        exit 0
      fi

      icon() { printf '^fg(${c.accent})%s^fg() ' "$1"; }

      # at most $2 characters, '^' escaped for dwlb
      shorten() {
        local s=$1
        if ((''${#s} > $2)); then s="''${s:0:$2-1}…"; fi
        printf '%s' "''${s//^/^^}"
      }

      # mako's do-not-disturb mode (Mod+Shift+n), nothing while it's off
      dnd() {
        if [[ $(makoctl mode 2>/dev/null) == *do-not-disturb* ]]; then
          printf '^fg(${c.dim})󰂛^fg()'
        fi
      }

      # EN/RU, written by dwl (patches/kblayout-local.patch)
      kblayout() {
        [ -r "$kbfile" ] || return 0
        printf '%s%s' "$(icon 󰌌)" "$(<"$kbfile")"
      }

      # Ethernet wins over Wi-Fi; the Wi-Fi list comes from NetworkManager's
      # cache (--rescan no), so this never triggers a scan
      network() {
        local devices type state line signal ssid wifi=0 eth=0
        local levels=(󰤯 󰤟 󰤢 󰤥 󰤨)
        devices=$(nmcli -t -f TYPE,STATE device 2>/dev/null) || return 0
        while IFS=: read -r type state; do
          [ "$state" = connected ] || continue
          case $type in
            ethernet) eth=1 ;;
            wifi) wifi=1 ;;
          esac
        done <<<"$devices"

        if ((eth)); then
          printf '%seth' "$(icon 󰈀)"
        elif ((wifi)); then
          line=$(nmcli -t -f ACTIVE,SIGNAL,SSID device wifi list --rescan no 2>/dev/null |
            grep -m1 '^yes:') || line=
          signal=''${line#yes:}
          signal=''${signal%%:*}
          [[ $signal =~ ^[0-9]+$ ]] || signal=0
          ssid=''${line#yes:*:}
          ssid=''${ssid//\\:/:} # nmcli -t escapes ':' in the SSID
          printf '%s%s %s%%' "$(icon "''${levels[signal * 4 / 100]}")" "$(shorten "''${ssid:-wifi}" 12)" "$signal"
        else
          printf '^fg(${c.urgent})󰤮^fg()'
        fi
      }

      # nothing without an adapter; bluetoothctl waits forever for a missing
      # bluetoothd, hence the timeouts
      bluetooth() {
        local show names
        show=$(timeout 2 bluetoothctl show 2>/dev/null) || return 0
        [[ $show == Controller* ]] || return 0
        if [[ $show != *"Powered: yes"* ]]; then
          printf '^fg(${c.dim})󰂲^fg()'
          return 0
        fi
        mapfile -t names < <(timeout 2 bluetoothctl devices Connected 2>/dev/null |
          sed -n 's/^Device [0-9A-Fa-f:]\{17\} //p')
        case ''${#names[@]} in
          0) printf '^fg(${c.accent})󰂯^fg()' ;;
          1) printf '%s%s' "$(icon 󰂱)" "$(shorten "''${names[0]}" 12)" ;;
          *) printf '%s%s' "$(icon 󰂱)" "''${#names[@]}" ;;
        esac
      }

      volume() {
        local out vol mic
        out=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null) || return 0
        vol=$(awk '{ printf "%d", $2 * 100 + 0.5 }' <<<"$out")
        if [[ $out == *MUTED* ]]; then
          printf '^fg(${c.dim})󰖁 %s%%^fg()' "$vol"
        else
          printf '%s%s%%' "$(icon 󰕾)" "$vol"
        fi
        # the microphone only shows up while muted (XF86AudioMicMute)
        if mic=$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null) && [[ $mic == *MUTED* ]]; then
          printf ' ^fg(${c.urgent})󰍭^fg()'
        fi
      }

      ${drmExternals}

      # laptop backlight, plus the external monitor's value as `brightness`
      # last set it over DDC: asking the monitor takes ddcutil far too long
      backlight() {
        local out pct
        out=$(brightnessctl -m -c backlight 2>/dev/null) || return 0
        IFS=, read -r _ _ _ pct _ <<<"$out"
        printf '%s%s' "$(icon 󰃠)" "$pct"
        if [ -r "$extfile" ] && [ -n "$(externals)" ]; then
          printf ' %s%s%%' "$(icon 󰍹)" "$(<"$extfile")"
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
      signalled=0
      trap 'signalled=1' USR1

      # network and Bluetooth (nmcli, bluetoothctl: the slow ones) only every
      # 10s, a redraw on SIGUSR1 reuses them so EN/RU, volume and brightness
      # show at once
      last=-10 net="" bt=""
      while :; do
        signalled=0
        if ((SECONDS - last >= 10)); then
          last=$SECONDS
          net=$(network)
          net=''${net:+^lm(ghostty -e nmtui)$net^lm()}
          bt=$(bluetooth)
          bt=''${bt:+^lm(ghostty -e bluetui)$bt^lm()}
        fi

        line=""
        for block in "$(dnd)" "$(kblayout)" "$net" "$bt" "$(volume)" "$(backlight)" "$(battery)" "$(date '+%a %d %b  %H:%M')"; do
          if [ -n "$block" ]; then line+="''${line:+    }$block"; fi
        done
        printf '%s\n' "$line"

        sleep 10 &
        sleep_pid=$!
        # a SIGUSR1 during the redraw above: don't wait for the next tick
        if ((!signalled)); then wait "$sleep_pid" || true; fi
        kill "$sleep_pid" 2>/dev/null || true
      done
    '';
  };

  # `brightness [ext] up|down|set N` (the brightness keys in config.h): the
  # laptop backlight with brightnessctl, at once, and every external monitor
  # over DDC/CI with ddcutil, in the background (hundreds of ms per call).
  # `ext` leaves the laptop alone; `brightness detect` forgets the cached
  # monitor list, e.g. after turning DDC/CI on in the monitor's menu.
  #
  # Key presses only add their step to $state/pending; one worker at a time
  # (flock -n) takes the sum and sets the final value, so holding the key
  # never queues up ddcutil runs. Monitor buses come from `ddcutil detect`,
  # cached per set of connected outputs, so plugging a monitor in or out
  # (kanshi or not) re-detects on the next press. Without an external
  # output ddcutil never runs; without a working DDC it fails silently.
  brightness = pkgs.writeShellApplication {
    name = "brightness";
    runtimeInputs = with pkgs; [ coreutils gawk util-linux brightnessctl ddcutil dwl-status ];
    text = ''
      state="''${XDG_RUNTIME_DIR:-/tmp}/brightness"
      mkdir -p "$state"
      step=5
      # add --sleep-multiplier=2 if a monitor drops commands (seen on NVIDIA)
      ddc=(ddcutil)

      usage() {
        echo "usage: brightness [ext] up|down|set PERCENT | brightness detect" >&2
        exit 2
      }

      ${drmExternals}

      # brightnessctl value (5%+, 5%-, 40%), never below 1% so it doesn't go black
      laptop() {
        local max
        max=$(brightnessctl -c backlight max 2>/dev/null) || return 0
        brightnessctl -q -c backlight --min-value=$((max >= 100 ? max / 100 : 1)) set "$1" || true
      }

      # $state/pending is "ABS REL": a percentage from `set` (- if none) and
      # the steps added since; queue adds one press, take empties it
      queue() {
        (
          flock 8
          local abs=- rel=0
          if [ -r "$state/pending" ]; then read -r abs rel <"$state/pending"; fi
          if [ "$1" != - ]; then abs=$1 rel=0; fi
          echo "$abs $((rel + $2))" >"$state/pending"
        ) 8>"$state/pending.lock"
      }
      take() {
        (
          flock 8
          cat "$state/pending" 2>/dev/null || true
          rm -f "$state/pending"
        ) 8>"$state/pending.lock"
      }

      # I2C bus numbers of the monitors that answer DDC, one per line
      buses() {
        local fp
        fp=$(externals | tr '\n' ' ')
        if [ "$(head -n1 "$state/displays" 2>/dev/null)" != "$fp" ]; then
          {
            echo "$fp"
            "''${ddc[@]}" detect --terse 2>/dev/null |
              awk '/^Display /{ok=1} /^Invalid display/{ok=0} ok && /I2C bus:/{sub(/.*\/dev\/i2c-/, ""); print}' || true
          } >"$state/displays.tmp"
          mv -f "$state/displays.tmp" "$state/displays"
        fi
        tail -n +2 "$state/displays"
      }

      # one pending change onto every monitor; now/top (current raw value,
      # max) are the worker's, so getvcp runs once per monitor per burst
      apply() {
        local abs rel bus out cur max pct shown=""
        read -r abs rel < <(take) || return 0
        for bus in $(buses); do
          if [ -z "''${now[$bus]:-}" ]; then
            # "VCP 10 C 50 100"
            if out=$("''${ddc[@]}" --bus "$bus" --skip-ddc-checks getvcp 10 --brief 2>/dev/null) &&
              read -r _ _ _ cur max <<<"$out" && ((max > 0)); then
              now[$bus]=$cur top[$bus]=$max
            else
              rm -f "$state/displays" # gone or DDC off: detect again next time
              continue
            fi
          fi
          if [ "$abs" != - ]; then pct=$abs; else pct=$(((now[$bus] * 100 + top[$bus] / 2) / top[$bus])); fi
          pct=$((pct + rel))
          pct=$((pct < 0 ? 0 : pct > 100 ? 100 : pct))
          cur=$((pct * top[$bus] / 100))
          if ((cur == now[$bus])); then
            shown=''${shown:-$pct} # already there, e.g. more presses at 100%
          elif "''${ddc[@]}" --bus "$bus" --skip-ddc-checks --noverify setvcp 10 "$cur" >/dev/null 2>&1; then
            now[$bus]=$cur
            shown=''${shown:-$pct}
          else
            unset "now[$bus]"
            rm -f "$state/displays"
          fi
        done
        if [ -n "$shown" ]; then echo "$shown" >"$state/ext"; else rm -f "$state/ext"; fi
        dwl-status refresh
      }

      worker() {
        local -A now=() top=()
        while :; do
          (
            flock -n 9 || exit 1 # another worker is on it and will see our change
            while [ -s "$state/pending" ]; do apply; done
          ) 9>"$state/worker.lock" || return 0
          # a press that came in while the lock was still held left its change
          # in pending and gave up on the lock: it's ours
          [ -s "$state/pending" ] || return 0
        done
      }

      target=all
      if [ "''${1:-}" = ext ]; then
        target=ext
        shift
      fi
      case ''${1:-} in
        up) arg=$step%+ abs=- rel=$step ;;
        down) arg=$step%- abs=- rel=-$step ;;
        set)
          if ! [[ ''${2:-} =~ ^[0-9]+$ ]] || ((10#$2 > 100)); then usage; fi
          arg=$((10#$2))% abs=$((10#$2)) rel=0
          ;;
        detect)
          rm -f "$state/displays" "$state/ext"
          exit 0
          ;;
        *) usage ;;
      esac

      if [ "$target" = all ]; then laptop "$arg"; fi
      if [ -n "$(externals)" ]; then
        queue "$abs" "$rel"
        worker </dev/null >/dev/null 2>&1 &
      fi
      dwl-status refresh
    '';
  };

  # Mod+x: lock / suspend / reboot / poweroff through fuzzel. Suspend locks
  # first by itself (swayidle's before-sleep below).
  powermenu = pkgs.writeShellApplication {
    name = "powermenu";
    runtimeInputs = [ config.programs.fuzzel.package config.programs.swaylock.package ];
    text = ''
      choice=$(printf '%s\n' "󰌾  lock" "󰤄  suspend" "󰜉  reboot" "󰐥  poweroff" |
        fuzzel --dmenu --prompt "power: " --lines 4 --width 20) || exit 0
      case $choice in
        *lock) swaylock -f ;;
        *suspend) systemctl suspend ;;
        *reboot) systemctl reboot ;;
        *poweroff) systemctl poweroff ;;
      esac
    '';
  };

  # Runs as `dwl -s dwl-startup`. Its stdin is dwl's status stream, which the
  # final `exec dwlb` reads, so everything else goes to the background first.
  dwl-startup = pkgs.writeShellApplication {
    name = "dwl-startup";
    runtimeInputs = with pkgs; [ dwlb dwl-status dbus ];
    text = ''
      # Hand the session env to D-Bus/systemd activated services (portals,
      # mako), then start the user services of the session (polkit agent,
      # swayidle, cliphist, wpaperd, kanshi, ...) through dwl-session.target below.
      dbus-update-activation-environment --systemd \
        WAYLAND_DISPLAY DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE
      systemctl --user start dwl-session.target || true

      # the status client needs the bar's socket, give dwlb a moment to start
      { sleep 1; dwl-status | dwlb -status-stdin all; } &

      exec dwlb \
        -font "${font.mono}:pixelsize=16" \
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

      # not exec'd: once dwl exits, stop the session's user services, so they
      # don't linger with a dead WAYLAND_DISPLAY until the next login
      status=0
      dwl -s dwl-startup 2>"$log" || status=$?
      systemctl --user stop dwl-session.target || true
      systemctl --user unset-environment WAYLAND_DISPLAY DISPLAY || true
      exit "$status"
    '';
  };
in
{
  # dwl has no systemd integration of its own, this is the same setup as
  # Home Manager's sway-session.target: dwl-startup starts it, which pulls
  # in graphical-session.target and with it every user service WantedBy
  # that (polkit agent from modules/desktop/dwl.nix, swayidle below, cliphist,
  # wpaperd, kanshi and wlsunset from home/desktop/common.nix). dwl-session stops it after dwl
  # exits; graphical-session.target is StopWhenUnneeded and those services
  # are PartOf it, so they all go down with it.
  systemd.user.targets.dwl-session = {
    Unit = {
      Description = "dwl compositor session";
      Documentation = [ "man:systemd.special(7)" ];
      BindsTo = [ "graphical-session.target" ];
      Wants = [ "graphical-session-pre.target" ];
      After = [ "graphical-session-pre.target" ];
    };
  };

  home.packages = [
    dwl
    pkgs.dwlb # also used by the Mod+b binding in config.h
    dwl-status
    dwl-session
    brightness
    powermenu
    pkgs.ddcutil # DDC/CI by hand: `ddcutil detect`, `ddcutil getvcp 10`
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
      font = font.mono;
      font-size = 28; # px (cairo)

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
      inside-color = c.bg;
      inside-clear-color = c.bg;
      inside-ver-color = c.bg;
      inside-wrong-color = c.bg;
      inside-caps-lock-color = c.bg;

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

  # --- Idle and suspend ---
  # Lock after 5 min without input, screens off after 10 (any input turns
  # them back on), and lock before every suspend: lid, `systemctl suspend`,
  # the power menu. -w (swayidle's default extraArgs here) makes logind wait
  # until swaylock -f has actually locked, so the laptop never wakes up
  # unlocked. Video in mpv/Firefox holds an idle inhibitor, then none of the
  # timeouts fire. The pgrep keeps a second swaylock from starting over a
  # locked screen. wlopm: dwl speaks wlr-output-power-management; it's
  # wrapped in a script so the '*' needs no quoting inside swayidle's ExecStart.
  services.swayidle =
    let
      lock = "${pkgs.procps}/bin/pgrep -x swaylock >/dev/null || ${config.programs.swaylock.package}/bin/swaylock -f";
      screens = pkgs.writeShellScript "screens" ''exec ${pkgs.wlopm}/bin/wlopm "--$1" '*' '';
    in
    {
      enable = true;
      events = {
        before-sleep = lock;
        after-resume = "${screens} on";
        lock = lock; # `loginctl lock-session`
      };
      timeouts = [
        {
          timeout = 300;
          command = lock;
        }
        {
          timeout = 600;
          command = "${screens} off";
          resumeCommand = "${screens} on";
        }
      ];
    };

  # Launcher (Mod+p), themed to match the bar.
  programs.fuzzel = {
    enable = true;
    settings = {
      main = {
        # pixelsize: with size= fuzzel would scale by each monitor's DPI
        font = "${font.mono}:pixelsize=20";
        terminal = "ghostty -e";
        width = 40;
        lines = 10;
        horizontal-pad = 20;
        vertical-pad = 12;
        inner-pad = 6;
      };
      colors = {
        background = "${c.bg}ff";
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
