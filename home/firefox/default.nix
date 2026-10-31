{ config, lib, pkgs, theme, font, ... }:

let
  # startpage/index.html has @key@ placeholders for the palette colors
  # and @font@ for the monospace font
  startpage = builtins.replaceStrings
    ((lib.mapAttrsToList (key: _: "@${key}@") theme) ++ [ "@font@" ])
    ((lib.mapAttrsToList (_: hex: "#${hex}") theme) ++ [ font.mono ])
    (builtins.readFile ./startpage/index.html);

  startpagePath = "${config.xdg.dataHome}/startpage/index.html";

  # There is no pref or policy for the new tab URL any more, but autoconfig
  # (mozilla.cfg, unsandboxed in Firefox) can set it on AboutNewTab. It stays
  # set through AboutNewTab.init(), which skips overridden URLs.
  newTabCfg = pkgs.writeText "startpage-newtab.js" ''
    // New tabs open the start page (home/firefox/default.nix)
    try {
      const { AboutNewTab } = ChromeUtils.importESModule("resource:///modules/AboutNewTab.sys.mjs");
      AboutNewTab.newTabURL = "file://${startpagePath}";
    } catch (e) {
      Cu.reportError(e);
    }
  '';
in
{
  home.file.${startpagePath}.text = startpage;

  # Firefox itself comes from here (the wrapper carries the policies), not
  # from home.packages. No profiles are declared, so HM writes no
  # profiles.ini and the existing profile is left as it is.
  programs.firefox = {
    enable = true;
    # extraPrefsFiles is appended to mozilla.cfg as is (extraPrefs would go
    # through a shell heredoc); HM's own override keeps it and adds policies.
    package = pkgs.firefox.override { extraPrefsFiles = [ newTabCfg ]; };
    # Firefox already keeps its profile in the XDG location; the HM default
    # for stateVersion < 26.05 is still ~/.mozilla/firefox (and warns).
    configPath = "${config.xdg.configHome}/mozilla/firefox";
    # Only the URL: the startup choice (restore the session or open the
    # homepage) stays whatever is set in Firefox settings.
    policies.Homepage = {
      URL = "file://${startpagePath}";
      Locked = false;
    };
  };
}
