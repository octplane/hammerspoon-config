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

-- Current mode: "aerospace" or "utils"
local currentMode = "aerospace"

-- Cached aerospace state for workspace button highlighting
local aeroFocusedWs = nil

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

-- ── Icon rendering helpers ──────────────────────────────────────────

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

-- Render a button with colored background, label text, and optional sublabel
local function renderButton(label, sublabel, bgColor, fgColor)
	local sz = streamdeck.buttonSize
	local canvas = c.new({ x = 0, y = 0, w = sz, h = sz })
	local idx = 1

	-- Background
	canvas[idx] = {
		type = "rectangle",
		frame = { x = 2, y = 2, w = sz - 4, h = sz - 4 },
		roundedRectRadii = { xRadius = 8, yRadius = 8 },
		fillColor = bgColor,
		action = "fill",
	}
	idx = idx + 1

	-- Main label
	local labelSize = sublabel and 32 or 40
	local labelY = sublabel and 4 or 8
	canvas[idx] = {
		type = "text",
		frame = { x = 0, y = labelY, w = sz, h = sz * 0.6 },
		text = hs.styledtext.new(label, {
			font = { name = ".AppleSystemUIFont", size = labelSize },
			color = fgColor,
			paragraphStyle = { alignment = "center" },
		}),
	}
	idx = idx + 1

	-- Sublabel (small text at bottom)
	if sublabel then
		canvas[idx] = {
			type = "text",
			frame = { x = 0, y = sz - 22, w = sz, h = 20 },
			text = hs.styledtext.new(sublabel, {
				font = { name = ".AppleSystemUIFont", size = 10 },
				color = fgColor,
				paragraphStyle = { alignment = "center" },
			}),
		}
		idx = idx + 1
	end

	local img = canvas:imageFromCanvas()
	canvas:delete()
	return img
end

-- ── Standard emojiStreamButton (unchanged) ──────────────────────────

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

-- ── AeroSpace button factory ────────────────────────────────────────

-- PR #2206 build; must match the running app's socket protocol version.
-- Revert: "/Users/pierrebaillet/.nix-profile/bin/aerospace"
local AEROSPACE = "/Users/pierrebaillet/ghq/github.com/nikitabobko/AeroSpace/result/bin/aerospace"

-- Run an aerospace command, then refresh the deck to reflect new state
local function aeroExec(args)
	hs.task.new(AEROSPACE, function()
		-- Small delay to let aerospace settle, then refresh workspace state
		hs.timer.doAfter(0.15, function() refreshAeroState() end)
	end, args):start()
end

-- Fetch focused workspace and update button highlights.
-- Timed out because a CLI whose socket protocol version doesn't match the
-- running app blocks forever, and this runs on a 2s poll (see aeroPoller).
local AERO_CALL_TIMEOUT = 5 -- seconds

function refreshAeroState()
	local task, timeout
	task = hs.task.new(AEROSPACE, function(exitCode, stdOut)
		if timeout then timeout:stop() end
		if exitCode ~= 0 then return end
		local ok, result = pcall(hs.json.decode, stdOut)
		if ok and result and result[1] then
			local newWs = result[1]["workspace"]
			if newWs ~= aeroFocusedWs then
				aeroFocusedWs = newWs
				if currentMode == "aerospace" then
					UpdateDeck()
				end
			end
		end
	end, { "list-workspaces", "--focused", "--json" })

	timeout = hs.timer.doAfter(AERO_CALL_TIMEOUT, function()
		if task:isRunning() then
			print("aerospace: list-workspaces timed out after " .. AERO_CALL_TIMEOUT .. "s, terminating")
			task:terminate()
		end
	end)
	task:start()
end

-- An aerospace button: shows label+sublabel, runs aerospace command on press
local function aeroButton(label, sublabel, args, bgColor)
	local b = {}
	b.label = label
	b.sublabel = sublabel
	b.args = args
	b.bgColor = bgColor or { red = 0.15, green = 0.15, blue = 0.15, alpha = 1.0 }
	b.fgColor = { red = 1.0, green = 1.0, blue = 1.0, alpha = 1.0 }

	function b:icon()
		return renderButton(self.label, self.sublabel, self.bgColor, self.fgColor)
	end

	function b:clickedIcon()
		local pressed = { red = 0.3, green = 0.5, blue = 1.0, alpha = 1.0 }
		return renderButton(self.label, self.sublabel, pressed, self.fgColor)
	end

	function b:pressed()
		aeroExec(self.args)
	end

	return b
end

-- Workspace button: dynamically highlights when it's the focused workspace
local function wsButton(wsName)
	local b = {}
	b.wsName = wsName

	local focusedBg = { red = 0.2, green = 0.5, blue = 1.0, alpha = 1.0 }
	local normalBg = { red = 0.2, green = 0.2, blue = 0.2, alpha = 1.0 }
	local fg = { red = 1.0, green = 1.0, blue = 1.0, alpha = 1.0 }

	function b:icon()
		local bg = (aeroFocusedWs == self.wsName) and focusedBg or normalBg
		return renderButton(self.wsName, nil, bg, fg)
	end

	function b:clickedIcon()
		return renderButton(self.wsName, nil, focusedBg, fg)
	end

	function b:pressed()
		aeroExec({ "workspace", self.wsName })
	end

	return b
end

