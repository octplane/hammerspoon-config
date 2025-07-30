local c = require("hs.canvas")

local streamdeck = {}

-- Normal streamdeck is 5*3 at 72px each, 360*216
streamdeck.buttonSize = 72
streamdeck.columns = 5
streamdeck.rows = 3
streamdeck.width = streamdeck.columns * streamdeck.buttonSize
streamdeck.height = streamdeck.rows * streamdeck.buttonSize
streamdeck.sleeping = false
streamdeck.images = {}
streamdeck.callbacks = {}

local a = c.new({ x = 0, y = 0, w = 72, h = 72 })
BLANK = a:imageFromCanvas()

local deck

function streamdeck:init()
	self:iterate(function(s, x, y, p)
		s.images[p] = BLANK
		s.callbacks[p] = function() end
	end)
end

function streamdeck:redraw() end

function streamdeck:iterate(cb)
	for y = 0, self.rows - 1 do
		for x = 0, self.columns - 1 do
			local position = x + y * streamdeck.columns + 1
			cb(self, x, y, position)
		end
	end
end

function streamdeck:sleep()
	self.sleeping = true
	UpdateDeck()
end

function streamdeck:awake()
	print("Waking up")
	self.sleeping = false
	UpdateDeck()
end

function streamdeck:showImage()
	local file = "/Users/pbaillet/Downloads/Archive/Pictures/dvACrXUExLs.jpg"
	local img = hs.image.imageFromPath(file)
	local d = streamdeck.buttonSize
	img = img:setSize({ w = self.width, h = self.height })

	local crops = {}
	for y = 0, streamdeck.rows - 1 do
		for x = 0, streamdeck.columns - 1 do
			crops[#crops + 1] = BLANK
		end
	end
	for y = 1, #crops do
		deck:setButtonImage(y, crops[y])
	end
end

function streamdeck:observe(bindings)
	hs.window.filter.new():subscribe({ hs.window.filter.windowFocused }, function(window)
		local currentApp = window:application()
		local bundleID = currentApp:bundleID()
		local ix = 11
		-- Change button at position ix to show the current App icon
		if deck == nil then
			return
		end
		deck:setButtonImage(ix, hs.image.imageFromAppBundle(bundleID))
		local name = currentApp:name()
		for i = 1, #bindings do
			local conf = bindings[i]
			if conf["app"] == name then
				local keys = conf["keys"]
				if keys ~= nil then
					for k = 1, #keys do
						local key = keys[k]
						local label = key["label"]
						ix = ix + 1
						deck:setButtonImage(ix, iconSized(label, 68))
						self.callbacks = key["fn"]
					end
				end
			end
		end
	end)
end

function streamdeck:blank() end

function iconSized(text, size)
	local a = c.new({ x = 0, y = 0, w = streamdeck.buttonSize, h = streamdeck.buttonSize })

	local delta = (streamdeck.buttonSize - size) / 2

	a[1] = {
		frame = { h = streamdeck.buttonSize, w = streamdeck.buttonSize, x = 0, y = 0 },
		text = hs.styledtext.new(text, {
			font = { name = ".AppleSystemUIFont", size = size },
			color = hs.drawing.color.colorsFor("Apple")["White"],
			paragraphStyle = { alignment = "center" },
		}),
		type = "text",
	}
	return a:imageFromCanvas()
end

function emojiStreamButton(icons, command, autoAdvanceIcon)
	local b = {}
	b.icons = icons
	b.current = 1
	b.command = command
	b.autoAdvanceIcon = autoAdvanceIcon

	function b:icon()
		return iconSized(self.icons[self.current], 68)
	end

	function b:clickedIcon()
		if self.clickedIcons then
			return iconSized(self.clickedIcons[self.current], 50)
		else
			return iconSized(self.icons[self.current], 50)
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

	function b:pressed()
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

local has_failed = false
function fail(msg)
	print(msg)
	hs.openConsole(true)
	has_failed = true
end

local status, secret = pcall(require, "secret")
local HUE_TOKEN = "FIXME"
if status then
	HUE_TOKEN = secret.HUE_TOKEN
else
	fail("Missing secret")
end

function hue_w(command, parameters)
	output, status, t, rc = hs.execute("~/bin/" .. command .. " " .. HUE_TOKEN .. " " .. parameters)
	if rc == 0 then
		return true, output
	else
		fail("Failed calling hue controlling command:")
		print(output)
		print(status)
		print(t)
		print(rc)
	end
	return false, ""
end

function isOn(what)
	ok, output = hue_w("hue_get_all_groups", "")
	if ok then
		for line in output:gmatch("([^\n]*)\n?") do
			if string.find(line, what) and string.find(line, " on ") then
				on = true
			end
		end
	end
	return on
end

function isLightOn(what)
	output, status, t, rc = hs.execute("~/bin/hue_get_all_lights " .. HUE_TOKEN)
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

function deskLights(self)
	local on = isOn("Ordi")
	if on then
		hs.execute("~/bin/hue_set_group_state FBXd8sQkm7c4fop3MxmEt1bqlZsT-PhT1nQCgZJu 5 off")
		self.current = 1
	else
		hs.execute("~/bin/hue_set_scene FBXd8sQkm7c4fop3MxmEt1bqlZsT-PhT1nQCgZJu OOhyOyaSQp2S77d")
		self.current = 2
	end
end

function Lava(self)
	local on = isLightOn("Lava lamp")

	if on then
		hs.execute("~/bin/hue_set_light_state FBXd8sQkm7c4fop3MxmEt1bqlZsT-PhT1nQCgZJu 18 off")
		self.current = 1
	else
		hs.execute("~/bin/hue_set_light_state FBXd8sQkm7c4fop3MxmEt1bqlZsT-PhT1nQCgZJu 18 on")
		self.current = 2
	end
end

local lightButton = emojiStreamButton({ "🕶️", "💡" }, deskLights)
local lavaButton = emojiStreamButton({ "🔥", "🔦" }, Lava)
local centerButton = emojiStreamButton({ "📐", "📏" }, function()
		hs.window.focusedWindow():centerOnScreen(nil, true)
	end)
	:withAutoAdvanceIcon()
	:withClickedIcons({ "ⓒ", "🄲" })
local consoleButton = emojiStreamButton({ "📝" }, ConsoleCommand)

function ToggleZoomMuteCommand()
	hs.eventtap.keyStroke(HYPER, "z")
end

local zoomButton = emojiStreamButton({ "🔇", "🗣️", "😴" }, ToggleZoomMuteCommand)

function getZoomMuteState()
	ret, obj, output = hs.osascript._osascript(
		[[
if application "zoom.us" is running then
  tell application "System Events" to tell process "zoom.us"
      if menu item "Unmute Audio" of menu 1 of menu bar item "Meeting" of menu bar 1 exists then
        set returnValue to "MUTED"
      else
       if menu item "Mute Audio" of menu 1 of menu bar item "Meeting" of menu bar 1 exists then
        set returnValue to "LIVE"
       end if
      end if
  end tell
else
  set returnValue to ""
end if
    ]],
		"applescript"
	)
	return obj
end

function UpdateZoomButton()
	local state = getZoomMuteState()
	if state == nil then
		zoomButton.current = 3
		return
	end
	if state == "MUTED" then
		zoomButton.current = 1
	else
		zoomButton.current = 2
	end
end

zoomTimer = hs.timer.doEvery(1, UpdateZoomButton)
UpdateZoomButton()

local function HomeManagerConf()
	hs.execute("/Applications/Sublime\\ Text.app/Contents/SharedSupport/bin/subl ~/.config/home-manager/", true)
end

local function EditConfiguration()
	hs.execute("/Applications/Sublime\\ Text.app/Contents/SharedSupport/bin/subl ~/.hammerspoon", true)
end

local deckConf = {
	centerButton,
	consoleButton,
	zoomButton,
	emojiStreamButton({ "♻️" }, ReloadHammerSpoon),
	emojiStreamButton({ "⬆️" }, VolumeUp),
	emojiStreamButton({ "⏯️" }, PlayPause),
	emojiStreamButton({ "⬇️" }, VolumeDown),
	emojiStreamButton({ "🔨" }, EditConfiguration),
	emojiStreamButton({ "🏠" }, HomeManagerConf),
}

local activeDeckConf = deckConf
function UpdateDeck()
	if deck == nil then
		return
	end
	activeDeckConf = deckConf

	if streamdeck.sleeping then
		streamdeck:showImage()
		activeDeckConf = {}
	end

	deck:buttonCallback(function(userData, button, buttonPressed)
		if button <= #activeDeckConf then
			dc = activeDeckConf[button]
			if buttonPressed then
				deck:setButtonImage(button, dc:clickedIcon())
				dc:pressed()
			else
				deck:setButtonImage(button, dc:icon())
			end
		end
	end)

	if streamdeck.sleeping then
		return
	end

	for a = 1, 15 do
		if #activeDeckConf >= a then
			local dc = activeDeckConf[a]
			deck:setButtonImage(a, dc:icon())
		else
			deck:setButtonColor(a, hs.drawing.color.definedCollections.hammerspoon["black"])
		end
	end
end

-- deckUpdate = hs.timer.doEvery(1, update_deck)

hs.streamdeck.init(function(connected, device)
	print("Setting up streamdeck configuration for " .. device:serialNumber())
	deck = device
	deck:reset()
	UpdateDeck()
end)

return streamdeck
