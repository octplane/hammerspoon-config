-- Enable this to do live debugging in ZeroBrane Studio
-- local ZBS = "/Applications/ZeroBraneStudio.app/Contents/ZeroBraneStudio"
-- package.path = package.path .. ";" .. ZBS .. "/lualibs/?/?.lua;" .. ZBS .. "/lualibs/?.lua"
-- package.cpath = package.cpath .. ";" .. ZBS .. "/bin/?.dylib;" .. ZBS .. "/bin/clibs53/?.dylib"
-- require("mobdebug").start()
hyper = {"⌘", "⌥", "⌃", "⇧"}

-- Reload Hotkey
hs.hotkey.bind(
  hyper,
  "r",
  "Reload Hammerspoon",
  function()
    hs.console.clearConsole()
    hs.openConsole(true)
    print("Reloading configuration...")
    hs.reload()
  end
)

-- hs.logger.defaultLogLevel = "info"

-- MultiCountryMenubarClock
hs.loadSpoon("MultiCountryMenubarClock")
spoon.MultiCountryMenubarClock:start()

hs.loadSpoon("Bretzel")

local bretzelConfig = {
  Desktop = {
    archiveAge = (86400 * 12),
    sortRoot = false,
    tagsAndAge = {
      Orange = (86400 * 4),
      Rouge = (86400 * 8)
    },
    path = os.getenv("HOME") .. "/Desktop"
  },
  Downloads = {
    archiveAge = (86400 * 10),
    sortRoot = true,
    tagsAndAge = {
      Vert = 86400,
      Orange = 86400
    },
    path = os.getenv("HOME") .. "/Downloads"
  }
}

for _, conf in pairs(bretzelConfig) do
  spoon.Bretzel:boot(conf["path"], conf["tagsAndAge"], conf["archiveAge"], conf["sortRoot"])
end

function show_notification(subtitle, infotext)
  local notification =
    hs.notify.new(
    nil,
    {
      title = "Hammerspoon",
      subtitle = subtitle,
      informativeText = infotext,
      autoWithdraw = true,
      hasActionButton = false
    }
  )
  notification:send()
  hs.timer.delayed.new(
    5,
    function()
      notification:withdraw()
    end
  )
end

local toggleAudioOutput = require("audio_output_toggle")
local hueBridge = require("hue_bridge")

function toggleInputVolume()
  local currentInput = hs.audiodevice.defaultInputDevice()
  local v = currentInput:inputVolume()
  if v < 50 then 
    currentInput:setInputVolume(66)
  else
    currentInput:setInputVolume(0)
  end
end

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
    else
      mainwin:application():hide()
    end
  end
end

-- StreamDeck

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
  configureHotKeys()
end
-- hs.streamdeck.init(cb)

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

function changeVolume(diff)
  return function()
    local current = hs.audiodevice.defaultOutputDevice():volume()
    local new = math.min(100, math.max(0, math.floor(current + diff)))
    if new > 0 then
      hs.audiodevice.defaultOutputDevice():setMuted(false)
    end
    hs.alert.closeAll(0.0)
    hs.alert.show("Volume " .. new .. "%", {}, 0.5)
    hs.audiodevice.defaultOutputDevice():setVolume(new)
  end
end

hs.hotkey.bind(hyper, "[", nil, function()

  if hs.spotify.isPlaying() then
    hs.spotify.volumeDown()
  else
    changeVolume(-3)
  end
end)

hs.hotkey.bind(hyper, "]", nil, function()

  if hs.spotify.isPlaying() then
    hs.spotify.volumeUp()
  else
    changeVolume(3)
  end
end)



--- Bind keys
hs.hotkey.bind(hyper, "return", "Toggle Audio Output", toggleAudioOutput)
hs.hotkey.bind(
  hyper,
  "c",
  "Toggle Console",
  function()
    hs.toggleConsole()
  end
)

hs.hotkey.bind(
  hyper,
  "a",
  "Slack",
  function()
    toggleApp({name = "Slack", launch = true, kbd = nil, rect = nil})
  end
)

hs.hotkey.bind(
  hyper,
  "s",
  "Spotify",
  function()
    toggleApp({name = "Spotify", launch = true, kbd = nil, rect = nil})
  end
)

hs.hotkey.bind(
  hyper,
  "d",
  "Drafts",
  function()
    toggleApp({name = "Drafts", launch = true, kbd = nil, rect = nil})
  end
)
hs.hotkey.bind(
  hyper,
  "q",
  "Telegram",
  function()
    toggleApp({name = "Telegram", launch = true, kbd = nil, rect = nil})
  end
)

hs.hotkey.bind(
  hyper,
  "w",
  "Keybase",
  function()
    toggleApp({name = "Keybase", launch = true, kbd = nil, rect = nil})
  end
)

hs.hotkey.bind(
  hyper,
  "m",
  "Marta",
  function()
    toggleApp({name = "Marta", launch = true, kbd = nil, rect = nil})
  end
)


ix = 1

function bindAndDock(name, key, bundleId)
  hs.hotkey.bind(hyper, key, name, 
  function()
    toggleApp({name = name, launch = true, kbd = nil, rect = nil})
  end
  )
  icon = hs.image.imageFromAppBundle(bundleId)
  streamDeck:setButtonImage(ix, icon)

  ix = ix + 1
  if ix == 6 then
    -- stop adding icons
  end
end

function configureHotKeys()
  bindAndDock("Trello", "z", "com.fluidapp.FluidApp2.Trello")
end
  


-- Unsplash
local secret = require("secret")
hs.loadSpoon("Unsplash")
spoon.Unsplash:start(secret.UNSPLASH_CLIENT_ID, "/Users/pierrebaillet/.hammerspoon/wallpaper")

-- MiroWindowsManager
hs.loadSpoon("MiroWindowsManager")
spoon.MiroWindowsManager:bindHotkeys(
  {
    up = {hyper, "up"},
    down = {hyper, "down"},
    right = {hyper, "right"},
    left = {hyper, "left"},
    fullscreen = {hyper, "f"}
  }
)
-- Emojis
hs.loadSpoon("Emojis")
spoon.Emojis:bindHotkeys(
  {
    toggle = {hyper, "e"}
  }
)

--
hs.loadSpoon("URLDispatcher")

u = spoon.URLDispatcher
u.logger.log_level = "debug"
u.url_patterns = {
  -- { "https?://trello.com","com.fluidapp.FluidApp2.Trello" }
  { "https?://github.com", "org.mozilla.firefox" }
  ,{ "https://www.youtube.com", "com.apple.Safari"}
  ,{ "https://youtube.com", "com.apple.Safari"}
  ,{ "https://datadoghq.atlassian.net", "com.brave.Browser"}
}
u.default_handler = "org.mozilla.firefox"
u:start()

-- 
-- kubernetes helper for stream deck
--k_watcher = hs.pathwatcher.new("/Users/pierrebaillet/.kube/config", function(path, flags)
--end)

--k_watched:start()
--
--
--
hs.loadSpoon("AfterDark"):start({showMenu = true})


hs.hotkey.showHotkeys(hyper, "h")

print("Reload Completed")
hs.closeConsole()

show_notification("Configuration", "Successfully Loaded!")
hs.dockicon.hide()
