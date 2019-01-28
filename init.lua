 -- Enable this to do live debugging in ZeroBrane Studio
-- local ZBS = "/Applications/ZeroBraneStudio.app/Contents/ZeroBraneStudio"
-- package.path = package.path .. ";" .. ZBS .. "/lualibs/?/?.lua;" .. ZBS .. "/lualibs/?.lua"
-- package.cpath = package.cpath .. ";" .. ZBS .. "/bin/?.dylib;" .. ZBS .. "/bin/clibs53/?.dylib"
-- require("mobdebug").start()

local fennel = require "fennel"
print("Loaded fennel")
local f = io.open("init.fnl", "rb")
local mycode_new =
  fennel.eval(
  f:read("*all"),
  {
    filename = "init.fnl"
  }
)
f:close()

-- Define audio device names for headphone/speaker switching
displayPort = "DisplayPort"
builtin = "Built-in Output"
--speakerDevice = "Built-in Output"

function toggle_audio_output()
    local current = hs.audiodevice.defaultOutputDevice()
    local speakers = hs.audiodevice.findOutputByName(builtin)
    local screen = hs.audiodevice.findOutputByName(displayPort)

    if not speakers or not screen then
        hs.notify.new({title="Hammerspoon", informativeText="ERROR: Some audio devices missing", ""}):send()
        return
    end

    if current:name() == speakers:name() then
        screen:setDefaultOutputDevice()
    else
        speakers:setDefaultOutputDevice()
    end
    hs.notify.new({
          title='Hammerspoon',
            informativeText='Default output device: '..hs.audiodevice.defaultOutputDevice():name()
        }):send()
end

hyper = {"⌘", "⌥", "⌃", "⇧"}
hs.hotkey.bind(hyper, "s", toggle_audio_output)

