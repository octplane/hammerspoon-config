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

p("https://dd.slack.com", "slack", ",", 16, 16, 800, 640)
p("https://mail.google.com", "gmail", ".", 16, 640, 800, 1200)


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

-- Window management
hs.hotkey.bind(mash, 'K', Grid.fullscreen)
hs.hotkey.bind(mash, 'H', Grid.lefthalf)
hs.hotkey.bind(mash, 'L', Grid.righthalf)


-- Finally, show a notification that we finished loading the config successfully
hs.notify.show("Hammerspoon", "", "Config loaded!", "")

