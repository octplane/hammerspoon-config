-- Single-keystroke panel over Firefox tabs, in the spirit of hotswitch-hs but
-- driven by firefox_tabs' cross-profile index instead of hs.window.
--
-- Rows are bounded on purpose: named targets above the line (stable letters, so
-- muscle memory holds), most-recently-used tabs below. The full tab list stays
-- searchable through firefox_tabs.chooser() — a letter-per-row panel cannot
-- address 70+ tabs, so it deliberately does not try.

local firefoxTabs = require("firefox_tabs")

local M = {}

local SETTING_KEY = "firefox-tab-panel-bindings"
local RECENT_ROWS = 12

-- Letters offered to recent rows, in reach order. Target keys are removed from
-- this pool at build time so a target and a recent never collide.
local RECENT_KEY_POOL = { "a", "s", "d", "f", "h", "j", "k", "l", "w", "e", "r", "u", "i", "o", "p", "n", "v", "z" }

-- Accepted as the second keystroke of a rebind.
local ASSIGNABLE_KEYS = {}
for _, key in ipairs({
	"a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m",
	"n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z",
	"1", "2", "3", "4", "5", "6", "7", "8", "9", "0",
}) do
	ASSIGNABLE_KEYS[key] = true
end

-- Matches the AwesomeKeys hyper panel in init.lua.
local FONT = "FiraCode Nerd Font Mono"
local FONT_SIZE = 13
local COLOR_BG = { hex = "#000", alpha = 0.9 }
local COLOR_KEY = { hex = "#f5d76b", alpha = 1 }
local COLOR_TEXT = { hex = "#FFF", alpha = 0.8 }
local COLOR_RULE = { hex = "#FFF", alpha = 0.25 }
local COLOR_BOUND = { hex = "#FA58B6", alpha = 1 }
local COLOR_HINT = { hex = "#FFF", alpha = 0.55 }
local COLOR_SELECTED = { hex = "#FA58B6", alpha = 0.28 }
local COLOR_SELECTED_KEY = { hex = "#FFF", alpha = 1 }
local PROFILE_COLORS = {
	Perso = { hex = "#FA58B6", alpha = 1 },
	Work = { hex = "#7DD3C0", alpha = 1 },
}
local COLOR_PROFILE_FALLBACK = { hex = "#AADDDD", alpha = 1 }

local PANEL_W = 760
local ROW_H = 26
local PADDING = 12
local KEY_X = PADDING + 10
local KEY_W = 26
local BADGE_X = KEY_X + KEY_W
local BADGE_W = 62
local TITLE_X = BADGE_X + BADGE_W

M.canvas = nil
M.tap = nil
M.watcher = nil
M.isOpen = false
M.rows = {}

-- Set while waiting for the second keystroke of a rebind. Holds the row whose
-- tab is about to get a new letter.
M.pendingRebind = nil

-- Letters bound interactively, persisted across reloads:
--   { { key = "d", page = "https://…/4439146680/…", title = "…", profile = "Work" } }
-- `page` is a query-stripped url, so a binding survives tab reordering, title
-- changes and the tracking params Confluence/Jira append on re-open.
function M.bindings()
	return hs.settings.get(SETTING_KEY) or {}
end

function M.setBindings(bindings)
	hs.settings.set(SETTING_KEY, bindings)
end

function M.clearBindings()
	hs.settings.clear(SETTING_KEY)
end

-- Rows are scarce, so two tabs of the same page must not eat two letters. Query
-- and fragment are dropped: Confluence and Jira re-open pages with ?atlOrigin=
-- tracking params, which exact-url comparison treats as distinct pages.
local function pageKey(url)
	return (url or ""):gsub("[?#].*$", "")
end

