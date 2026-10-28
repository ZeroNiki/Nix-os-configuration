/* Taken from https://github.com/djpohly/dwl/issues/466 */
#define COLOR(hex)    { ((hex >> 24) & 0xFF) / 255.0f, \
                        ((hex >> 16) & 0xFF) / 255.0f, \
                        ((hex >> 8) & 0xFF) / 255.0f, \
                        (hex & 0xFF) / 255.0f }
/* appearance */
static const int sloppyfocus               = 1;  /* focus follows mouse */
static const int bypass_surface_visibility = 0;  /* 1 means idle inhibitors will disable idle tracking even if it's surface isn't visible  */
static const unsigned int borderpx         = 2;  /* border pixel of windows */
static const int gappx                     = 8;  /* gap between windows and screen edges (patches/gaps.patch) */
static const unsigned int snap             = 32; /* snap pixel */
/* Everforest Dark Medium: keep these in sync with home/theme/everforest.nix
 * (bgDim, bg3, green, red), which the bar, lock screen and launcher use */
static const float rootcolor[]             = COLOR(0x232a2eff);
static const float bordercolor[]           = COLOR(0x475258ff);
static const float focuscolor[]            = COLOR(0xa7c080ff);
static const float urgentcolor[]           = COLOR(0xe67e80ff);
/* This conforms to the xdg-protocol. Set the alpha to zero to restore the old behavior */
static const float fullscreen_bg[]         = COLOR(0x232a2eff); /* You can also use glsl colors */

/* btrtile (patches/btrtile.patch), set up like bspwm with
 * automatic_scheme longest_side + initial_polarity second_child:
 * a new window halves the focused one along its longer side and goes
 * right/bottom of it; a closed window's sibling takes its place */
static const int use_active_for_splits     = 1;    /* 1: split the focused client, 0: the one under the pointer */
static const int force_split               = 2;    /* 0: new client on the pointer's side, 1: always left/top, 2: always right/bottom */
static const int preserve_split            = 1;    /* 1: a split keeps the direction it got when created */
static const float split_width_multiplier  = 1.0f; /* split side by side when width >= height * this */
static const uint32_t resize_interval_ms   = 16;   /* Mod+right drag updates at most every 16ms */
enum Direction { DIR_LEFT, DIR_RIGHT, DIR_UP, DIR_DOWN };

/* tagging - TAGCOUNT must be no greater than 31 */
#define TAGCOUNT (9)

/* logging */
static int log_level = WLR_ERROR;

static const Rule rules[] = {
	/* app_id             title       tags mask     isfloating   monitor */
	{ "firefox",          "Picture-in-Picture", 0,  1,           -1 },
	{ "org.telegram.desktop", "Media viewer", 0,    1,           -1 },
	{ "org.keepassxc.KeePassXC", "Unlock Database", 0, 1,        -1 },
    /* default/example rule: can be changed but cannot be eliminated; at least one rule must exist */
};

/* layout(s) */
static const Layout layouts[] = {
	/* symbol     arrange function */
	{ "[B]",      btrtile }, /* first: the default on every monitor */
	{ "[]=",      tile },
	{ "><>",      NULL },    /* no layout function means floating behavior */
	{ "[M]",      monocle },
};

/* monitors */
/* (x=-1, y=-1) is reserved as an "autoconfigure" monitor position indicator
 * WARNING: negative values other than (-1, -1) cause problems with Xwayland clients due to
 * https://gitlab.freedesktop.org/xorg/xserver/-/issues/899 */
static const MonitorRule monrules[] = {
   /* name        mfact  nmaster scale layout       rotate/reflect                x    y
    * example of a HiDPI laptop monitor:
    { "eDP-1",    0.5f,  1,      2,    &layouts[0], WL_OUTPUT_TRANSFORM_NORMAL,   -1,  -1 }, */
	{ NULL,       0.55f, 1,      1,    &layouts[0], WL_OUTPUT_TRANSFORM_NORMAL,   -1,  -1 },
	/* default monitor rule: can be changed but cannot be eliminated; at least one monitor rule must exist */
};

/* keyboard */
static const struct xkb_rule_names xkb_rules = {
	.layout = "us,ru",
	.options = "grp:win_space_toggle",
};

/* bar's layout indicator (patches/kblayout-local.patch): on every switch the
 * active layout's name goes to $XDG_RUNTIME_DIR/dwl-kblayout and dwl-status
 * (home/dwl/default.nix) gets SIGUSR1 through its pidfile, like on
 * `dwl-status refresh` */
static const char *kblayout_names[] = { "EN", "RU" }; /* order of .layout above */
static const char kblayout_file[]    = "dwl-kblayout";
static const char kblayout_pidfile[] = "dwl-status.pid";
static const char kblayout_comm[]    = "dwl-status";

static const int repeat_rate = 25;
static const int repeat_delay = 600;

