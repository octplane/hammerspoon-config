
local Grid = require 'grid'
local Hazel = require 'hazel'

local fnutils = require "hs.fnutils"

Hazel.boot()

-- Window Manipulation

-- Bind alt-Tab to show next window of current application

hs.hotkey.bind({"alt"}, "Tab", function()
	local win = hs.window.focusedWindow()
	local app = win:application()
	local windows = app:allWindows()

	windows[#windows]:focus()
end)


local mash = {"cmd", "alt", "ctrl"}
local mashshift = {"cmd", "alt", "ctrl", "shift"}


--
-- replace caffeine
--
local caffeine = hs.menubar.new()
function setCaffeineDisplay(state)
    local result
    if state then
        result = caffeine:setIcon("caffeine-on.pdf")
    else
        result = caffeine:setIcon("caffeine-off.pdf")
    end
end

function caffeineClicked()
    setCaffeineDisplay(hs.caffeinate.toggle("displayIdle"))
end

if caffeine then
    caffeine:setClickCallback(caffeineClicked)
    setCaffeineDisplay(hs.caffeinate.get("displayIdle"))
end

hs.hotkey.bind(mash, "/", function() caffeineClicked() end)
--
-- /replace caffeine
--

-- Window management
hs.hotkey.bind(mash, 'K', Grid.fullscreen)
hs.hotkey.bind(mash, 'H', Grid.lefthalf)
hs.hotkey.bind(mash, 'L', Grid.righthalf)

hs.hotkey.bind({"cmd", "alt", "ctrl"}, "R", function()
  hs.reload()
end)

-- Finally, show a notification that we finished loading the config successfully
hs.notify.show("Hammerspoon", "", "Config loaded!", "")
