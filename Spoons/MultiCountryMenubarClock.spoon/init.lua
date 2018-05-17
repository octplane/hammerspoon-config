local obj = {}
obj.__index = obj

-- Metadata
obj.name = "MultiCountryMenubarClock"
obj.version = "0.1"
obj.author = "Pierre BAILLET <pierre@baillet.name>"
obj.homepage = "https://github.com/Hammerspoon/Spoons"
obj.license = "MIT - https://opensource.org/licenses/MIT"

local function get_timezone()
  local now = os.time()
  return os.difftime(now, os.time(os.date("!*t", now)))
end

function obj:init()
  local function update()
    self:displayTime()
  end
  local function toggle()
    self.current_clock = self.current_clock + 1
    if self.current_clock > #self.clocks then
      self.current_clock = 1
    end
    self:displayTime()
  end
  self.menubar = hs.menubar.new()
  self.timer = hs.timer.doEvery(2, update)
  self.menubar:setClickCallback(toggle)

  self.clocks = {
    {
      clock = 3600,
      prefix = "🇫🇷",
      tooltip = "Home"
    },
    {
      clock = -5 * 3600,
      prefix = "🇺🇸",
      tootip = "ET"
    }
  }
  self.current_clock = 1

  print("mc MultiCountryMenubarClock starting")
  update()
end

function obj:displayTime()
  local clock = self.clocks[self.current_clock]
  local tz = clock["clock"]
  local prefix = clock["prefix"]
  local local_tz = get_timezone()

  if tz == local_tz then
    prefix = ""
  end

  self.menubar:setTitle(prefix .. os.date("%H:%M", os.time() + tz - local_tz))
end

return obj
