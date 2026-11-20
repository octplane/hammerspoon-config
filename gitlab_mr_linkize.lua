-- When Slack is focused, if the pasteboard contains a GitLab MR URL,
-- replace it with a rich-text snippet: "repo!123" (or "comment on repo!123") linking to the URL.

local M = {}

local mrPattern = "^(https://[^/]+/(.+)/%-/merge_requests/(%d+)%S*)"
local jiraPattern = "^(https://[^/]+/browse/([A-Z][A-Z0-9_]+%-(%d+))%S*)"
local anchorPattern = "^(https://[^#]+)#(.*)$"
local function linkizePasteboard()
	local contents = hs.pasteboard.getContents()
	if not contents then
		return
	end

	-- Trim whitespace
	contents = contents:match("^%s*(.-)%s*$")

	local url, linkText

	-- Try GitLab MR pattern
	local mrUrl, projectPath, mrId = contents:match(mrPattern)
	if mrUrl then
		url = mrUrl
		print(contents)
		local mUrl, anchor = contents:match(anchorPattern)
		if string.find("?", url) then
			url = mrUrl ..  "no_unfurl"
		else
		  url = mrUrl .. "?no_unfurl"
		end
		if anchor ~= "" and anchor ~= nil then
			url = url .. "#" .. anchor
		end
		print(url)
		
		local repo = projectPath:match("([^/]+)$")
		linkText = repo .. "!" .. mrId
		-- A #note_<id> anchor points at a specific comment on the MR
		if mrUrl:match("#note_%d+") then
			linkText = "comment on " .. linkText
		end
	end

	-- Try Jira/Confluence ticket pattern
	if not url then
		local jiraUrl, ticketKey = contents:match(jiraPattern)
		if jiraUrl then
			url = jiraUrl
			linkText = ticketKey
		end
	end

	if not url then
		return
	end
	local plainText = linkText .. " — " .. url
	local html = '<a href="' .. url .. '">' .. linkText .. "</a>"

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
