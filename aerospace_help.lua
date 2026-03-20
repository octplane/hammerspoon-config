-- aerospace_help.lua — Parse ~/.aerospace.toml and show a keyboard shortcut help panel
--
-- Uses the same visual style as AwesomeKeys (colored modifiers, keys, descriptions).

local M = {}

local styledtext = hs.styledtext.new
local drawing = hs.drawing

local CONFIG_PATH = os.getenv("HOME") .. "/.aerospace.toml"

-- Visual config (matches AwesomeKeys defaults from init.lua)
local style = {
  backgroundColor = { hex = "#000", alpha = 0.9 },
  textColor       = { hex = "#FFF", alpha = 0.8 },
  modsColor       = { hex = "#FA58B6" },
  keyColor        = { hex = "#f5d76b" },
  sectionColor    = { hex = "#FFF", alpha = 0.4 },
  fontFamily      = "FiraCode Nerd Font Mono",
  fontSize        = 12,
  padding         = 24,
  radius          = 12,
  strokeWidth     = 2,
  strokeColor     = { white = 1, alpha = 0.1 },
  columns         = 3,
}

-- State
local alertDrawings = {}

-- Modifier symbol mapping
local MOD_SYMBOLS = {
  cmd   = "⌘",
  ctrl  = "⌃",
  alt   = "⌥",
  shift = "⇧",
}

-- Friendly labels for aerospace commands
local COMMAND_LABELS = {
  ["focus left"]         = "Focus ←",
  ["focus right"]        = "Focus →",
  ["focus up"]           = "Focus ↑",
  ["focus down"]         = "Focus ↓",
  ["move left"]          = "Move ←",
  ["move right"]         = "Move →",
  ["move up"]            = "Move ↑",
  ["move down"]          = "Move ↓",
  ["resize smart -50"]   = "Shrink",
  ["resize smart +50"]   = "Grow",
  ["layout tiles horizontal vertical"]    = "Tile layout",
  ["layout accordion horizontal vertical"] = "Accordion layout",
  ["layout floating tiling"]               = "Float/Tile toggle",
  ["workspace-back-and-forth"]             = "Last workspace",
  ["move-workspace-to-monitor --wrap-around next"] = "Move ws → monitor",
  ["reload-config"]      = "Reload config",
  ["flatten-workspace-tree"] = "Reset layout",
  ["close-all-windows-but-current"] = "Close others",
}

