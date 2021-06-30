-- Enable this to do live debugging in ZeroBrane Studio
-- local ZBS = "/Applications/ZeroBraneStudio.app/Contents/ZeroBraneStudio"
-- package.path = package.path .. ";" .. ZBS .. "/lualibs/?/?.lua;" .. ZBS .. "/lualibs/?.lua"
-- package.cpath = package.cpath .. ";" .. ZBS .. "/bin/?.dylib;" .. ZBS .. "/bin/clibs53/?.dylib"
-- require("mobdebug").start()
hyper = {"⌘", "⌥", "⌃", "⇧"}

function reloadCommand()
  hs.console.clearConsole()
  hs.openConsole(true)
  print("Reloading configuration...")
  hs.reload()
end

-- Reload Hotkey
hs.hotkey.bind(
  hyper,
  "r",
  "Reload Hammerspoon",
  reloadCommand
)

-- hs.logger.defaultLogLevel = "info"

-- MultiCountryMenubarClock
-- hs.loadSpoon("MultiCountryMenubarClock")
-- spoon.MultiCountryMenubarClock:start()

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
    if #v == 2 then
      hs.eventtap.keyStroke(v[1], v[2], 10000)
    elseif #v == 1 then
      hs.eventtap.keyStrokes(v[1])
    end
  end
end


--  https://github.com/asmagill/hammerspoon_asm
local hasSpaces, spaces = pcall(require, "hs.spaces")


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
      mainwin:frontmostWindow():unminimize()
      mainwin:focus()
    else
      mainwin:application():hide()
    end
  end

end

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


function consoleCommand()
  hs.toggleConsole()
end

--- Bind keys
hs.hotkey.bind(hyper, "return", "Toggle Audio Output", toggleAudioOutput)
hs.hotkey.bind(
  hyper,
  "c",
  "Toggle Console",
  consoleCommand
)

hs.hotkey.bind(
  hyper,
  "v",
  "Edit Configuration",
  function()
    hs.execute("subl ~/.hammerspoon", true)
  end
)

hs.hotkey.bind(
  hyper,
  "a",
  nil,
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
    toggleApp({name = "Drafts", launch = true, kbd = nil, rect = nil, moveToCurrentSpace= true})
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
  "Coaster",
  function()
    toggleApp({name = "Coaster", launch = true, kbd = nil, rect = nil, moveToCurrentSpace= true})
  end
)

function toggleZoomMuteCommand()
    hs.osascript.applescript([[
if application "zoom.us" is running then
tell application "System Events" to tell process "zoom.us"
    if menu item "Unmute Audio" of menu 1 of menu bar item "Meeting" of menu bar 1 exists then
     click menu item "Unmute Audio" of menu 1 of menu bar item "Meeting" of menu bar 1
    else
     if menu item "Mute Audio" of menu 1 of menu bar item "Meeting" of menu bar 1 exists then
       click menu item "Mute Audio" of menu 1 of menu bar item "Meeting" of menu bar 1
     end if
    end if
end tell
end if
]]
)
  end

hs.hotkey.bind(
  hyper,
  "z",
  nil,
  toggleZoomMuteCommand
)


