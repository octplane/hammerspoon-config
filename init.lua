-- Enable this to do live debugging in ZeroBrane Studio
-- local ZBS = "/Applications/ZeroBraneStudio.app/Contents/ZeroBraneStudio"
-- package.path = package.path .. ";" .. ZBS .. "/lualibs/?/?.lua;" .. ZBS .. "/lualibs/?.lua"
-- package.cpath = package.cpath .. ";" .. ZBS .. "/bin/?.dylib;" .. ZBS .. "/bin/clibs53/?.dylib"
-- require("mobdebug").start()

local fennel = require "fennel"
print("Loaded fennel")
local f = io.open("init.fnl", "rb")
local mycode_new =
  fennel.eval(
  f:read("*all"),
  {
    filename = "init.fnl"
  }
)
f:close()

local toggleAudioOutput = require("audio_output_toggle")
local hueBridge = require("hue_bridge")

hyper = {"⌘", "⌥", "⌃", "⇧"}
hs.hotkey.bind(hyper, "s", toggleAudioOutput)

-- hueBridge:init()
-- hueBridge:start()
-- curl http://192.168.1.38/api/tE9SjzBRdFpFQXt5tfwRkxJfjbXpa2cG9M2hR2T3/lights | jq "to_entries[] | {k:.key,n:.value.name}"

-- Plays an array of keystroke events.
local function playKb(kbd)
  for _, v in pairs(kbd) do
    if #v == 2 then
      hs.eventtap.keyStroke(v[1], v[2], 10000)
    elseif #v == 1 then
      hs.eventtap.keyStrokes(v[1])
    end
  end
end

-- Bring focus to the specified app, maybe launch it.
-- Maybe bring up an alternate and focus or launch it.
local function toggleApp(appinfo)
  local app = hs.appfinder.appFromName(appinfo.name)
  if not app then
    -- App isn't running.
    if appinfo.launch then
      if (appinfo.name == "iTerm2") then
        -- naming is weird here.
        hs.application.launchOrFocus("/Applications/iTerm.app")
      else
        hs.application.launchOrFocus(appinfo.name)
      end
      if appinfo.rect ~= nil or appinfo.kbd ~= nil then
        -- allow time app to start
        hs.timer.usleep(2000000)
      end
      if appinfo.rect ~= nil then
        local win = hs.window.focusedWindow()
        if win ~= nil then
          win:setFrame(appinfo.rect)
        end
      end
      if appinfo.kbd ~= nil then
      end
      playKb(appinfo.kbd)
    end
    return
  end
  -- App is running, let's focus it.
  local mainwin = app:mainWindow()
  if mainwin then
    if mainwin ~= hs.window.focusedWindow() then
      mainwin:application():activate(true)
      mainwin:application():unhide()
      mainwin:frontmostWindow():unminimize()
      mainwin:focus()
    end
  end
end

local foo = 1
local ix = 1

function open_in_shell(what)
  local function act()
    local shell_command = 'open "' .. what .. '"'
    hs.execute(shell_command)
  end
  return act
end

local c = require("hs.canvas")
function iconSized(text, size)
  local a = c.new {x = 0, y = 0, w = 80, h = 80}

  a[1] = {
    frame = {h = 80, w = 80, x = 0, y = 0},
    text = hs.styledtext.new(
      text,
      {
        font = {name = ".AppleSystemUIFont", size = size},
        color = hs.drawing.color.colorsFor("Apple")["White"],
        paragraphStyle = {alignment = "center"}
      }
    ),
    type = "text"
  }
  return a:imageFromCanvas()
end

function icon(text)
  return iconSized(text, 70)
end

function clicked(text)
  return iconSized(text, 50)
end

function n(txt, content)
  local n = {}
  n.text = txt
  n.content = content
  n.action = nil
  return n
end

function action(txt, action)
  local n = {}
  n.text = txt
  n.content = nil
  n.action = action
  return n
end

deckConf =
  n(
  "root",
  {
    n(
      "🥃",
      {
        n("1", {}),
        n("2", {}),
        n("3", {}),
        n("4", {})
      }
    ),
    n(
      "🏡",
      {
        n("5", {}),
        n("6", {}),
        n("7", {}),
        n("8", {})
      }
    ),
    action("🍖", open_in_shell("zoommtg://zoom.us/join?action=join&confno=207603154")),
    action(
      "Z",
      function()
        toggleApp({name = "zoom.us.app", launch = true})
      end
    ),
    n("", {}),
    n("", {})
  }
)

local custom_actions = {
  zoom = {bundleId = "us.zoom.xos"},
  slack = {bundleId = "com.tinyspeck.slackmacgap"}
}

function locate(tree, ix)
  if #position < ix then
    return tree
  end
  local lk = position[ix]
  content = tree.content
  for tx = 1, #content do
    k = content[tx]
    if k.text == lk then
      return locate(k, ix + 1)
    end
  end
end

position = deckConf

function deckClicked(deck, i, pressed)
  local treeNode = position.content
  if pressed then
    deck:setButtonImage(i, clicked(treeNode[i].text))
  else
    deck:setButtonImage(i, icon(treeNode[i].text))
    if treeNode[i].action then
      treeNode[i].action()
    end
  end
end

function drawDeck(deck)
  local treeNode = position.content
  for i = 1, 6 do
    deck:setButtonImage(i, icon(treeNode[i].text))
  end
end

local streamDeck

function cb(connected, deck)
  deck:reset()
  deck:buttonCallback(deckClicked)
  drawDeck(deck)
  streamDeck = deck
end
hs.streamdeck.init(cb)

hs.hotkey.bind(
  hyper,
  "a",
  function()
    toggleApp({name = "Slack", launch = true, kbd = nil, rect = nil})
  end
)

function applicationWatcher(appName, eventType, appObject)
  if (eventType == hs.application.watcher.activated) then
    if streamDeck then
      icon = hs.image.imageFromAppBundle(appObject:bundleID())
      print(appObject:bundleID())
      streamDeck:setButtonImage(6, icon)
    end
  end
end

appWatcher = hs.application.watcher.new(applicationWatcher)
appWatcher:start()

-- Unsplash
local secret = require("secret")
local usplash = hs.loadSpoon("Unsplash")
usplash:start(secret.UNSPLASH_CLIENT_ID, "/Users/pierrebaillet/.hammerspoon/wallpaper")
