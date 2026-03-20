-- When Slack is focused, if the pasteboard contains a GitLab MR URL,
-- replace it with a rich-text snippet: "repo!123" linking to the URL.

local M = {}

local mrPattern = "^(https://[^/]+/(.+)/%-/merge_requests/(%d+))"

local function linkizePasteboard()
	local contents = hs.pasteboard.getContents()
	if not contents then
		return
	end

	-- Trim whitespace
	contents = contents:match("^%s*(.-)%s*$")

	local url, projectPath, mrId = contents:match(mrPattern)
	if not url then
		return
	end

	-- Extract last path component as repo name
	local repo = projectPath:match("([^/]+)$")
	local linkText = repo .. "!" .. mrId
	local plainText = linkText .. " — " .. url
	local html = '<a href="' .. url .. '">' .. linkText .. "</a>"

	-- Use osascript to set both HTML and plain text on the pasteboard,
	-- matching the approach from linkize-gitlab.sh
	local hexHtml = ""
	for i = 1, #html do
		hexHtml = hexHtml .. string.format("%02x", html:byte(i))
	end

	local escapedPlain = plainText:gsub('"', '\\"')
	local script = string.format(
		'set the clipboard to {«class HTML»:«data HTML%s», string:"%s"}',
		hexHtml,
		escapedPlain
	)
	hs.osascript.applescript(script)

	hs.alert.show("📋 " .. linkText, {}, 1.5)
end

function M.start()
	M.watcher = hs.application.watcher.new(function(appName, eventType, _appObject)
		if eventType == hs.application.watcher.activated and appName == "Slack" then
			linkizePasteboard()
		end
	end)
	M.watcher:start()
end

function M.stop()
	if M.watcher then
		M.watcher:stop()
	end
end

return M
