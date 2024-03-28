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
HyperBindings = keys:createHyperBindings({
	hyperKey = "f20",
	backgroundColor = { hex = "#000", alpha = 0.9 },
	textColor = { hex = "#FFF", alpha = 0.8 },
	fontSize = 12,
	modsColor = { hex = "#FA58B6" },
	keyColor = { hex = "#f5d76b" },
	fontFamily = "JetBrainsMono Nerd Font Mono",
	separator = "---",
	position = { x = "center", y = "bottom" },
})

require("bretzel_conf")

function ShowNotification(subtitle, infotext)
	local notification = hs.notify.new(nil, {
		title = "Hammerspoon",
		subtitle = subtitle,
		informativeText = infotext,
		autoWithdraw = true,
		hasActionButton = false,
	})
	notification:send()
	hs.timer.delayed.new(5, function()
		notification:withdraw()
	end)
end

local ToggleAudioOutput = require("audio_output_toggle")

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
		local win = hs.window.frontmostWindow()
		local id = win:id()
		local screen = win:screen()
		local grid = hs.grid.getGrid(screen)

		local w = math.floor(grid.w / 3)
		local h = math.floor(grid.h / 3)

		local cell = 0 .. ",0 " .. w .. "x" .. h

		hs.grid.set(win, cell, screen)
	end
end

function CenterMiddle()
	if hs.window.focusedWindow() then
		local win = hs.window.frontmostWindow()
		local id = win:id()
		local screen = win:screen()
		local grid = hs.grid.getGrid(screen)

		local w = math.floor(grid.w / 4)

		local cell = w .. ",0 " .. 2 * w .. "x" .. grid.h

		hs.grid.set(win, cell, screen)
	end
end

function ToggleAppCallback(appinfo)
	return function()
		toggleApp(appinfo)
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
			if appinfo.name == "iTerm2" then
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
	if appinfo.url ~= nil then
		hs.urlevent.openURL(appinfo.url)
		return
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
	if eventType == hs.application.watcher.activated then
		if not streamdeck == nil then
			icon = hs.image.imageFromAppBundle(appObject:bundleID())
			streamdeck:setButtonImage(6, icon)
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

function ConsoleCommand()
	hs.toggleConsole()
end

function EditConfiguration()
	hs.execute("subl ~/.hammerspoon", true)
end

function GB(key, label, fn)
	return { key = key, mods = HYPER, label = label, fn = fn }
end

HyperBindings:setGlobalBindings(
	GB("r", "Reload Hammerspoon", ReloadHammerSpoon),
	GB("]", "Volume Up", VolumeUp),
	GB("[", "Volume Down", VolumeDown),
	GB("c", "Center Middle", CenterMiddle),
	GB("return", "Toggle Audio Output", ToggleAudioOutput),
	GB("p", "Toggle Console", ConsoleCommand),
	GB("v", "Edit Configuration", EditConfiguration),
	GB("a", "Slack", ToggleAppCallback({ name = "Slack", launch = true, kbd = nil, rect = nil })),
	GB("s", "Spotify", ToggleAppCallback({ name = "Spotify", launch = true, kbd = nil, rect = nil })),
	GB("q", "Telegram", ToggleAppCallback({ name = "Telegram", launch = true, kbd = nil, rect = nil })),
	GB("o", "Obsidian", ToggleAppCallback({ name = "Obsidian", launch = true, kbd = nil, rect = nil }))
)

local bindingConf = {
	{
		app = "Zoom",
		keys = {
			{ key = "c", label = "Below Camera", fn = ZoomZoom },
			{
				key = "z",
				label = "Mute",
				fn = function()
					hs.eventtap.keyStroke(HYPER, "z")
				end,
			},
		},
	},
	{
		app = "Slack",
		keys = {
			{ mods = { "option" }, key = "1", label = "👀", fn = keys.fnutils.paste("+👀") },
			{ mods = { "option" }, key = "2", label = "😂", fn = keys.fnutils.paste("+😂") },
			{ mods = { "option" }, key = "3", label = "❤️", fn = keys.fnutils.paste("+❤️") },
		},
	},
	{
		app = "Firefox",
		keys = {
			{
				key = "p",
				label = "pulls",
				fn = keys.fnutils.openURL("https://github.com/pulls/assigned"),
			},
			{
				key = "i",
				label = "issues",
				fn = keys.fnutils.openURL("https://github.com/issues/assigned"),
			},
		},
	},
	{
		app = "Sublime Text",
		keys = {
			{
				key = "m",
				label = "🗃️",
				fn = function()
					hs.eventtap.keyStroke({ "cmd", "alt" }, "m")
				end,
			},
			{
				key = ".",
				label = "👨‍💻",
				fn = function()
					hs.eventtap.keyStroke({ "cmd", "alt" }, ".")
				end,
			},
		},
	},
}

HyperBindings:setAppBindings(bindingConf)
--- Bind keys

