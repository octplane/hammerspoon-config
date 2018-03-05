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

function is_this_the_keyboard()
  local usbs = hs.usb.attachedDevices()
  for k, v in pairs(usbs) do
    if v.productID == 8240 then
      print("Detected Typematrix Keyboard")
      return true
    end
  end
  return false
end
