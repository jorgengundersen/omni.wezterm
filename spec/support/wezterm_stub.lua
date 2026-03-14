-- wezterm_stub.lua: fake wezterm API for tests running outside WezTerm
local wez = {}

wez._filesystem = {}
wez._logs = {}
wez._child_process_responses = {}
wez._workspace_names = {}
wez._performed_actions = {}
wez._toasts = {}
wez.target_triple = "x86_64-unknown-linux-gnu"

function wez._reset()
  wez._filesystem = {}
  wez._files = {}
  wez._logs = {}
  wez._child_process_responses = {}
  wez._workspace_names = {}
  wez._performed_actions = {}
  wez._toasts = {}
  wez.target_triple = "x86_64-unknown-linux-gnu"
end

wez.mux = {}

function wez.mux.get_workspace_names()
  return wez._workspace_names
end

function wez._mock_window()
  local win = {}
  function win:perform_action(action, pane) -- luacheck: no unused args
    wez._performed_actions[#wez._performed_actions + 1] = { action = action, pane = pane }
  end
  function win:toast_notification(title, message) -- luacheck: no unused args
    wez._toasts[#wez._toasts + 1] = { title = title, message = message }
  end
  return win
end

function wez.run_child_process(args)
  local key = args[1]
  local response = wez._child_process_responses[key]
  if response then
    return response[1], response[2], response[3]
  end
  return false, "", ""
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
  return wez._filesystem[path]
end

wez._files = {}

function wez.read_file(path)
  local content = wez._files[path]
  if content == nil then
    return nil
  end
  return content
end

wez.serde = {}

function wez.serde.toml_decode(_str)
  -- Stub: tests should override this per-test via spy/stub
  error("wezterm.serde.toml_decode not stubbed for this input")
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
