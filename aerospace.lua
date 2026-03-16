-- aerospace.lua — Hammerspoon menubar widget for AeroSpace window manager
--
-- Shows workspaces in the menubar with focused workspace highlighted,
-- lists windows per workspace, and allows switching via click.

local M = {}

local AEROSPACE = "/Users/pierrebaillet/bin/aerospace"
local REFRESH_INTERVAL = 20 -- seconds

-- State
local menubar = nil
local refreshTimer = nil
local cachedWorkspaces = nil
local cachedFocusedWs = nil

-- Run aerospace CLI asynchronously, call callback(parsed_json) when done
local function aerospace(args, callback)
  local argList = {}
  for word in args:gmatch("%S+") do
    table.insert(argList, word)
  end

  local startTime = hs.timer.absoluteTime()
  hs.task.new(AEROSPACE, function(exitCode, stdOut, stdErr)
    local elapsed = (hs.timer.absoluteTime() - startTime) / 1e6 -- ms
    print(string.format("aerospace: %s completed in %.1fms (exit %d)", args, elapsed, exitCode))
    if exitCode ~= 0 then
      if stdErr and stdErr ~= "" then print("stderr: " .. stdErr) end
      callback(nil)
      return
    end
    local ok, result = pcall(hs.json.decode, stdOut)
    if not ok then
      print("aerospace: JSON parse error for: " .. args)
      print("output was: " .. stdOut)
      callback(nil)
      return
    end
    callback(result)
  end, argList):start()
end

-- Fetch all workspace/window state asynchronously, then call callback(workspaces, focusedWs)
local function fetchState(callback)
  aerospace("list-workspaces --focused --json", function(focused)
    local focusedWs = focused and focused[1] and focused[1]["workspace"] or nil

    aerospace("list-workspaces --all --json", function(allWorkspaces)
      if not allWorkspaces then
        callback(nil, nil)
        return
      end

      local workspaces = {}
      local pending = #allWorkspaces
      if pending == 0 then
        callback(workspaces, focusedWs)
        return
      end

      for i, ws in ipairs(allWorkspaces) do
        local name = ws["workspace"]
        aerospace("list-windows --workspace " .. name .. " --json", function(windows)
          workspaces[i] = {
            name = name,
            focused = (name == focusedWs),
            windows = windows or {},
          }
          pending = pending - 1
          if pending == 0 then
            callback(workspaces, focusedWs)
          end
        end)
      end
    end)
  end)
end

-- Build the menubar title showing workspace indicators
local function buildTitle(workspaces, focusedWs)
  local parts = {}
  for _, ws in ipairs(workspaces) do
    if ws.focused or #ws.windows > 0 then
      if ws.focused then
	table.insert(parts, "[" .. ws.name .. "]")
      else
	table.insert(parts, ws.name)
      end
    end
  end
  return table.concat(parts, " ")
end

-- Build the dropdown menu
local function buildMenu(workspaces)
  local items = {}

  for _, ws in ipairs(workspaces) do
    -- Skip empty non-focused workspaces
    if ws.focused or #ws.windows > 0 then
      local prefix = ws.focused and "▶ " or "  "
      local windowCount = #ws.windows > 0 and " (" .. #ws.windows .. ")" or ""

      table.insert(items, {
	title = prefix .. "Workspace " .. ws.name .. windowCount,
	fn = function()
	  hs.task.new(AEROSPACE, function() M.refresh() end, {"workspace", ws.name}):start()
	end,
	checked = ws.focused,
      })

      -- Add window sub-items
      for _, win in ipairs(ws.windows) do
	local appName = win["app-name"] or "?"
	local winTitle = win["window-title"] or ""
	local windowId = tostring(win["window-id"])

	-- Truncate long titles
	if #winTitle > 50 then
	  winTitle = winTitle:sub(1, 47) .. "..."
	end

	local label = "      " .. appName
	if winTitle ~= "" and winTitle ~= appName then
	  label = label .. " — " .. winTitle
	end

	table.insert(items, {
	  title = label,
	  fn = function()
	    hs.task.new(AEROSPACE, function() M.refresh() end, {"focus", "--window-id", windowId}):start()
	  end,
	  indent = 1,
	})
      end
    end
  end

  table.insert(items, { title = "-" })
  table.insert(items, {
    title = "Refresh",
    fn = function()
      M.refresh()
    end,
  })

  return items
end

function M.refresh()
  if not menubar then
    return
  end

  fetchState(function(workspaces, focusedWs)
    if not workspaces then
      menubar:setTitle("✈ ?")
      return
    end

    cachedWorkspaces = workspaces
    cachedFocusedWs = focusedWs

    local title = buildTitle(workspaces, focusedWs)
    menubar:setTitle("✈ " .. title)
    menubar:setMenu(function()
      if not cachedWorkspaces then
        return {}
      end
      return buildMenu(cachedWorkspaces)
    end)
  end)
end

function M.start()
  if menubar then
    return
  end

  menubar = hs.menubar.new()
  if not menubar then
    print("aerospace: failed to create menubar")
    return
  end

  M.refresh()

  -- refreshTimer = hs.timer.doEvery(REFRESH_INTERVAL, function()
    -- 	M.refresh()
    -- end)

    print("aerospace: menubar widget started")
end

function M.stop()
  if refreshTimer then
    refreshTimer:stop()
    refreshTimer = nil
  end
  if menubar then
    menubar:delete()
    menubar = nil
  end
  print("aerospace: menubar widget stopped")
end

return M