/* Trackpad */
static const int tap_to_click = 1;
static const int tap_and_drag = 1;
static const int drag_lock = 1;
static const int natural_scrolling = 0;
static const int disable_while_typing = 1;
static const int left_handed = 0;
static const int middle_button_emulation = 0;
/* You can choose between:
LIBINPUT_CONFIG_SCROLL_NO_SCROLL
LIBINPUT_CONFIG_SCROLL_2FG
LIBINPUT_CONFIG_SCROLL_EDGE
LIBINPUT_CONFIG_SCROLL_ON_BUTTON_DOWN
*/
static const enum libinput_config_scroll_method scroll_method = LIBINPUT_CONFIG_SCROLL_2FG;

/* You can choose between:
LIBINPUT_CONFIG_CLICK_METHOD_NONE
LIBINPUT_CONFIG_CLICK_METHOD_BUTTON_AREAS
LIBINPUT_CONFIG_CLICK_METHOD_CLICKFINGER
*/
static const enum libinput_config_click_method click_method = LIBINPUT_CONFIG_CLICK_METHOD_BUTTON_AREAS;

/* You can choose between:
LIBINPUT_CONFIG_SEND_EVENTS_ENABLED
LIBINPUT_CONFIG_SEND_EVENTS_DISABLED
LIBINPUT_CONFIG_SEND_EVENTS_DISABLED_ON_EXTERNAL_MOUSE
*/
static const uint32_t send_events_mode = LIBINPUT_CONFIG_SEND_EVENTS_ENABLED;

/* You can choose between:
LIBINPUT_CONFIG_ACCEL_PROFILE_FLAT
LIBINPUT_CONFIG_ACCEL_PROFILE_ADAPTIVE
*/
static const enum libinput_config_accel_profile accel_profile = LIBINPUT_CONFIG_ACCEL_PROFILE_ADAPTIVE;
static const double accel_speed = 0.0;

/* You can choose between:
LIBINPUT_CONFIG_TAP_MAP_LRM -- 1/2/3 finger tap maps to left/right/middle
LIBINPUT_CONFIG_TAP_MAP_LMR -- 1/2/3 finger tap maps to left/middle/right
*/
static const enum libinput_config_tap_button_map button_map = LIBINPUT_CONFIG_TAP_MAP_LRM;

/* If you want to use the windows key for MODKEY, use WLR_MODIFIER_LOGO */
#define MODKEY WLR_MODIFIER_LOGO

#define TAGKEYS(KEY,TAG) \
	{ MODKEY,                    KEY,            view,            {.ui = 1 << TAG} }, \
	{ MODKEY|WLR_MODIFIER_CTRL,  KEY,            toggleview,      {.ui = 1 << TAG} }, \
	{ MODKEY|WLR_MODIFIER_SHIFT, KEY,            tag,             {.ui = 1 << TAG} }, \
	{ MODKEY|WLR_MODIFIER_CTRL|WLR_MODIFIER_SHIFT,KEY,toggletag,  {.ui = 1 << TAG} }

/* helper for spawning shell commands in the pre dwm-5.0 fashion */
#define SHCMD(cmd) { .v = (const char*[]){ "/bin/sh", "-c", cmd, NULL } }

/* commands */
/* --gtk-single-instance=false: otherwise a ghostty already running under niri
 * opens the new window over there instead of in dwl */
static const char *termcmd[] = { "ghostty", "--gtk-single-instance=false", NULL };
static const char *menucmd[] = { "fuzzel", NULL };
/* swaylock-effects, themed in home/dwl/default.nix; -f returns once locked */
static const char *lockcmd[] = { "swaylock", "-f", NULL };
/* lock / suspend / reboot / poweroff through fuzzel (home/dwl/default.nix) */
static const char *powercmd[] = { "powermenu", NULL };

/* dwl-status (home/dwl/default.nix) redraws the bar right away on "refresh" */
#define STATUS(cmd) SHCMD(cmd "; dwl-status refresh")

