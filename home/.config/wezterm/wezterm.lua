local wezterm = require("wezterm")
local config = wezterm.config_builder()

-- ink + signal: near-black surfaces, one electric teal accent, minimal chrome.
local ink = {
  crust = "#07070a",
  mantle = "#0c0c10",
  base = "#101014",
  surface0 = "#16161d",
  surface1 = "#1c1c26",
  surface2 = "#262633",
  overlay = "#858596",
  subtext = "#a3a3b5",
  text = "#e6e6ea",
  signal = "#3dffc0",
  signal_dim = "#1a9e74",
  warn = "#ffb454",
  error = "#ff5c7a",
  info = "#6eb6ff",
  soft = "#9b8cff",
}

local hostname = wezterm.hostname():gsub("%.local$", "")

config.colors = {
  foreground = ink.text,
  background = ink.base,
  cursor_bg = ink.signal,
  cursor_fg = ink.crust,
  cursor_border = ink.signal,
  selection_fg = ink.text,
  selection_bg = ink.surface2,
  scrollbar_thumb = ink.surface2,
  split = ink.surface1,
  ansi = {
    ink.surface1,
    ink.error,
    ink.signal_dim,
    ink.warn,
    ink.info,
    ink.soft,
    ink.signal,
    ink.subtext,
  },
  brights = {
    ink.overlay,
    "#ff7a92",
    ink.signal,
    "#ffc87a",
    "#8fc5ff",
    "#b5a8ff",
    "#7affe0",
    ink.text,
  },
  tab_bar = {
    background = ink.mantle,
    active_tab = {
      bg_color = ink.surface0,
      fg_color = ink.signal,
      intensity = "Bold",
    },
    inactive_tab = {
      bg_color = ink.mantle,
      fg_color = ink.overlay,
    },
    inactive_tab_hover = {
      bg_color = ink.surface0,
      fg_color = ink.subtext,
    },
    new_tab = {
      bg_color = ink.mantle,
      fg_color = ink.overlay,
    },
    new_tab_hover = {
      bg_color = ink.surface0,
      fg_color = ink.signal,
    },
  },
}

config.font = wezterm.font_with_fallback({
  { family = "JetBrainsMono Nerd Font", weight = "Regular" },
  { family = "Symbols Nerd Font Mono", scale = 0.92 },
  { family = "JetBrains Mono", weight = "Regular" },
  "Menlo",
})
config.font_size = 15.0
config.line_height = 1.12
config.freetype_load_target = "Light"
config.freetype_render_target = "HorizontalLcd"

config.max_fps = 120
config.animation_fps = 60
config.cursor_blink_rate = 0
config.default_cursor_style = "SteadyBar"

config.window_decorations = "RESIZE"
config.window_background_opacity = 0.97
config.macos_window_background_blur = 36
config.window_padding = { left = 24, right = 24, top = 20, bottom = 16 }

config.enable_tab_bar = true
config.use_fancy_tab_bar = false
config.tab_bar_at_bottom = true
config.hide_tab_bar_if_only_one_tab = false
config.show_new_tab_button_in_tab_bar = false
config.tab_max_width = 36

config.inactive_pane_hsb = { saturation = 0.85, brightness = 0.85 }
config.bold_brightens_ansi_colors = "BrightAndBold"
config.command_palette_fg_color = ink.text
config.command_palette_bg_color = ink.mantle
config.command_palette_font_size = 14.0

config.audible_bell = "Disabled"
config.window_close_confirmation = "NeverPrompt"

-- Viewer-side image bridge (Frontera WezTerm → Maverick agent).
-- Cmd+Shift+V: clipboard/Desktop shot → scp → paste @/tmp/omp-inbox/...
-- Cmd+Shift+U: rewrite a local drag-drop path on the clipboard the same way.

