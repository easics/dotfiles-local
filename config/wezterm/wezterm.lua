local w = require("wezterm")
local config = w.config_builder()
local a = w.action

-- Linux shell in my passwd is missing
config.set_environment_variables = { SHELL = "/bin/bash" }
config.default_prog = { "/bin/bash", "-l" }

-- Switch panes using the same keys as nvim
local function is_inside_vim(pane)
  local tty = pane:get_tty_name()
  if tty == nil then
    return false
  end

  local success, stdout, stderr = w.run_child_process({
    "sh",
    "-c",
    "ps -o state= -o comm= -t"
      .. w.shell_quote_arg(tty)
      .. " | "
      .. "grep -iqE '^[^TXZ ]+ +(\\S+\\/)?g?(view|l?n?vim?x?)(diff)?$'",
  })

  return success
end

local function is_outside_vim(pane)
  return not is_inside_vim(pane)
end

local function bind_if(cond, key, mods, action)
  local function callback(win, pane)
    if cond(pane) then
      win:perform_action(action, pane)
    else
      win:perform_action(a.SendKey({ key = key, mods = mods }), pane)
    end
  end

  return { key = key, mods = mods, action = w.action_callback(callback) }
end


config.keys = {
    bind_if(is_outside_vim, "h", "CTRL", a.ActivatePaneDirection("Left")),
    bind_if(is_outside_vim, "l", "CTRL", a.ActivatePaneDirection("Right")),
}

-- Nicer font
config.font = w.font("JetBrainsMono Nerd Font")

-- Try to reduce CPU usage
config.animation_fps = 1
config.cursor_blink_rate = 1000

return config