-- Build the row list: targets first, then the most recent tabs that aren't
-- already covered by a target. Each row carries the tab to focus, or just a url
-- for a target with nothing open. Exposed so it can be inspected from the
-- Hammerspoon console: hs.inspect(require("firefox_tab_panel").buildRows(...)).
function M.buildRows(tabs)
	local rows = {}
	local claimedKeys = {}
	local seenUrls = {}

	-- Interactively bound letters come first and win any key collision with a
	-- declared target: an explicit choice beats config.
	for _, binding in ipairs(M.bindings()) do
		local best
		for _, tab in ipairs(tabs) do
			if pageKey(tab.url) == binding.page then
				if not best or (tab.lastAccessed or 0) > (best.lastAccessed or 0) then
					best = tab
				end
			end
		end
		claimedKeys[binding.key] = true
		seenUrls[binding.page] = true
		table.insert(rows, {
			key = binding.key,
			label = best and (best.title or best.url) or ((binding.title or binding.page) .. "   (closed)"),
			profile = best and best.profile or (binding.profile or ""),
			tab = best,
			url = binding.page,
			binding = binding,
			isBound = true,
		})
	end

	for _, name in ipairs(firefoxTabs.targetOrder) do
		local target = firefoxTabs.targets[name]
		if target and target.key and not claimedKeys[target.key] then
			local best
			for _, tab in ipairs(tabs) do
				if (tab.url or ""):find(target.match, 1, true) then
					if not best or (tab.lastAccessed or 0) > (best.lastAccessed or 0) then
						best = tab
					end
				end
			end
			if not (best and seenUrls[pageKey(best.url)]) then
				claimedKeys[target.key] = true
				if best then
					seenUrls[pageKey(best.url)] = true
				end
				table.insert(rows, {
					key = target.key,
					label = best and (best.title or best.url) or (name .. "  (open)"),
					profile = best and best.profile or "",
					tab = best,
					url = target.url,
					isTarget = true,
				})
			end
		end
	end

	local candidates = {}
	for _, tab in ipairs(tabs) do
		table.insert(candidates, tab)
	end
	-- Sort before deduping, so the most recently used copy of a page is the one
	-- that earns the row.
	table.sort(candidates, function(a, b)
		return (a.lastAccessed or 0) > (b.lastAccessed or 0)
	end)

	local pool = {}
	for _, key in ipairs(RECENT_KEY_POOL) do
		if not claimedKeys[key] then
			table.insert(pool, key)
		end
	end

	local used = 0
	for _, tab in ipairs(candidates) do
		if used >= RECENT_ROWS or used >= #pool then
			break
		end
		local key = pageKey(tab.url)
		if not seenUrls[key] then
			seenUrls[key] = true
			used = used + 1
			table.insert(rows, {
				key = pool[used],
				label = tab.title or tab.url,
				profile = tab.profile,
				tab = tab,
				firstRecent = (used == 1),
			})
		end
	end

	return rows
end

local function text(value, color, x, y, width)
	return {
		type = "text",
		frame = { x = x, y = y, h = ROW_H, w = width },
		text = hs.styledtext.new(value, {
			font = { name = FONT, size = FONT_SIZE },
			color = color,
		}),
	}
end

local SEPARATOR_GAP = 8