local function do_bridge(window, pane, file_arg)
  local bridge = os.getenv("HOME") .. "/.local/bin/omp-bridge-image"
  local cmdline = bridge
  if file_arg and file_arg ~= "" then
    cmdline = bridge .. " " .. string.format("%q", file_arg)
  end
  local out_file = os.tmpname()
  local err_file = os.tmpname()
  local ok = os.execute(string.format("%s >%s 2>%s", cmdline, out_file, err_file))
  local f = io.open(out_file, "r")
  local out = f and f:read("*a") or ""
  if f then f:close() end
  local ef = io.open(err_file, "r")
  local err = ef and ef:read("*a") or ""
  if ef then ef:close() end
  os.remove(out_file)
  os.remove(err_file)
  out = (out or ""):gsub("%s+$", "")
  if out == "" then
    window:toast_notification("Image bridge", err ~= "" and err or "no image", nil, 4000)
    return
  end
  window:toast_notification("Image bridge", out, nil, 2500)
  pane:send_text(out)
end

config.keys = {
  {
    key = "v",
    mods = "CMD|SHIFT",
    action = wezterm.action_callback(function(window, pane)
      do_bridge(window, pane, nil)
    end),
  },
  {
    key = "u",
    mods = "CMD|SHIFT",
    action = wezterm.action_callback(function(window, pane)
      -- Rewrite last drag-drop path sitting on the clipboard as text.
      local ok, clip = pcall(function()
        local h = io.popen("pbpaste")
        if not h then return "" end
        local t = h:read("*a") or ""
        h:close()
        return t:gsub("%s+$", "")
      end)
      if not ok or not clip or clip == "" then
        window:toast_notification("OMP bridge", "clipboard empty", nil, 2500)
        return
      end
      -- Only rewrite local image / TemporaryItems / Desktop paths.
      if not clip:match("^/") then
        window:toast_notification("OMP bridge", "clipboard is not a path", nil, 2500)
        return
      end
      do_bridge(window, pane, clip)
    end),
  },
}

-- Clickable links: plain left-click opens a hyperlink under the cursor
-- (CompleteSelectionOrOpenLinkAtMouseCursor). Full mouse map is listed
-- because assigning mouse_bindings replaces WezTerm defaults entirely.
local act = wezterm.action

config.hyperlink_rules = {
  -- Nice labeled OSC-8 / markdown-ish and standard URLs.
  {
    regex = "\\b\\w+://(?:[\\w.-]+)\\S*\\b",
    format = "$0",
  },
  -- Explicit http(s)
  {
    regex = "\\bhttps?://\\S+\\b",
    format = "$0",
  },
  -- Loopback without scheme (agent paste)
  {
    regex = "\\b((?:127\\.0\\.0\\.1|localhost)(?::\\d+)(?:/\\S*)?)",
    format = "http://$1",
  },
}

config.mouse_bindings = {
  -- Triple / double / single select
  {
    event = { Down = { streak = 3, button = "Left" } },
    mods = "NONE",
    action = act.SelectTextAtMouseCursor("Line"),
  },
  {
    event = { Down = { streak = 2, button = "Left" } },
    mods = "NONE",
    action = act.SelectTextAtMouseCursor("Word"),
  },
  {
    event = { Down = { streak = 1, button = "Left" } },
    mods = "NONE",
    action = act.SelectTextAtMouseCursor("Cell"),
  },
  {
    event = { Down = { streak = 1, button = "Left" } },
    mods = "SHIFT",
    action = act.ExtendSelectionToMouseCursor("Cell"),
  },
  {
    event = { Down = { streak = 1, button = "Left" } },
    mods = "ALT",
    action = act.SelectTextAtMouseCursor("Block"),
  },
  -- THE important one: plain click opens link if present, else finishes selection
  {
    event = { Up = { streak = 1, button = "Left" } },
    mods = "NONE",
    action = act.CompleteSelectionOrOpenLinkAtMouseCursor("ClipboardAndPrimarySelection"),
  },
  {
    event = { Up = { streak = 1, button = "Left" } },
    mods = "SHIFT",
    action = act.CompleteSelectionOrOpenLinkAtMouseCursor("ClipboardAndPrimarySelection"),
  },
  {
    event = { Up = { streak = 1, button = "Left" } },
    mods = "ALT",
    action = act.CompleteSelection("ClipboardAndPrimarySelection"),
  },
  {
    event = { Up = { streak = 2, button = "Left" } },
    mods = "NONE",
    action = act.CompleteSelection("ClipboardAndPrimarySelection"),
  },
  {
    event = { Up = { streak = 3, button = "Left" } },
    mods = "NONE",
    action = act.CompleteSelection("ClipboardAndPrimarySelection"),
  },
  -- Drag
  {
    event = { Drag = { streak = 1, button = "Left" } },
    mods = "NONE",
    action = act.ExtendSelectionToMouseCursor("Cell"),
  },
  {
    event = { Drag = { streak = 1, button = "Left" } },
    mods = "ALT",
    action = act.ExtendSelectionToMouseCursor("Block"),
  },
  {
    event = { Drag = { streak = 2, button = "Left" } },
    mods = "NONE",
    action = act.ExtendSelectionToMouseCursor("Word"),
  },
  {
    event = { Drag = { streak = 3, button = "Left" } },
    mods = "NONE",
    action = act.ExtendSelectionToMouseCursor("Line"),
  },
  -- Middle paste
  {
    event = { Down = { streak = 1, button = "Middle" } },
    mods = "NONE",
    action = act.PasteFrom("PrimarySelection"),
  },
  -- Window drag
  {
    event = { Drag = { streak = 1, button = "Left" } },
    mods = "SUPER",
    action = act.StartWindowDrag,
  },
  {
    event = { Drag = { streak = 1, button = "Left" } },
    mods = "CTRL|SHIFT",
    action = act.StartWindowDrag,
  },
}