-- Layout cycle button: steps through layout modes one at a time
local function layoutButton(layouts)
	local b = {}
	b.layouts = layouts
	b.current = 1
	b.bgColor = { red = 0.4, green = 0.2, blue = 0.5, alpha = 1.0 }
	b.fgColor = { red = 1.0, green = 1.0, blue = 1.0, alpha = 1.0 }

	function b:icon()
		local entry = self.layouts[self.current]
		return renderButton(entry.label, entry.name, self.bgColor, self.fgColor)
	end

	function b:clickedIcon()
		local pressed = { red = 0.6, green = 0.3, blue = 0.8, alpha = 1.0 }
		local entry = self.layouts[self.current]
		return renderButton(entry.label, entry.name, pressed, self.fgColor)
	end

	function b:pressed()
		local entry = self.layouts[self.current]
		aeroExec({ "layout", entry.name })
		self.current = self.current + 1
		if self.current > #self.layouts then
			self.current = 1
		end
	end

	return b
end

-- ── Mode toggle button ──────────────────────────────────────────────

local function modeToggleButton()
	local b = {}

	local aeroBg = { red = 0.1, green = 0.3, blue = 0.1, alpha = 1.0 }
	local utilsBg = { red = 0.3, green = 0.1, blue = 0.1, alpha = 1.0 }
	local fg = { red = 1.0, green = 1.0, blue = 1.0, alpha = 1.0 }

	function b:icon()
		if currentMode == "aerospace" then
			return renderButton("🔧", "utils", utilsBg, fg)
		else
			return renderButton("✈", "aero", aeroBg, fg)
		end
	end

	function b:clickedIcon()
		return self:icon()
	end

	function b:pressed()
		if currentMode == "aerospace" then
			currentMode = "utils"
		else
			currentMode = "aerospace"
		end
		UpdateDeck()
	end

	return b
end

-- ── Hue / utility buttons (preserved from original) ─────────────────

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
	local handle = io.popen(os.getenv("HOME") .. "/bin/" .. command .. " " .. HUE_TOKEN .. " " .. parameters)
	output = handle:read("*a")
	local ok, t, rc = handle:close()
	if ok then
		return true, output
	else
		fail("Failed calling hue controlling command:")
		print(output)
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

local function HomeManagerConf()
	hs.execute("/Applications/Sublime\\ Text.app/Contents/SharedSupport/bin/subl ~/.config/home-manager/", true)
end

local function EditConfiguration()
	hs.execute("/Applications/Sublime\\ Text.app/Contents/SharedSupport/bin/subl ~/.hammerspoon", true)
end

-- ── Deck configurations ─────────────────────────────────────────────

local modeToggle = modeToggleButton()

-- AeroSpace mode layout (5x3):
--  Row 1: WS1  WS2  WS3  WS4  WS5
--  Row 2: ←    ↓    ↑    →    layout
--  Row 3: J←   J↓   J↑   J→   [mode]
local navColor = { red = 0.1, green = 0.25, blue = 0.4, alpha = 1.0 }
local joinColor = { red = 0.4, green = 0.15, blue = 0.1, alpha = 1.0 }

local aerospaceConf = {
	-- Row 1: workspace switching
	wsButton("1"),
	wsButton("2"),
	wsButton("3"),
	wsButton("4"),
	wsButton("5"),
	-- Row 2: focus navigation + layout toggle
	aeroButton("←", "focus", { "focus", "left" }, navColor),
	aeroButton("↓", "focus", { "focus", "down" }, navColor),
	aeroButton("↑", "focus", { "focus", "up" }, navColor),
	aeroButton("→", "focus", { "focus", "right" }, navColor),
	aeroButton("⊞", "layout", { "layout", "tiles", "accordion" }, { red = 0.4, green = 0.2, blue = 0.5, alpha = 1.0 }),
	-- Row 3: join with + mode toggle
	aeroButton("⇐", "join", { "join-with", "left" }, joinColor),
	aeroButton("⇓", "join", { "join-with", "down" }, joinColor),
	aeroButton("⇑", "join", { "join-with", "up" }, joinColor),
	aeroButton("⇒", "join", { "join-with", "right" }, joinColor),
	modeToggle,
}

-- Utilities mode layout (original buttons + mode toggle at position 15)
local utilsConf = {
	centerButton,
	consoleButton,
	emojiStreamButton({ "♻️" }, ReloadHammerSpoon),
	emojiStreamButton({ "⬆️" }, VolumeUp),
	emojiStreamButton({ "⏯️" }, PlayPause),
	emojiStreamButton({ "⬇️" }, VolumeDown),
	emojiStreamButton({ "🔨" }, EditConfiguration),
	emojiStreamButton({ "🏠" }, HomeManagerConf),
	lightButton,
	lavaButton,
	nil, nil, nil, nil, -- empty slots 11-14
	modeToggle,
}

-- ── Deck update logic ───────────────────────────────────────────────

local activeDeckConf = aerospaceConf

function UpdateDeck()
	if deck == nil then
		return
	end

	if currentMode == "aerospace" then
		activeDeckConf = aerospaceConf
	else
		activeDeckConf = utilsConf
	end

	if streamdeck.sleeping then
		streamdeck:showImage()
		activeDeckConf = {}
	end

	deck:buttonCallback(function(userData, button, buttonPressed)
		if button <= #activeDeckConf and activeDeckConf[button] ~= nil then
			local dc = activeDeckConf[button]
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
		if a <= #activeDeckConf and activeDeckConf[a] ~= nil then
			local dc = activeDeckConf[a]
			deck:setButtonImage(a, dc:icon())
		else
			deck:setButtonColor(a, hs.drawing.color.definedCollections.hammerspoon["black"])
		end
	end
end

-- Poll aerospace state to keep workspace highlights in sync
local aeroPoller = hs.timer.doEvery(2, function()
	if currentMode == "aerospace" then
		refreshAeroState()
	end
end)

hs.streamdeck.init(function(connected, device)
	print("Setting up streamdeck configuration for " .. device:serialNumber())
	deck = device
	deck:reset()
	refreshAeroState()
	UpdateDeck()
end)

return streamdeck
