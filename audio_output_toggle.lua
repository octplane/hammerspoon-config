function toggle_output(out)
  if out ==  nil then
    return
  end

  local uid = out["uid"]
  local current = hs.audiodevice.defaultOutputDevice()
  if current:uid() == uid then
    return
  end

  local device = hs.audiodevice.findOutputByUID(uid)
  if uid == nil then
    return
  end

  device:setDefaultOutputDevice()
  hs.notify.new({
      title='Hammerspoon',
      informativeText='Default output device: '.. out['text']
  }):send()
end

local chooser = hs.chooser.new(toggle_output)

function get_outputs()
  local devices = hs.audiodevice.allOutputDevices()
  local local_outputs = {}
  for d=1, #devices do
    local device = devices[d]
    local_outputs[#local_outputs+1] = {
      text=device:name(),
      uid=device:uid()
    }
  end
  hs.inspect.inspect(local_outputs)
  return local_outputs
end

function toggle_audio_chooser()
  local choices = get_outputs()
  chooser:choices(choices)
  chooser:show()
end


return toggle_audio_chooser

