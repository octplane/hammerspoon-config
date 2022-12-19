-- Enable this to do live debugging in ZeroBrane Studio
-- local ZBS = "/Applications/ZeroBraneStudio.app/Contents/ZeroBraneStudio"
-- package.path = package.path .. ";" .. ZBS .. "/lualibs/?/?.lua;" .. ZBS .. "/lualibs/?.lua"
-- package.cpath = package.cpath .. ";" .. ZBS .. "/bin/?.dylib;" .. ZBS .. "/bin/clibs53/?.dylib"
-- require("mobdebug").start()



function ReloadHammerSpoon()
  hs.console.clearConsole()
  hs.openConsole(true)
  print("Reloading configuration...")
  hs.reload()
end

HYPER = { "cmd", "alt", "control", "shift" }


hs.loadSpoon("AwesomeKeys")
local keys = spoon.AwesomeKeys
-- hbb = keys:createHyperBindings(
--   {
--     mods = HYPER,
--     hyperKey = "pageup",
--     backgroundColor = { hex = "#000", alpha = 0.9 },
--     textColor = { hex = "#FFF", alpha = 0.8 },
--     modsColor = { hex = "#FA58B6" },
--     keyColor = { hex = "#f5d76b" },
--     fontFamily = "JetBrainsMono Nerd Font Mono",
--     separator = "(✌ ﾟ ∀ ﾟ)☞ –––",
--     position = { x = "center", y = "bottom" }
--   }
-- )


require("bretzel_conf")

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

function toggleInputVolume()
  local currentInput = hs.audiodevice.defaultInputDevice()
  local v = currentInput:inputVolume()
  if v < 50 then
    currentInput:setInputVolume(66)
  else
    currentInput:setInputVolume(0)
  end
end

