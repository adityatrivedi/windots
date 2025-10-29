local wezterm = require 'wezterm'

local config = wezterm.config_builder and wezterm.config_builder() or {}

-- Font fallback (first available in list is used) + emoji
config.font = wezterm.font_with_fallback {
  'Cascadia Code NF',
  'CaskaydiaCove Nerd Font',
  'Cascadia Code',
  'Consolas',
  'Segoe UI Emoji',
}
config.font_size = 11.0

-- UI basics
config.color_scheme = 'Catppuccin Macchiato'
config.hide_tab_bar_if_only_one_tab = true
config.use_fancy_tab_bar = false
config.show_tab_index_in_tab_bar = true
config.window_decorations = 'RESIZE'
config.audible_bell = 'Disabled'
config.window_close_confirmation = "NeverPrompt"

-- Default shell: prefer PowerShell 7 if present
local function has(exe)
  for dir in string.gmatch(os.getenv('PATH') or '', '([^;]+)') do
    local f = io.open(dir .. '\\' .. exe, 'r'); if f then f:close(); return true end
  end
end
config.default_prog = has('pwsh.exe') and { 'pwsh.exe', '-NoLogo' } or { 'powershell.exe', '-NoLogo' }

-- Pass through XDG_CONFIG_HOME for spawned shells
local home = os.getenv('USERPROFILE') or os.getenv('HOME') or ''
config.set_environment_variables = {
  XDG_CONFIG_HOME = os.getenv('XDG_CONFIG_HOME') or (home .. '\\.config'),
}

-- Keybindings
local act = wezterm.action
config.keys = {
  -- Clipboard
  { key = 'v', mods = 'CTRL|SHIFT', action = act.PasteFrom 'Clipboard' },
  { key = 'c', mods = 'CTRL|SHIFT', action = act.CopyTo 'Clipboard' },
  -- Tab management
  { key = 't', mods = 'CTRL|SHIFT', action = act.SpawnTab 'CurrentPaneDomain' },
  { key = 'w', mods = 'CTRL|SHIFT', action = act.CloseCurrentTab { confirm = true } },
  -- Tab navigation
  { key = 'Tab', mods = 'CTRL|SHIFT', action = act.ActivateTabRelative(-1) },
}

return config