local c = require("hs.canvas")
function iconSized(text, size)
  local a = c.new {x = 0, y = 0, w = 80, h = 80}

  local delta = (80 - size) / 2

  a[1] = {
    frame = {h = size, w = size, x = delta, y = delta},
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

function iconForDeck(text)
  return iconSized(text, 76)
end

function clickedIconForDeck(text)
  return iconSized(text, 60)
end


function streamButton(icons, command, autoAdvanceIcon)
  local b = {}
  b.icons = icons
  b.current = 1
  b.command = command
  b.autoAdvanceIcon = autoAdvanceIcon

  function b:icon()
    return self.icons[self.current]
  end

  function b:clickedIcon()
    if self.clickedIcons then 
      return self.clickedIcons[self.current]
    else
      return self:icon()
    end
  end

  function b:withAutoAdvanceIcon()
    self.autoAdvanceIcon = true
    return self
  end

  function b:withClickedIcons(i)
    self.clickedIcons = i
    return self
  end

  function b:pressed ()
    if self.command then
      self.command(self)
      if self.autoAdvanceIcon then
        self.current = self.current + 1
        if self.current > #self.icons then
          self.current = 1
        end
      end
    end
  end
  return b
end


function isOn(what)
  output, status, t, rc = hs.execute("~pierre.baillet/bin/hue_get_all_groups FBXd8sQkm7c4fop3MxmEt1bqlZsT-PhT1nQCgZJu")
  local on = false
  if rc == 0 then
    for line in output:gmatch("([^\n]*)\n?") do
      if string.find(line, what) and string.find(line, " on ") then
        on = true
      end
    end
  else
    print("Failed calling hue controlling command:")
    print(output)
    print(status)
    print(t)
    print(rc)
  end

  return on
end

function lightsCommand(self)
  local on = isOn("Ordi")
  if on then       
    output, status, t, rc = hs.execute("~pierre.baillet/bin/hue_set_group_state FBXd8sQkm7c4fop3MxmEt1bqlZsT-PhT1nQCgZJu 5 off")
    self.current = 1
  else
    output, status, t, rc = hs.execute("~pierre.baillet/bin/hue_set_scene FBXd8sQkm7c4fop3MxmEt1bqlZsT-PhT1nQCgZJu OOhyOyaSQp2S77d")
    self.current = 2
  end
end

local lightButton = streamButton({"🛋️", "💡"}, lightsCommand)
local centerButton = streamButton({"🅲", "🅒"}, function ()
    hs.window.focusedWindow():centerOnScreen(nil, true)
  end):
  withAutoAdvanceIcon():
  withClickedIcons({"ⓒ", "🄲"})

if not isOn("Ordi") then
  lightButton.current = 2
end
 
local deckConf =  {
  lightButton,
  centerButton, 
  streamButton({"♻️"}, reloadCommand),
  streamButton({"📜"}, consoleCommand),
  streamButton({"🔇"}, toggleZoomMuteCommand)
}


hs.streamdeck.init(function(connected, device)
  print("received streamdeck plugin event ".. device:serialNumber())
  device:reset()
  for a = 1,6 do
    if #deckConf < a then
      print("we don't have info for button ".. a)

    else
      local dc = deckConf[a]
      device:setButtonImage(a, iconForDeck(dc:icon()))
    end
  end

  device:buttonCallback(
    function (userData, button, buttonPressed)
      dc = deckConf[button]
      if buttonPressed then
        device:setButtonImage(button, clickedIconForDeck(dc:clickedIcon()))
        dc:pressed()
      else
        device:setButtonImage(button, iconForDeck(dc:icon()))
      end
    end)
end)

-- Unsplash
local status, secret = pcall(require, "secret")
if(status) then
  hs.loadSpoon("Unsplash")
  spoon.Unsplash.logger.setLogLevel("debug")
  spoon.Unsplash:start(secret.UNSPLASH_CLIENT_ID, "/Users/pierrebaillet/.hammerspoon/wallpaper")
else
  print("UNSPLASH secret is missing, not starting...")
end

-- MiroWindowsManager
hs.loadSpoon("MiroWindowsManager")
spoon.MiroWindowsManager:bindHotkeys(
  {
    up = {hyper, "up"},
    down = {hyper, "down"},
    right = {hyper, "right"},
    left = {hyper, "left"},
    fullscreen = {hyper, "f"},
  }
)

-- extra feature for the WM
hs.hotkey.bind(hyper, "pagedown", "Center Window",
  function ()
    hs.window.focusedWindow():centerOnScreen(nil, true)
  end)

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
u.logger.setLogLevel("debug")
u.url_patterns = {
  -- { "https?://github.com", "org.mozilla.firefox" }
  -- ,{ "https://www.youtube.com", "com.apple.Safari"}
  -- ,{ "https://youtube.com", "com.apple.Safari"}
  -- { "https?://trello.com","com.fluidapp.FluidApp2.Trello" }
  -- ,{ "https://datadoghq.atlassian.net", "com.brave.Browser"}
}
u.default_handler = "org.mozilla.firefox"
u:start()

hs.loadSpoon("AfterDark"):start({showMenu = true})


hs.hotkey.showHotkeys(hyper, "h")

print("Reload Completed")
hs.closeConsole()

show_notification("Configuration", "Successfully Loaded!")
hs.dockicon.hide()