-- Plays an array of keystroke events.
local function playKb(kbd)
  for _, v in pairs(kbd) do
    print(v)
    print(#v)
    if #v == 2 then
      hs.eventtap.keyStroke(v[1], v[2], 10000)
    elseif #v == 1 then
      hs.eventtap.keyStrokes(v[1])
    end
  end
end

--  https://github.com/asmagill/hammerspoon_asm
local hasSpaces, spaces = pcall(require, "hs.spaces")

function ZoomZoom()
  if hs.window.focusedWindow() then
    local win    = hs.window.frontmostWindow()
    local id     = win:id()
    local screen = win:screen()
    local grid   = hs.grid.getGrid(screen)

    local w = math.floor(grid.w / 3)
    local h = math.floor(grid.h / 3)
    local x = math.floor(grid.w / 2 - grid.w / 6)

    local cell = x .. ",0 " .. w .. "x" .. h
    print(cell)


    hs.grid.set(win, cell, screen)
  end
end

-- Bring focus to the specified app, maybe launch it.
-- Maybe bring up an alternate and focus or launch it.
function toggleApp(appinfo)
  print("Looking for " .. appinfo.name)
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
        playKb(appinfo.kbd)
      end
    end
    return
  end
  -- App is running, let's focus it.
  local mainwin = app:mainWindow()
  if hasSpaces then
    if appinfo.moveToCurrentSpace then
      spaces.moveWindowToSpace(mainwin, spaces.focusedSpace())
    end
  else
    print("unable to move window to current space: no Spaces extension available")
  end
  if mainwin then
    if mainwin ~= hs.window.focusedWindow() then
      mainwin:application():activate(true)
      mainwin:application():unhide()
      mainwin:focus()
    else
      mainwin:application():hide()
    end
  else
    app:activate()
  end
end

---@diagnostic disable-next-line: unused-local
function applicationWatcher(appName, eventType, appObject)
  if (eventType == hs.application.watcher.activated) then
    if streamDeck then
      icon = hs.image.imageFromAppBundle(appObject:bundleID())
      print(appObject:bundleID())
      streamDeck:setButtonImage(6, icon)
    end
  end
end

AppWatcher = hs.application.watcher.new(applicationWatcher)
AppWatcher:start()

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

function VolumeDown()
  if hs.spotify.isPlaying() then
    hs.spotify.volumeDown()
  else
    changeVolume(-3)
  end
end

function VolumeUp()
  if hs.spotify.isPlaying() then
    hs.spotify.volumeUp()
  else
    changeVolume(3)
  end
end

function PlayPause()
  hs.eventtap.event.newSystemKeyEvent("PLAY", true):post()
end

-- hbb:setGlobalBindings(
--   {
--     key = "r",
--     mods = HYPER,
--     label = "Reload Hammerspoon",
--     fn = ReloadHammerSpoon
--   },
--   {
--     key = "[",
--     mods = { "shift" },
--     label = "Volume Down",
--     fn = VolumeDown
--   },
--   {
--     key = "]",
--     mods = { "shift" },
--     label = "Volume Up",
--     fn = VolumeUp
--   }
-- )

local bindingConf = {
  {
    app = "Zoom",
    splitEvery = 8,
    keys = {
      {
        key = "c",
        label = "Center",
        fn = ZoomZoom
      },
      { key = "z", label = "Mute", fn = function() hs.eventtap.keyStroke(HYPER, "z") end }
    }
  },
  {
    app = "Slack",
    keys = {
      {
        mods = { "option" },
        key = "1",
        label = "👀",
        fn = keys.fnutils.paste("👀")
      },
      {
        mods = { "option" },
        key = "2",
        label = "😂",
        fn = keys.fnutils.paste("😂")
      },
      {
        mods = { "option" },
        key = "3",
        label = "❤️",
        fn = keys.fnutils.paste("❤️")
      }
    }
  },
  {
    app = "Firefox",
    keys = {
      {
        mods = { "command" },
        key = "p",
        label = "pulls",
        fn = keys.fnutils.openURL("https://github.com/pulls/assigned")
      },
      {
        mods = { "command" },
        key = "i",
        label = "issues",
        fn = keys.fnutils.openURL("https://github.com/issues/assigned")
      }
    }
  },
  {
    app = "Sublime Text",
    keys = {
      {
        key = "m",
        label = "🗃️",
        fn = function()
          hs.eventtap.keyStroke({ "cmd", "alt" }, "m")
        end
      },
      {
        key = ".",
        label = "👨‍💻",
        fn = function()
          hs.eventtap.keyStroke({ "cmd", "alt" }, ".")
        end
      },
    }
  }
}

-- hbb:setAppBindings(bindingConf)

function ConsoleCommand()
  hs.toggleConsole()
end

--- Bind keys
hs.hotkey.bind(HYPER, "return", "Toggle Audio Output", toggleAudioOutput)
hs.hotkey.bind(
  HYPER,
  "c",
  "Toggle Console",
  ConsoleCommand
)

hs.hotkey.bind(
  HYPER,
  "v",
  "Edit Configuration",
  function()
    hs.execute("subl ~/.hammerspoon", true)
  end
)

hs.hotkey.bind(
  HYPER,
  "a",
  "Slack",
  function()
    toggleApp({ name = "Slack", launch = true, kbd = nil, rect = nil })
  end
)

hs.hotkey.bind(
  HYPER,
  "s",
  "Spotify",
  function()
    toggleApp({ name = "Spotify", launch = true, kbd = nil, rect = nil })
  end
)

hs.hotkey.bind(
  HYPER,
  "q",
  "Telegram",
  function()
    toggleApp({ name = "Telegram", launch = true, kbd = nil, rect = nil })
  end
)

hs.hotkey.bind(
  HYPER,
  "o",
  "Obsidian",
  function()
    toggleApp({ name = "Obsidian", launch = true, kbd = nil, rect = nil })
  end
)

hs.hotkey.bind(
  HYPER,
  "'",
  "To Markdown Link",
  function()
    playKb({ { "cmd", "l" }, { "cmd", "c" } })
    playKb({ { "cmd", "l" }, { "cmd", "c" } })

    local title = hs.window.focusedWindow():title()
    local url = hs.pasteboard.readString()
    if string.find(url, "http") == 1 then
      hs.pasteboard.writeObjects("[" .. title .. "](" .. url .. ")")
    end
    hs.timer.doAfter(1, function()
      hs.eventtap.keyStroke({}, "ESCAPE")
    end)
  end
)


-- Unsplash
-- local status, secret = pcall(require, "secret")
-- if(status) then
--   hs.loadSpoon("Unsplash")
--   spoon.Unsplash.logger.setLogLevel("debug")
--   spoon.Unsplash:start(secret.UNSPLASH_CLIENT_ID, "/Users/pierrebaillet/.hammerspoon/wallpaper")
-- else
--   print("UNSPLASH secret is missing, not starting...")
-- end

-- -- MiroWindowsManager
hs.loadSpoon("MiroWindowsManager")
hs.window.animationDuration = 0
spoon.MiroWindowsManager:bindHotkeys(
  {
    up = { HYPER, "up" },
    down = { HYPER, "down" },
    right = { HYPER, "right" },
    left = { HYPER, "left" },
    fullscreen = { HYPER, "f" },
  }
)


-- extra feature for the WM
hs.hotkey.bind(HYPER, "pagedown", "Center Window",
  function()
    hs.window.focusedWindow():centerOnScreen(nil, true)
  end)

-- Emojis
hs.loadSpoon("Emojis")
spoon.Emojis:bindHotkeys(
  {
    toggle = { HYPER, "e" }
  }
)

--
-- hs.loadSpoon("URLDispatcher")

-- u = spoon.URLDispatcher
-- u.logger.setLogLevel("debug")
-- u.url_patterns = {
--   -- { "https?://github.com", "org.mozilla.firefox" }
--   -- ,{ "https://www.youtube.com", "com.apple.Safari"}
--   -- ,{ "https://youtube.com", "com.apple.Safari"}
--   -- { "https?://trello.com","com.fluidapp.FluidApp2.Trello" }
--   -- ,{ "https://datadoghq.atlassian.net", "com.brave.Browser"}
-- }
-- u.default_handler = "org.mozilla.firefox"
-- u:start()

hs.loadSpoon("AfterDark"):start({ showMenu = true })

streamdeck = require("streamdeck")
streamdeck:observe(bindingConf)

function locked()
  streamdeck:sleep()
end

function unlocked()
  streamdeck:awake()
end

watcher = require("lock_watcher")
watcher:start(locked, unlocked)

-- This lets you click on the menu bar item to toggle the mute state
zoomStatusMenuBarItem = hs.menubar.new(nil)
zoomStatusMenuBarItem:setClickCallback(function()
  spoon.Zoom:toggleMute()
end)

updateZoomStatus = function(event)
  hs.printf("updateZoomStatus(%s)", event)
  if (event == "from-running-to-meeting") then
    zoomStatusMenuBarItem:returnToMenuBar()
  elseif (event == "muted") then
    zoomStatusMenuBarItem:setTitle("🔴")
  elseif (event == "unmuted") then
    zoomStatusMenuBarItem:setTitle("🟢")
  elseif (event == "from-meeting-to-running") or (event == "from-running-to-closed") then
    zoomStatusMenuBarItem:setTitle("no-zoom")
  end
end

hs.loadSpoon("Zoom")
updateZoomStatus("from-running-to-closed")
spoon.Zoom:setStatusCallback(updateZoomStatus)
spoon.Zoom:start()

print("Reload Completed")
if not has_failed then
  hs.closeConsole()
end

show_notification("Configuration", "Successfully Loaded!")
hs.dockicon.hide()