-- Parse a keybinding string like "cmd-ctrl-alt-h" into { mods = {...}, key = "h" }
local function parseKeyCombo(combo)
  local parts = {}
  for part in combo:gmatch("[^-]+") do
    table.insert(parts, part)
  end

  local mods = {}
  local key = parts[#parts]
  for i = 1, #parts - 1 do
    table.insert(mods, parts[i])
  end

  return mods, key
end

-- Parse a command value (may be a string or array like ['cmd1', 'cmd2'])
local function parseCommand(value)
  -- Strip quotes
  value = value:match("^%s*(.-)%s*$")

  -- Array form: ['cmd1', 'cmd2']
  if value:match("^%[") then
    local cmds = {}
    for cmd in value:gmatch("'([^']*)'") do
      if cmd ~= "mode main" then
        table.insert(cmds, cmd)
      end
    end
    return table.concat(cmds, ", ")
  end

  -- Single quoted string
  local str = value:match("^'(.*)'$") or value:match('^"(.*)"$')
  return str or value
end

-- Friendly label for a command
local function labelForCommand(cmd)
  -- Check exact match
  if COMMAND_LABELS[cmd] then return COMMAND_LABELS[cmd] end

  -- workspace N
  local wsNum = cmd:match("^workspace (%d+)$")
  if wsNum then return "Workspace " .. wsNum end

  -- move-node-to-workspace N
  local moveWsNum = cmd:match("^move%-node%-to%-workspace (%d+)$")
  if moveWsNum then return "Move → ws " .. moveWsNum end

  -- join-with direction
  local joinDir = cmd:match("^join%-with (%w+)")
  if joinDir then return "Join " .. joinDir end

  -- mode X
  local mode = cmd:match("^mode (%w+)")
  if mode and mode ~= "main" then return "Mode: " .. mode end

  -- Fallback: use the raw command
  return cmd
end

-- Categorize bindings for display
local function categorizeBindings(bindings)
  local categories = {
    { name = "Focus",     items = {} },
    { name = "Move",      items = {} },
    { name = "Workspace", items = {} },
    { name = "Layout",    items = {} },
    { name = "Other",     items = {} },
  }

  local catMap = {
    focus        = categories[1],
    move         = categories[2],
    workspace    = categories[3],
    layout       = categories[4],
  }

  for _, b in ipairs(bindings) do
    local cmd = b.command
    local cat = "Other"
    if cmd:match("^focus ") then cat = "focus"
    elseif cmd:match("^move") then cat = "move"
    elseif cmd:match("workspace") then cat = "workspace"
    elseif cmd:match("^layout") or cmd:match("^resize") then cat = "layout"
    elseif cmd:match("^join") then cat = "move"
    elseif cmd:match("^mode ") then cat = "Other"
    end

    local target = catMap[cat] or categories[5]
    table.insert(target.items, b)
  end

  -- Filter empty categories
  local result = {}
  for _, cat in ipairs(categories) do
    if #cat.items > 0 then
      table.insert(result, cat)
    end
  end
  return result
end

-- Parse the aerospace.toml file and extract bindings per mode
local function parseConfig()
  local f = io.open(CONFIG_PATH, "r")
  if not f then return {} end
  local content = f:read("*a")
  f:close()

  local modes = {}
  local currentMode = nil

  for line in content:gmatch("[^\r\n]+") do
    -- Detect mode section headers like [mode.main.binding]
    local mode = line:match("^%[mode%.(%w+)%.binding%]")
    if mode then
      currentMode = mode
      modes[currentMode] = modes[currentMode] or {}
    elseif line:match("^%[") then
      -- Another section started
      currentMode = nil
    elseif currentMode then
      -- Parse key = value lines
      local combo, value = line:match("^%s*([%w%-]+)%s*=%s*(.+)$")
      if combo and value then
        local mods, key = parseKeyCombo(combo)
        local command = parseCommand(value)
        local label = labelForCommand(command)
        table.insert(modes[currentMode], {
          mods = mods,
          key = key,
          command = command,
          label = label,
        })
      end
    end
  end

  return modes
end

-- Build styled text for a single binding
local function styledBinding(binding)
  local textStyle = { font = { name = style.fontFamily, size = style.fontSize } }

  -- Modifier symbols
  local modStr = ""
  for _, m in ipairs(binding.mods) do
    modStr = modStr .. (MOD_SYMBOLS[m] or m)
  end

  local result = styledtext(modStr, {
    font = textStyle.font,
    color = style.modsColor,
  })

  -- Key
  result = result .. styledtext(binding.key .. " ", {
    font = textStyle.font,
    color = style.keyColor,
  })

  -- Label
  result = result .. styledtext(binding.label, {
    font = textStyle.font,
    color = style.textColor,
  })

  return result
end

-- Build the full styled text panel content
local function buildHelpText(modes)
  local textStyle = { font = { name = style.fontFamily, size = style.fontSize } }
  local spacerStyle = { font = textStyle.font, color = { hex = "#FFF", alpha = 0.4 } }

  local text = styledtext("", {})

  for modeName, bindings in pairs(modes) do
    -- Mode header
    local header = modeName == "main" and "AeroSpace" or "AeroSpace — " .. modeName .. " mode"
    text = text .. styledtext(header .. "\n", {
      font = { name = style.fontFamily, size = style.fontSize + 2 },
      color = style.keyColor,
    })

    local categories = categorizeBindings(bindings)

    for _, cat in ipairs(categories) do
      -- Category header
      text = text .. styledtext("\n" .. cat.name .. "\n", {
        font = textStyle.font,
        color = style.sectionColor,
      })

      -- Bindings in columns
      local col = 0
      for _, b in ipairs(cat.items) do
        if col > 0 then
          text = text .. styledtext("   ", spacerStyle)
        end
        text = text .. styledBinding(b)
        col = col + 1
        if col >= style.columns then
          text = text .. styledtext("\n", textStyle)
          col = 0
        end
      end
      if col > 0 then
        text = text .. styledtext("\n", textStyle)
      end
    end

    text = text .. styledtext("\n", textStyle)
  end

  return text
end

-- Show the help panel
function M.show()
  M.hide()

  local modes = parseConfig()
  if not modes or not next(modes) then
    hs.alert.show("No aerospace config found")
    return
  end

  local text = buildHelpText(modes)
  local screenFrame = hs.screen.mainScreen():fullFrame()

  -- Measure text
  local textFrame = drawing.getTextDrawingSize(text, {
    font = style.fontFamily,
    size = style.fontSize,
  })
  textFrame.w = math.ceil(textFrame.w)

  -- Drawing frame
  local drawingFrame = {
    w = textFrame.w + style.padding * 2 + style.strokeWidth,
    h = textFrame.h + style.padding * 2 + style.strokeWidth,
  }
  drawingFrame.x = screenFrame.x + (screenFrame.w - drawingFrame.w) / 2
  drawingFrame.y = screenFrame.y + screenFrame.h - drawingFrame.h - 8

  -- Background rectangle
  local bg = drawing.rectangle(drawingFrame)
    :setStroke(true)
    :setStrokeWidth(style.strokeWidth)
    :setStrokeColor(style.strokeColor)
    :setFill(true)
    :setFillColor(style.backgroundColor)
    :setRoundedRectRadii(style.radius, style.radius)
    :show()
  table.insert(alertDrawings, bg)

  -- Text
  local tf = {
    x = drawingFrame.x + (drawingFrame.w - textFrame.w) / 2,
    y = drawingFrame.y + (drawingFrame.h - textFrame.h) / 2,
    w = textFrame.w,
    h = textFrame.h,
  }
  local textDrawing = drawing.text(tf, text)
    :orderAbove(bg)
    :show()
  table.insert(alertDrawings, textDrawing)
end

-- Hide the help panel
function M.hide()
  for _, d in ipairs(alertDrawings) do
    d:hide()
  end
  alertDrawings = {}
end

-- Toggle the help panel
function M.toggle()
  if #alertDrawings > 0 then
    M.hide()
  else
    M.show()
  end
end

return M
