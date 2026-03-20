-- aerospace.lua — Hammerspoon menubar widget for AeroSpace window manager
--
-- Shows workspaces as colored pills with real app icons in the menubar.
-- Click a pill to switch to that workspace.

local M = {}
local aerospaceHelp = require("aerospace_help")

local AEROSPACE = "/Users/pierrebaillet/bin/aerospace"
local POLL_INTERVAL = 2 -- seconds — lightweight poll (focused ws + its windows only)

-- Detect menubar height: notch Macs = 37pt, non-notch = 24pt
local function getMenubarHeight()
  local screen = hs.screen.mainScreen()
  if not screen then return 24 end
  local full = screen:fullFrame()
  local usable = screen:frame()
  return usable.y - full.y
end

-- Sizing constants for canvas rendering (computed from menubar height)
local MENUBAR_H    = getMenubarHeight()
local CANVAS_H     = MENUBAR_H - 2  -- 1px padding top/bottom
local PILL_H       = CANVAS_H - 2   -- 1px padding inside canvas
local PILL_RADIUS  = PILL_H / 2  -- fully rounded (capsule shape)
local PILL_GAP     = 3
local PILL_PAD_X   = 6
local ICON_SIZE    = 16
local ICON_W       = 18
local WS_FONT_SIZE = ICON_SIZE - 2  -- smaller, aligned with icons
local WS_TEXT_W    = 10
local MAX_ICONS    = 3

-- Colors
local COLOR_FOCUSED_BG   = { red = 0.2, green = 0.5, blue = 1.0, alpha = 0.9 }
local COLOR_UNFOCUSED_BG = { red = 0.5, green = 0.5, blue = 0.5, alpha = 0.3 }
local COLOR_FOCUSED_FG   = { red = 1.0, green = 1.0, blue = 1.0, alpha = 1.0 }
local COLOR_UNFOCUSED_FG = { red = 0.7, green = 0.7, blue = 0.7, alpha = 0.8 }

-- State
local menubar = nil
local refreshTimer = nil
local cachedWorkspaces = nil
local cachedFocusedWs = nil
local cachedPills = nil  -- pill layout data for click detection

-- Build a lookup table: lowercase app name → bundle ID from running apps
local function buildBundleIDMap()
  local map = {}
  for _, app in ipairs(hs.application.runningApplications()) do
    local name = app:name()
    local bid = app:bundleID()
    if name and bid then
      map[name:lower()] = bid
    end
  end
  return map
end