static const Key keys[] = {
	/* modifier                  key                  function          argument */
	{ MODKEY,                    XKB_KEY_p,           spawn,            {.v = menucmd} },
	{ MODKEY,                    XKB_KEY_Return,      spawn,            {.v = termcmd} },
	{ MODKEY,                    XKB_KEY_b,           spawn,            SHCMD("dwlb -toggle-visibility all") },
	{ MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_s,           spawn,            SHCMD("grim -g \"$(slurp)\" - | wl-copy") },
	{ MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_l,           spawn,            {.v = lockcmd} },
	{ MODKEY,                    XKB_KEY_x,           spawn,            {.v = powercmd} },
	{ 0,                         XKB_KEY_Print,       spawn,            SHCMD("grim - | wl-copy") },
	{ 0,                         XKB_KEY_XF86AudioRaiseVolume,  spawn,  STATUS("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+") },
	{ 0,                         XKB_KEY_XF86AudioLowerVolume,  spawn,  STATUS("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-") },
	{ 0,                         XKB_KEY_XF86AudioMute,         spawn,  STATUS("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle") },
	/* laptop and external monitors together; Mod+[ / Mod+] only the external ones (DDC/CI) */
	{ 0,                         XKB_KEY_XF86MonBrightnessUp,   spawn,  SHCMD("brightness up") },
	{ 0,                         XKB_KEY_XF86MonBrightnessDown, spawn,  SHCMD("brightness down") },
	{ MODKEY,                    XKB_KEY_bracketright, spawn,           SHCMD("brightness ext up") },
	{ MODKEY,                    XKB_KEY_bracketleft,  spawn,           SHCMD("brightness ext down") },
	{ MODKEY,                    XKB_KEY_j,           focusstack,       {.i = +1} },
	{ MODKEY,                    XKB_KEY_k,           focusstack,       {.i = -1} },
	{ MODKEY,                    XKB_KEY_i,           incnmaster,       {.i = +1} },
	{ MODKEY,                    XKB_KEY_d,           incnmaster,       {.i = -1} },
	/* setfact: moves the focused client's vertical split under [B], mfact otherwise */
	{ MODKEY,                    XKB_KEY_h,           setfact,          {.f = -0.05f} },
	{ MODKEY,                    XKB_KEY_l,           setfact,          {.f = +0.05f} },
	{ MODKEY|WLR_MODIFIER_CTRL,  XKB_KEY_k,           setratio_v,       {.f = -0.05f} },
	{ MODKEY|WLR_MODIFIER_CTRL,  XKB_KEY_j,           setratio_v,       {.f = +0.05f} },
	{ MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_Return,      zoom,             {0} },
	{ MODKEY,                    XKB_KEY_Tab,         view,             {0} },
	{ MODKEY,                    XKB_KEY_q,           killclient,       {0} },
	{ MODKEY,                    XKB_KEY_w,           setlayout,        {.v = &layouts[0]} }, /* btrtile */
	{ MODKEY,                    XKB_KEY_t,           setlayout,        {.v = &layouts[1]} }, /* tile */
	{ MODKEY,                    XKB_KEY_f,           setlayout,        {.v = &layouts[2]} }, /* floating */
	{ MODKEY,                    XKB_KEY_m,           setlayout,        {.v = &layouts[3]} }, /* monocle */
	{ MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_space,       togglefloating,   {0} },
	{ MODKEY,                    XKB_KEY_e,           togglefullscreen, {0} },
	{ MODKEY,                    XKB_KEY_0,           view,             {.ui = ~0} },
	{ MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_0,           tag,              {.ui = ~0} },
	{ MODKEY,                    XKB_KEY_comma,       focusmon,         {.i = WLR_DIRECTION_LEFT} },
	{ MODKEY,                    XKB_KEY_period,      focusmon,         {.i = WLR_DIRECTION_RIGHT} },
	{ MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_comma,       tagmon,           {.i = WLR_DIRECTION_LEFT} },
	{ MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_period,      tagmon,           {.i = WLR_DIRECTION_RIGHT} },
	/* btrtile: swap with the neighbour in a direction, flip/mirror the split */
	{ MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_Up,          swapclients,      {.ui = DIR_UP} },
	{ MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_Down,        swapclients,      {.ui = DIR_DOWN} },
	{ MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_Left,        swapclients,      {.ui = DIR_LEFT} },
	{ MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_Right,       swapclients,      {.ui = DIR_RIGHT} },
	{ MODKEY|WLR_MODIFIER_CTRL,  XKB_KEY_t,           togglesplit,      {0} },
	{ MODKEY|WLR_MODIFIER_CTRL,  XKB_KEY_y,           swapsplit,        {0} },
	TAGKEYS(                     XKB_KEY_1,           0),
	TAGKEYS(                     XKB_KEY_2,           1),
	TAGKEYS(                     XKB_KEY_3,           2),
	TAGKEYS(                     XKB_KEY_4,           3),
	TAGKEYS(                     XKB_KEY_5,           4),
	TAGKEYS(                     XKB_KEY_6,           5),
	TAGKEYS(                     XKB_KEY_7,           6),
	TAGKEYS(                     XKB_KEY_8,           7),
	TAGKEYS(                     XKB_KEY_9,           8),
	{ MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_q,           quit,             {0} },

	/* Ctrl-Alt-Backspace and Ctrl-Alt-Fx used to be handled by X server */
	{ WLR_MODIFIER_CTRL|WLR_MODIFIER_ALT,XKB_KEY_BackSpace, quit, {0} },
	/* Ctrl-Alt-Fx is used to switch to another VT, if you don't know what a VT is
	 * do not remove them.
	 */
#define CHVT(n) { WLR_MODIFIER_CTRL|WLR_MODIFIER_ALT,XKB_KEY_F##n, chvt, {.ui = (n)} }
	CHVT(1), CHVT(2), CHVT(3), CHVT(4), CHVT(5), CHVT(6),
	CHVT(7), CHVT(8), CHVT(9), CHVT(10), CHVT(11), CHVT(12),
};

static const Button buttons[] = {
	{ MODKEY, BTN_LEFT,   moveresize,     {.ui = CurMove} },
	{ MODKEY, BTN_MIDDLE, togglefloating, {0} },
	{ MODKEY, BTN_RIGHT,  moveresize,     {.ui = CurResize} },
};

static const Axis axes[] = {
	{ MODKEY, AxisUp,   spawn, SHCMD("volume-up_EXAMPLE") },
	{ MODKEY, AxisDown, spawn, SHCMD("volume-down_EXAMPLE") },
};