-- hs.hotkey.bind(HYPER, "t", "Todo", function()
-- 	toggleApp({
-- 		name = "Drafts",
-- 		url = "drafts://x-callback-url/open?uuid=9D659E1D-A20B-4B66-861C-FDCCDEA994E4",
-- 		launch = true,
-- 		kbd = nil,
-- 		rect = nil,
-- 	})
-- end)
--
-- hs.hotkey.bind(HYPER, "9", "Open Stream Deck", function()
-- 	local ret = hs.osascript.applescript([[
-- tell application "System Events" to tell process "Stream Deck"
--     tell menu bar item 1 of menu bar 1
--         click menu item "Configure Stream Deck" of menu 1
--     end tell
-- end tell]])
-- 	print(ret)
-- end)
--
-- Unsplash
-- local status, secret = pcall(require, "secret")
-- if(status) then
--   hs.loadSpoon("Unsplash")
--   spoon.Unsplash.logger.setLogLevel("debug")
--   spoon.Unsplash:start(secret.UNSPLASH_CLIENT_ID, "/Users/pierrebaillet/.hammerspoon/wallpaper")
-- else
--   print("UNSPLASH secret is missing, not starting...")
-- end
--

us = hs.loadSpoon("UnsplashZ")
us.init()

-- -- MiroWindowsManager
hs.loadSpoon("MiroWindowsManager")
hs.window.animationDuration = 0
spoon.MiroWindowsManager:bindHotkeys({
	up = { HYPER, "up" },
	down = { HYPER, "down" },
	right = { HYPER, "right" },
	left = { HYPER, "left" },
	fullscreen = { HYPER, "f" },
})

-- extra feature for the WM
hs.hotkey.bind(HYPER, "pagedown", "Center Window", function()
	CenterMiddle()
end)

AsciimojiCompletion = function(chosen)
	if chosen then
		hs.eventtap.keyStrokes(chosen["subText"])
	end
end

AsciimojiChooser = hs.chooser.new(AsciimojiCompletion)
AsciimojiChooser:choices(require("asciimoji"))

hs.hotkey.bind(HYPER, "x", "Asciimoji", function()
	AsciimojiChooser:show()
end)

-- Emojis
hs.loadSpoon("Emojis")
spoon.Emojis:bindHotkeys({
	toggle = { HYPER, "e" },
})

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

-- streamdeck = nil
-- streamdeck = require("streamdeck")
-- streamdeck:observe(bindingConf)
--
-- function locked()
-- 	streamdeck:sleep()
-- end
--
-- function unlocked()
-- 	streamdeck:awake()
-- end
--
-- watcher = require("lock_watcher")
-- watcher:start(locked, unlocked)
--
-- This lets you click on the menu bar item to toggle the mute state
zoomStatusMenuBarItem = hs.menubar.new(true)
zoomStatusMenuBarItem:setClickCallback(function()
	spoon.Zoom:toggleMute()
end)

updateZoomStatus = function(event)
	hs.printf("updateZoomStatus(%s)", event)
	if event == "from-running-to-meeting" then
		zoomStatusMenuBarItem:returnToMenuBar()
	elseif event == "muted" then
		zoomStatusMenuBarItem:setTitle("🔴")
	elseif event == "unmuted" then
		zoomStatusMenuBarItem:setTitle("🟢")
	elseif (event == "from-meeting-to-running") or (event == "from-running-to-closed") then
		zoomStatusMenuBarItem:setTitle("no-zoom")
	end
end

hs.loadSpoon("Zoom")
updateZoomStatus("from-running-to-closed")
spoon.Zoom:setStatusCallback(updateZoomStatus)
spoon.Zoom:start()

local hotswitchHs = require("hotswitch-hs/hotswitch-hs")
-- hotswitchHs.enableAutoUpdate() -- If you don't want to update automatically, remove this line.
hotswitchHs.setPanelToAlwaysShowOnPrimaryScreen()
hotswitchHs.enableAllSpaceWindows()
hs.hotkey.bind({ "command" }, ".", hotswitchHs.openOrClose) -- Set a keybind you like to open HotSwitch-HS panel.

function invertScreen()
	hs.screen.setInvertedPolarity(true)
end

function normalScreen()
	hs.screen.setInvertedPolarity(false)
end

function nagScreen()
	-- start nagging
	local toggled = false
	local timer = hs.timer.doEvery(1, function()
		if toggled then
			normalScreen()
		else
			invertScreen()
		end
		toggled = not toggled
	end)

	local wf = hs.window.filter
	termWindow = wf.new("Terminal")
	termWindow:subscribe(wf.windowFocused, function()
		termWindow:unsubscribeAll()
		timer:stop()
		-- restore regardless of previous state.
		normalScreen()
	end)
end

print("Reload Completed")

ShowNotification("Configuration", "Successfully Loaded!")
hs.dockicon.hide()