-- Run aerospace CLI asynchronously, call callback(parsed_json) when done
local function aerospace(args, callback)
  local argList = {}
  for word in args:gmatch("%S+") do
    table.insert(argList, word)
  end

  hs.task.new(AEROSPACE, function(exitCode, stdOut, stdErr)
    if exitCode ~= 0 then
      if stdErr and stdErr ~= "" then print("aerospace: " .. args .. " error: " .. stdErr) end
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

-- Fetch ALL workspace/window state (expensive: 2 + N calls)
local function fetchFullState(callback)
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

-- Collect app icons for a workspace's windows (one per window, not deduplicated)
local function getAppIcons(windows, bundleMap)
  local icons = {}
  for _, win in ipairs(windows) do
    local appName = win["app-name"] or ""
    local key = appName:lower()
    local bundleID = bundleMap[key]
    local icon = nil
    if bundleID then
      icon = hs.image.imageFromAppBundle(bundleID)
    end
    local windowId = win["window-id"] and tostring(win["window-id"]) or nil
    table.insert(icons, { image = icon, name = appName, windowId = windowId })
    if #icons >= MAX_ICONS then break end
  end
  return icons
end

-- Calculate pill width: padding + ws number + icons + padding
local function pillWidth(numIcons)
  return PILL_PAD_X + WS_TEXT_W + (numIcons * ICON_W) + PILL_PAD_X
end

-- Build an hs.canvas image of workspace pills; also returns pill layout for click detection
local function buildIcon(workspaces)
  local bundleMap = buildBundleIDMap()

  -- Filter to visible workspaces and collect their app icons
  local pills = {}
  for _, ws in ipairs(workspaces) do
    if ws.focused or #ws.windows > 0 then
      local icons = getAppIcons(ws.windows, bundleMap)
      table.insert(pills, {
        name = ws.name,
        focused = ws.focused,
        icons = icons,
        width = pillWidth(#icons),
      })
    end
  end

  if #pills == 0 then
    return nil, nil
  end

  -- Calculate total canvas width
  local totalWidth = 0
  for i, p in ipairs(pills) do
    totalWidth = totalWidth + p.width
    if i < #pills then totalWidth = totalWidth + PILL_GAP end
  end

  local canvas = hs.canvas.new({ x = 0, y = 0, w = totalWidth, h = CANVAS_H })
  local idx = 1
  local x = 0

  -- Store pill x ranges for click detection
  for _, p in ipairs(pills) do
    p.x_start = x
    p.x_end = x + p.width

    local bgColor = p.focused and COLOR_FOCUSED_BG or COLOR_UNFOCUSED_BG
    local fgColor = p.focused and COLOR_FOCUSED_FG or COLOR_UNFOCUSED_FG
    local pillY = (CANVAS_H - PILL_H) / 2

    -- Rounded rectangle background
    canvas[idx] = {
      type = "rectangle",
      frame = { x = x, y = pillY, w = p.width, h = PILL_H },
      roundedRectRadii = { xRadius = PILL_RADIUS, yRadius = PILL_RADIUS },
      fillColor = bgColor,
      strokeColor = { alpha = 0 },
      action = "fill",
    }
    idx = idx + 1

    -- Shared vertical center for both text and icons
    local contentY = pillY + (PILL_H - ICON_SIZE) / 2

    -- Workspace number (same height as icons, vertically aligned)
    local textH = ICON_SIZE  -- match icon height for alignment
    canvas[idx] = {
      type = "text",
      frame = { x = x + PILL_PAD_X, y = contentY, w = WS_TEXT_W, h = textH },
      text = hs.styledtext.new(p.name, {
        font = { name = ".AppleSystemUIFont", size = WS_FONT_SIZE },
        color = fgColor,
        paragraphStyle = { alignment = "center", lineBreakMode = "clip" },
      }),
    }
    idx = idx + 1

    -- App icon images (with click targets)
    p.iconTargets = {}
    local iconX = x + PILL_PAD_X + WS_TEXT_W
    local iconY = contentY
    for _, appIcon in ipairs(p.icons) do
      table.insert(p.iconTargets, {
        x_start = iconX,
        x_end = iconX + ICON_W,
        windowId = appIcon.windowId,
      })
      if appIcon.image then
        canvas[idx] = {
          type = "image",
          frame = { x = iconX + (ICON_W - ICON_SIZE) / 2, y = iconY, w = ICON_SIZE, h = ICON_SIZE },
          image = appIcon.image,
          imageScaling = "scaleToFit",
        }
      else
        -- Fallback: draw first letter of app name
        canvas[idx] = {
          type = "text",
          frame = { x = iconX, y = contentY, w = ICON_W, h = textH },
          text = hs.styledtext.new((appIcon.name:sub(1, 1)):upper(), {
            font = { name = ".AppleSystemUIFont", size = WS_FONT_SIZE },
            color = fgColor,
            paragraphStyle = { alignment = "center", lineBreakMode = "clip" },
          }),
        }
      end
      idx = idx + 1
      iconX = iconX + ICON_W
    end

    x = x + p.width + PILL_GAP
  end

  local image = canvas:imageFromCanvas()
  canvas:delete()
  return image, pills
end

-- Lightweight poll: only fetch focused workspace + its windows (2 calls)
-- If focused workspace changed, trigger a full refresh.
-- Otherwise, update the focused ws windows in cache and redraw.
local function pollFocused()
  if not menubar then return end

  aerospace("list-workspaces --focused --json", function(focused)
    local focusedWs = focused and focused[1] and focused[1]["workspace"] or nil
    if not focusedWs then return end

    -- Workspace changed → full refresh
    if focusedWs ~= cachedFocusedWs then
      print("aerospace: workspace changed " .. (cachedFocusedWs or "nil") .. " → " .. focusedWs .. ", full refresh")
      M.refresh()
      return
    end

    -- Same workspace — just update its windows
    aerospace("list-windows --workspace " .. focusedWs .. " --json", function(windows)
      if not windows or not cachedWorkspaces then return end

      -- Update the focused workspace's windows in cache
      for _, ws in ipairs(cachedWorkspaces) do
        if ws.name == focusedWs then
          ws.windows = windows
          break
        end
      end

      -- Redraw
      local icon, pills = buildIcon(cachedWorkspaces)
      cachedPills = pills
      if icon then
        menubar:setIcon(icon, false)
      end
      menubar:setTitle("")
    end)
  end)
end

-- Handle click on menubar: click icon → focus window, click ws number → switch workspace
local function handleClick(_modifiers)
  if not cachedPills or not menubar then return end

  local frame = menubar:frame()
  if not frame then return end

  local mousePos = hs.mouse.absolutePosition()
  local relativeX = mousePos.x - frame.x

  for _, pill in ipairs(cachedPills) do
    if relativeX >= pill.x_start and relativeX <= pill.x_end then
      -- Check if an individual icon was clicked
      if pill.iconTargets then
        for _, target in ipairs(pill.iconTargets) do
          if relativeX >= target.x_start and relativeX <= target.x_end and target.windowId then
            hs.task.new(AEROSPACE, function() M.refresh() end,
              {"focus", "--window-id", target.windowId}):start()
            return
          end
        end
      end
      -- Clicked the workspace number area → switch workspace
      hs.task.new(AEROSPACE, function() M.refresh() end, {"workspace", pill.name}):start()
      return
    end
  end
end

-- Full refresh: fetch all workspaces and their windows
function M.refresh()
  if not menubar then
    return
  end

  fetchFullState(function(workspaces, focusedWs)
    if not workspaces then
      menubar:setTitle("✈ ?")
      menubar:setIcon(nil)
      return
    end

    cachedWorkspaces = workspaces
    cachedFocusedWs = focusedWs

    local icon, pills = buildIcon(workspaces)
    cachedPills = pills
    if icon then
      menubar:setIcon(icon, false)
    end
    menubar:setTitle("")
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

  menubar:setClickCallback(handleClick)
  M.refresh()

  refreshTimer = hs.timer.doEvery(POLL_INTERVAL, pollFocused)
  print("aerospace: menubar widget started (polling every " .. POLL_INTERVAL .. "s)")
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
  cachedPills = nil
  cachedWorkspaces = nil
  cachedFocusedWs = nil
  print("aerospace: menubar widget stopped")
end

-- Expose help panel toggle
M.toggleHelp = aerospaceHelp.toggle

return M
