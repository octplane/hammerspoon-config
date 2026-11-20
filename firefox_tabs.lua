-- Cross-profile Firefox tab index and switcher.
--
-- Index: every profile's sessionstore recovery file, dumped as JSON by the
-- `firefox-tabs` helper. Gives url + title + window + position per tab, for all
-- profiles at once — including ones that aren't running.
--
-- Actuation: the accessibility tree of each running Firefox instance. The tab
-- strip is an AXTabGroup whose AXRadioButton children carry the tab title in
-- AXTitle, so we locate the tab by title and AXPress it. Nothing to install in
-- the browser: no extension, no native messaging host.

local M = {}

local INDEXER = os.getenv("HOME") .. "/.nix-profile/bin/firefox-tabs"
local BUNDLE_ID = "org.mozilla.firefox"

M.tabs = {}

-- Named targets, the equivalent of foxhop's tabs.json. `match` is tested
-- against the tab url; `url` is opened when no tab matches; `key` is the letter
-- firefox_tab_panel assigns to it.
M.targets = {
	qobuz = { key = "q", match = "play.qobuz.com", url = "https://play.qobuz.com/discover/new-releases" },
	mail = { key = "m", match = "app.fastmail.com", url = "https://app.fastmail.com/mail/Inbox" },
	jira = { key = "t", match = "loftorbital.atlassian.net/browse" },
	gitlab = { key = "g", match = "gitlab.com/loft-orbital" },
	confluence = { key = "c", match = "loftorbital.atlassian.net/wiki" },
	calendar = { key = "y", match = "calendar.google.com", url = "https://calendar.google.com/calendar/r" },
}

-- Panel row order. Explicit because Lua hash iteration order is not stable, and
-- rows that move between invocations defeat the point of a keystroke panel.
M.targetOrder = { "qobuz", "mail", "jira", "gitlab", "confluence", "calendar" }

-- The strip title and the flushed sessionstore title drift apart: auto-tab-discard
-- prefixes unloaded tabs with 💤, and mail/chat tabs carry a moving unread count.
-- Strip both before comparing.
local function normalize(title)
	return (title or ""):gsub("💤", ""):gsub("%(%d+%)", ""):gsub("%s+", " "):gsub("^ ", ""):gsub(" $", ""):lower()
end

-- Firefox exposes several AXTabGroups (the strip, plus the tab-group feature).
-- The strip is the one with the most AXRadioButton children.
local function findTabStrip(element, depth)
	if depth > 5 then
		return nil, 0
	end
	local best, bestCount = nil, 0
	for _, child in ipairs(element:attributeValue("AXChildren") or {}) do
		local role = child:attributeValue("AXRole")
		if role == "AXTabGroup" then
			local count = 0
			for _, tab in ipairs(child:attributeValue("AXChildren") or {}) do
				if tab:attributeValue("AXRole") == "AXRadioButton" then
					count = count + 1
				end
			end
			if count > bestCount then
				best, bestCount = child, count
			end
		elseif role ~= "AXWebArea" then
			-- Never descend into page content: it is unbounded.
			local found, count = findTabStrip(child, depth + 1)
			if found and count > bestCount then
				best, bestCount = found, count
			end
		end
	end
	return best, bestCount
end

local function eachTabStrip(fn)
	for _, app in ipairs(hs.application.applicationsForBundleID(BUNDLE_ID)) do
		local axApp = hs.axuielement.applicationElement(app)
		if axApp then
			for _, axWindow in ipairs(axApp:attributeValue("AXWindows") or {}) do
				local strip = findTabStrip(axWindow, 0)
				if strip then
					fn(app, axWindow, strip)
				end
			end
		end
	end
end

-- Focus the tab described by an index entry. Returns true if a live tab was
-- found; otherwise opens the url so the action never silently does nothing.
function M.focus(tab)
	local wanted = normalize(tab.title)
	local match

	eachTabStrip(function(app, axWindow, strip)
		for position, axTab in ipairs(strip:attributeValue("AXChildren") or {}) do
			if axTab:attributeValue("AXRole") == "AXRadioButton" then
				if normalize(axTab:attributeValue("AXTitle")) == wanted then
					-- Duplicate titles are common (two Jira boards, two GitLab MRs);
					-- prefer the one sitting where the index said it would be.
					if not match or position == tab.index then
						match = { app = app, window = axWindow, tab = axTab }
					end
				end
			end
		end
	end)

	if match then
		match.tab:performAction("AXPress")
		local window = match.window:asHSWindow()
		if window then
			window:focus()
		else
			match.app:activate()
		end
		return true
	end

	if tab.url then
		hs.urlevent.openURL(tab.url)
	end
	return false
end

function M.reindex(callback)
	hs.task
		.new(INDEXER, function(code, stdout, stderr)
			if code ~= 0 then
				hs.alert.show("firefox-tabs failed")
				print("firefox-tabs: " .. (stderr or ""))
				return
			end
			M.tabs = hs.json.decode(stdout) or {}
			if callback then
				callback(M.tabs)
			end
		end)
		:start()
end

local function choices()
	local out = {}
	for _, tab in ipairs(M.tabs) do
		table.insert(out, {
			text = tab.title or tab.url,
			subText = tab.profile .. (tab.pinned and " · pinned · " or " · ") .. (tab.url or ""),
			tab = tab,
		})
	end
	return out
end

-- One chooser for the life of the config, built on first use. hs.chooser
-- objects are not released when they close, so constructing a fresh one per
-- invocation accumulated them (audio_output_toggle.lua already does this).
local tabChooser = nil

-- Chooser over every tab of every profile. Shows the cached index instantly and
-- swaps in a fresh one when the indexer returns (~150ms).
function M.chooser()
	if not tabChooser then
		tabChooser = hs.chooser.new(function(choice)
			if choice then
				M.focus(choice.tab)
			end
		end)
		tabChooser:searchSubText(true)
	end
	tabChooser:choices(choices())
	M.reindex(function()
		tabChooser:choices(choices())
	end)
	tabChooser:show()
end

-- Jump straight to a named target, reindexing first so the hit is never stale.
function M.hop(name)
	return function()
		local target = M.targets[name]
		if not target then
			hs.alert.show("no foxhop target " .. name)
			return
		end
		M.reindex(function(tabs)
			local best
			for _, tab in ipairs(tabs) do
				if (tab.url or ""):find(target.match, 1, true) then
					if not best or (tab.lastAccessed or 0) > (best.lastAccessed or 0) then
						best = tab
					end
				end
			end
			if best then
				M.focus(best)
			elseif target.url then
				hs.urlevent.openURL(target.url)
			else
				hs.alert.show("no tab matching " .. target.match)
			end
		end)
	end
end

return M
