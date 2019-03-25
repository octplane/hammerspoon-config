function toggle_audio_output()
    -- Define audio device names for headphone/speaker switching
    displayPort = "DisplayPort"
    builtin = "Built-in Output"
    headphones = "Headphone port"
    local current = hs.audiodevice.defaultOutputDevice()
    local speakers = hs.audiodevice.findOutputByName(builtin) or hs.audiodevice.findOutputByName(headphones)
    local screen = hs.audiodevice.findOutputByName(displayPort)

    if not speakers or not screen then
        hs.notify.new({title="Hammerspoon", informativeText="ERROR: Some audio devices are missing.", ""}):send()
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

return toggle_audio_output

