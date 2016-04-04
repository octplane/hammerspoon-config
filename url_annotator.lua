-- https://gist.github.com/vitorgalvao/5392178
UrlAnnotator = {}

function UrlAnnotator.annotate()
  script = [[

# This example will return both the URL and title for the frontmost tab of the active browser, separated by a newline.
# Keep in mind that by using `using terms from`, we’re basically requiring that referenced browser to be available on the system
# (i.e., to use this on "Google Chrome Canary" or "Chromium", "Google Chrome" needs to be installed).
# This is required to be able to use a variable in `tell application`. If it is undesirable, the accompanying example should be used instead.

tell application "System Events" to set frontApp to name of first process whose frontmost is true

if (frontApp = "Safari") or (frontApp = "Webkit") then
  using terms from application "Safari"
    tell application frontApp to set currentTabUrl to URL of front document
    tell application frontApp to set currentTabTitle to name of front document
  end using terms from
else if (frontApp = "Google Chrome") or (frontApp = "Google Chrome Canary") or (frontApp = "Chromium") then
  using terms from application "Google Chrome"
    tell application frontApp to set currentTabUrl to URL of active tab of front window
    tell application frontApp to set currentTabTitle to title of active tab of front window
  end using terms from
else
  return "You need a supported browser as your frontmost app"
end if

return currentTabUrl & "\n" & currentTabTitle
]]
  ok, result = hs.applescript(script)
  hs.notify.show("Hammerspoon", "", result, "")
end

return UrlAnnotator