local function draw(rows)
	local height = PADDING * 2 + (#rows + 1) * ROW_H + SEPARATOR_GAP
	local screen = hs.screen.primaryScreen():frame()
	local frame = {
		x = screen.x + (screen.w - PANEL_W) / 2,
		y = screen.y + (screen.h - height) / 3,
		w = PANEL_W,
		h = height,
	}

	if M.canvas then
		M.canvas:delete()
	end
	M.canvas = hs.canvas.new(frame)
	M.canvas:level(hs.canvas.windowLevels.overlay)
	M.canvas:behavior(hs.canvas.windowBehaviors.canJoinAllSpaces)

	local elements = {
		{
			type = "rectangle",
			action = "fill",
			fillColor = COLOR_BG,
			frame = { x = "0", y = "0", h = "1", w = "1" },
			roundedRectRadii = { xRadius = 8, yRadius = 8 },
			withShadow = true,
		},
	}

	-- Once the separator is drawn, every row below it shifts by the same gap;
	-- offsetting only the separator's own row would leave uneven spacing.
	local offset = 0

	for i, row in ipairs(rows) do
		if row.firstRecent then
			table.insert(elements, {
				type = "rectangle",
				action = "fill",
				fillColor = COLOR_RULE,
				frame = {
					x = PADDING,
					y = PADDING + (i - 1) * ROW_H + offset + SEPARATOR_GAP / 2,
					h = 1,
					w = PANEL_W - PADDING * 2,
				},
			})
			offset = offset + SEPARATOR_GAP
		end

		local y = PADDING + (i - 1) * ROW_H + offset
		local isPending = (M.pendingRebind == row)
		if isPending then
			table.insert(elements, {
				type = "rectangle",
				action = "fill",
				fillColor = COLOR_SELECTED,
				frame = { x = PADDING, y = y, h = ROW_H, w = PANEL_W - PADDING * 2 },
				roundedRectRadii = { xRadius = 4, yRadius = 4 },
			})
		end

		local keyColor = row.isBound and COLOR_BOUND or COLOR_KEY
		if isPending then
			keyColor = COLOR_SELECTED_KEY
		end
		table.insert(elements, text(isPending and "▸" or row.key, keyColor, KEY_X, y, KEY_W))
		if row.profile ~= "" then
			local color = PROFILE_COLORS[row.profile] or COLOR_PROFILE_FALLBACK
			table.insert(elements, text(row.profile, color, BADGE_X, y, BADGE_W))
		end
		table.insert(elements, text(row.label, COLOR_TEXT, TITLE_X, y, PANEL_W - TITLE_X - PADDING))
	end

	local hint
	if M.pendingRebind then
		hint = "press a letter for: " .. (M.pendingRebind.label or "")
		if M.pendingRebind.isBound then
			hint = hint .. "      ⌫ unbind"
		end
	else
		hint = "⇧+letter  rebind that row      esc  close"
	end
	table.insert(
		elements,
		text(hint, COLOR_HINT, KEY_X, PADDING + #rows * ROW_H + offset, PANEL_W - KEY_X - PADDING)
	)

	M.canvas:replaceElements(elements)
	M.canvas:show()
end

function M.hide()
	M.isOpen = false
	M.pendingRebind = nil
	if M.tap then
		M.tap:stop()
		M.tap = nil
	end
	if M.canvas then
		M.canvas:delete()
		M.canvas = nil
	end
	if M.watcher then
		M.watcher:stop()
		M.watcher = nil
	end
end

local function activate(row)
	M.hide()
	if row.tab then
		firefoxTabs.focus(row.tab)
	elseif row.url then
		hs.urlevent.openURL(row.url)
	end
end

-- Declared ahead of the key handlers, which re-render after a rebind.
local render

-- Persist `letter` for the page shown on `row`, dropping whatever held that
-- letter before and any earlier binding for the same page (so rebinding a row
-- moves it rather than duplicating it).
local function assignLetter(row, letter)
	local page = row.tab and pageKey(row.tab.url) or row.url
	if not page or page == "" then
		hs.alert.show("nothing to bind on that row")
		return
	end

	local title = row.tab and (row.tab.title or row.tab.url) or (row.binding and row.binding.title) or row.label
	local kept = {}
	for _, binding in ipairs(M.bindings()) do
		if binding.key ~= letter and binding.page ~= page then
			table.insert(kept, binding)
		end
	end
	table.insert(kept, {
		key = letter,
		page = page,
		title = title,
		profile = row.tab and row.tab.profile or row.profile,
	})
	M.setBindings(kept)
end

local function unbind(row)
	if not row.binding then
		return
	end
	local kept = {}
	for _, binding in ipairs(M.bindings()) do
		if binding.page ~= row.binding.page then
			table.insert(kept, binding)
		end
	end
	M.setBindings(kept)
end

render = function(tabs)
	local rows = M.buildRows(tabs)
	if #rows == 0 then
		M.hide()
		hs.alert.show("no Firefox tabs indexed")
		return
	end
	M.rows = rows
	M.pendingRebind = nil
	draw(rows)
end

-- One eventtap for the whole panel rather than a hotkey per row. Two reasons:
-- shift is just a flag on the event, and nothing has to delete the hotkey it is
-- currently firing from in order to change modes.
local function handleKey(event)
	local flags = event:getFlags()
	-- Let system shortcuts (⌘Q, ⌘Tab, …) through untouched.
	if flags.cmd or flags.ctrl or flags.alt or flags.fn then
		return false
	end

	local key = hs.keycodes.map[event:getKeyCode()]
	if type(key) ~= "string" then
		return true
	end

	if M.pendingRebind then
		local row = M.pendingRebind
		if key == "escape" then
			M.pendingRebind = nil
			draw(M.rows)
		elseif key == "delete" or key == "forwarddelete" then
			unbind(row)
			render(firefoxTabs.tabs)
		elseif ASSIGNABLE_KEYS[key] then
			assignLetter(row, key)
			render(firefoxTabs.tabs)
		end
		return true
	end

	if key == "escape" then
		M.hide()
		return true
	end

	for _, row in ipairs(M.rows) do
		if row.key == key then
			if flags.shift then
				-- Pick the row instead of jumping to it; redraw to show which.
				M.pendingRebind = row
				draw(M.rows)
			else
				activate(row)
			end
			return true
		end
	end

	return true
end

function M.toggle()
	if M.isOpen then
		M.hide()
		return
	end

	M.isOpen = true
	M.pendingRebind = nil
	M.tap = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, handleKey)
	M.tap:start()

	-- Show from cache at once, then swap in a fresh index (~150ms). Bound and
	-- target rows keep their letters; only recents can shift.
	if #firefoxTabs.tabs > 0 then
		render(firefoxTabs.tabs)
	end
	firefoxTabs.reindex(function(tabs)
		-- Never redraw mid-rebind: it would move rows under the second keystroke.
		if M.isOpen and not M.pendingRebind then
			render(tabs)
		end
	end)

	M.watcher = hs.application.watcher.new(function(_, eventType)
		if eventType == hs.application.watcher.activated then
			M.hide()
		end
	end)
	M.watcher:start()
end

return M
