-- Update the fan and temp. Needs iStats CLI tool from homebrew.
local function updateStats()
  fanSpeed = os.capture("/Users/octplane/.rbenv/versions/2.2.2/bin/istats fan speed | cut -c14- | sed 's/\\..*//'")
  temp = os.capture("/Users/octplane/.rbenv/versions/2.2.2/bin/istats cpu temp | cut -c11- | sed 's/\\..*//'")
end

local function makeStatsMenu(calledFromWhere)
  if statsMenu == nil then
    statsMenu = hs.menubar.new()
  end
  updateStats()
  statsMenu:setTitle(" F:" .. fanSpeed .. " | T:" .. temp)
end

-- How often to update Fan and Temp
updateStatsInterval = 20
statsMenuTimer = hs.timer.new(updateStatsInterval, makeStatsMenu)
statsMenuTimer:start()
makeStatsMenu()
