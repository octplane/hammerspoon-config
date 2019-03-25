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

hueBridge:init()
-- hueBridge:start()
-- curl http://192.168.1.38/api/tE9SjzBRdFpFQXt5tfwRkxJfjbXpa2cG9M2hR2T3/lights | jq "to_entries[] | {k:.key,n:.value.name}"

-- Plays an array of keystroke events.
local function playKb(kbd)
  for _,v in pairs(kbd) do
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

hs.hotkey.bind(hyper, 'a', function() toggleApp({name="Slack", launch=true, kbd=nil, rect=nil}) end)
