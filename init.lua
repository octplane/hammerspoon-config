hs.loadSpoon('FadeLogo'):start()
hs.console.clearConsole()

local mash = {"cmd", "alt", "ctrl"}
local mashshift = {"cmd", "alt", "ctrl", "shift"}

hs.hotkey.bind(mashshift, "R", function()
  hs.reload()
end)

hs.hotkey.bind(mash, "/", function()
  hs.toggleConsole()
end)

local Grid = require 'grid'
local Bretzel = require 'bretzel'
local fnutils = require "hs.fnutils"

local p = require "popup"

-- p("https://dd.slack.com", "slack", ",", 16, 16, 800, 640)


local tagsAndAge = { Orange = 86400 * 4, Rouge = 86400 * 8 }
local archiveAge = 86400 * 12
Bretzel.boot(os.getenv("HOME") .. "/Desktop", tagsAndAge, archiveAge, false)

Bretzel.boot(os.getenv("HOME") .. "/Downloads",
{
  Vert = 86400 * 4,
  Orange = 86400 * 7,
},
86400 * 10,
true
)

-- Window Manipulation

-- Bind alt-Tab to show next window of current application

-- hs.hotkey.bind({"alt"}, "Tab", function()
-- 	local win = hs.window.focusedWindow()
-- 	local app = win:application()
-- 	local windows = app:allWindows()

-- 	print("We have " .. #windows .. " windows.")
-- 	if #windows == 1 then
-- 		return
-- 	end

-- 	local focusable = 12

-- 	for pos,lwin in pairs(windows) do
-- 		if focusable == nil then
-- 			print("Focussing on window #" .. pos)
-- 			focusable = lwin
-- 		end
-- 		if lwin == win then
-- 			print("This window is #" .. pos)
-- 			focusable = nil
-- 		end
-- 	end
-- 	if focusable == 12 then
-- 		print("We never found our window :(")
-- 		focusable = windows[#windows]
-- 	end

-- 	focusable:focus()
-- end)




-- --
-- -- replace caffeine
-- --
-- local caffeine = hs.menubar.new()
-- function setCaffeineDisplay(state)
--     local result
--     if state then
--         result = caffeine:setIcon("caffeine-on.pdf")
--     else
--         result = caffeine:setIcon("caffeine-off.pdf")
--     end
-- end
--
-- function caffeineClicked()
--     setCaffeineDisplay(hs.caffeinate.toggle("displayIdle"))
-- end
--
-- if caffeine then
--     caffeine:setClickCallback(caffeineClicked)
--     setCaffeineDisplay(hs.caffeinate.get("displayIdle"))
-- end
--
-- hs.hotkey.bind(mash, "/", function() caffeineClicked() end)
-- --
-- -- /replace caffeine
-- --

hs.hotkey.bind(mash, 'E', function()
  ok,result = hs.applescript('tell application "Finder" to eject (every disk whose ejectable is true)')
  hs.notify.show("Hammerspoon", "", "Ejected all disks", "")

end)

wm_bindings={}

function unbind()
  for h,hotkey in pairs(wm_bindings) do
    hotkey:disable():delete()
  end
  wm_bindings = {}
end

function show_temporary_notification(subtitle, infoText)
  local notification = hs.notify.new(nil, 
  { title="Hammerspoon",
    subTitle=subtitle,
    informativeText=infoText,
    autoWithdraw=true,
    hasActionButton=false})
  notification:send()

  local w = function()
    notification:withdraw()
  end
  hs.timer.delayed.new(5, w):start()

end

function show_keyboard_notif(keyboard)
  show_temporary_notification("Keyboard", "Switched to " .. keyboard)
end

-- Window management
function bind_for_qwerty(show_notification)
  unbind()
  if show_notification then
    show_keyboard_notif("qwerty")
  end

  wm_bindings = {
    hs.hotkey.bind(mash, 'U', Grid.topleft),
    hs.hotkey.bind(mash, 'I', Grid.topright),
    hs.hotkey.bind(mash, 'K', Grid.fullscreen),
    hs.hotkey.bind(mash, 'H', Grid.leftchunk),
    hs.hotkey.bind(mash, 'L', Grid.rightchunk),
    hs.hotkey.bind(mash, 'M', Grid.bottomleft),
    hs.hotkey.bind(mash, ',', Grid.bottomright)
  }
end

function bind_for_dvorak(show_notification)
  unbind()
  if show_notification then
    show_keyboard_notif("dvorak")
  end

  wm_bindings = {
    hs.hotkey.bind(mash, 'F', Grid.topleft),
    hs.hotkey.bind(mash, 'C', Grid.topright),
    hs.hotkey.bind(mash, 'H', Grid.fullscreen),
    hs.hotkey.bind(mash, 'D', Grid.leftchunk),
    hs.hotkey.bind(mash, 'T', Grid.rightchunk),
    hs.hotkey.bind(mash, 'B', Grid.bottomleft),
    hs.hotkey.bind(mash, 'W', Grid.bottomright)
  }
end

function usb_enumerate()
  local usbs = hs.usb.attachedDevices()
  for k,v in pairs(usbs) do
    print(k .. " " .. v)    
  end
end


local usbs = hs.usb.attachedDevices()


usb_watch = function (item)
  print "An USB change was detected."
  local u = hs.usb.attachedDevices()
  if #u>5  then
    bind_for_dvorak(true)
  else
    bind_for_qwerty(true)
  end
end

w = hs.usb.watcher.new(usb_watch)
w:start()



if #usbs>5 then
  bind_for_dvorak(false)
else
  bind_for_qwerty(false)
end

hs.loadSpoon('SpeedMenu')

-- Finally, show a notification that we finished loading the config successfully
show_temporary_notification("Configuration", "Successfully loaded!")