-- Shared opener used by open-uri and the selection fallback.
local function open_uri_now(window, uri)
  if not uri or uri == "" then
    return
  end
  -- Always route through mav-open-url on frontera (handles loopback + normal).
  -- Elsewhere use macOS open.
  if hostname == "frontera" then
    local opener = os.getenv("HOME") .. "/.local/bin/mav-open-url"
    local log = os.getenv("HOME") .. "/.cache/mav-open-url.log"
    os.execute("mkdir -p " .. string.format("%q", os.getenv("HOME") .. "/.cache"))
    local cmd = string.format(
      "/usr/bin/nohup /bin/bash %q %q >>%s 2>&1 &",
      opener,
      uri,
      log
    )
    os.execute(cmd)
    window:toast_notification("open", uri, nil, 2000)
  else
    os.execute(string.format("/usr/bin/open %q &", uri))
  end
end

-- Fallback: Cmd+Shift+O opens the current selection as a URL.
table.insert(config.keys, {
  key = "o",
  mods = "CMD|SHIFT",
  action = wezterm.action_callback(function(window, pane)
    local uri = window:get_selection_text_for_pane(pane) or ""
    uri = uri:gsub("%s+", "")
    if uri == "" then
      window:toast_notification("open", "select a URL first", nil, 2500)
      return
    end
    if not uri:match("^https?://") and uri:match("^(127%.0%.0%.1|localhost)") then
      uri = "http://" .. uri
    end
    if not uri:match("^https?://") then
      window:toast_notification("open", "selection is not an http(s) URL", nil, 2500)
      return
    end
    open_uri_now(window, uri)
  end),
})

-- Frontera: every opened URI goes through mav-open-url.
wezterm.on("open-uri", function(window, pane, uri)
  if hostname ~= "frontera" then
    return
  end
  open_uri_now(window, uri)
  return false
end)




-- Quiet telemetry rail; visible even with a single tab.
wezterm.on("update-right-status", function(window)
  window:set_right_status(wezterm.format({
    { Foreground = { Color = ink.signal } },
    { Text = " / " },
    { Foreground = { Color = ink.text } },
    { Text = hostname:upper() },
    { Foreground = { Color = ink.overlay } },
    { Text = "   " .. wezterm.strftime("%H:%M") .. "  " },
  }))
end)

wezterm.on("format-tab-title", function(tab, tabs, panes, cfg, hover, max_width)
  local title = tab.tab_title
  if title == "" then
    title = tab.active_pane.title
  end
  title = wezterm.truncate_right(title, math.max(1, max_width - 10))
  return {
    { Background = { Color = tab.is_active and ink.surface1 or ink.mantle } },
    { Foreground = { Color = tab.is_active and ink.signal or ink.overlay } },
    { Text = string.format("  %02d  ", tab.tab_index + 1) },
    { Foreground = { Color = tab.is_active and ink.text or ink.subtext } },
    { Text = title .. "   " },
  }
end)

return config
