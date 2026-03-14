-- wezterm_stub.lua: fake wezterm API for tests running outside WezTerm
local wez = {}

wez._filesystem = {}
wez._logs = {}

function wez._reset()
  wez._filesystem = {}
  wez._logs = {}
end

function wez.home_dir()
  return "/home/testuser"
end

function wez.log_info(msg)
  wez._logs[#wez._logs + 1] = { level = "info", message = msg }
end

function wez.log_warn(msg)
  wez._logs[#wez._logs + 1] = { level = "warn", message = msg }
end

function wez.log_error(msg)
  wez._logs[#wez._logs + 1] = { level = "error", message = msg }
end

function wez.read_dir(path)
  return wez._filesystem[path] or {}
end

wez.action = {}

function wez.action.InputSelector(args)
  return { type = "InputSelector", args = args }
end

function wez.action.SwitchToWorkspace(args)
  return { type = "SwitchToWorkspace", args = args }
end

function wez.action_callback(fn)
  return { type = "action_callback", fn = fn }
end

_G.wezterm = wez

return wez
