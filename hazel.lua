Hazel = {}

local fnutils = require "hs.fnutils"
local fs = require "hs.fs"

-- tag is https://github.com/jdberry/tag
-- no display of filename
-- one tag per line
local tag_path = os.getenv("HOME") .. "/bin/tag -Ng"

local orange_age = 86400 * 4
local red_age = 86400 * 8
local archive_arge = 86400 * 12

function Hazel.boot()
  local desktop = os.getenv("HOME") .. "/Desktop/"

  local iter, dir_data = hs.fs.dir(desktop)
  hs.openConsole()
  local now = os.time()

  while true do
	  local elt = iter(dir_data)
	  if elt == nil then break end
    local fname = desktop .. elt
    local since = now - hs.fs.attributes(fname, "access")


    -- if since > red_age then
    --   print("red " .. elt .. " " .. since)
    -- elseif since > orange_age then
    --   print("orange " .. elt .. " " .. since)
    -- else
    --   print("no color " .. elt)
    -- end


    get_tags(fname)

  end

end

function os.capture(cmd, raw)
  local f = io.popen(cmd, 'r')
  local s = f:read('*a')
  f:close()
  if raw then return s end
  s = string.gsub(s, '^%s+', '')
  s = string.gsub(s, '%s+$', '')
  s = string.gsub(s, '[\n\r]+', ' ')
  return s
end

function Split(str, delim, maxNb)
    -- Eliminate bad cases...
    if string.find(str, delim) == nil then
        return { str }
    end
    if maxNb == nil or maxNb < 1 then
        maxNb = 0    -- No limit
    end
    local result = {}
    local pat = "(.-)" .. delim .. "()"
    local nb = 0
    local lastPos
    for part, pos in string.gmatch(str, pat) do
        nb = nb + 1
        result[nb] = part
        lastPos = pos
        if nb == maxNb then break end
    end
    -- Handle the last field
    if nb ~= maxNb then
        result[nb + 1] = string.sub(str, lastPos)
    end
    return result
end

function SplitWithoutLastEmpty(str, delim, maxNb)
  local content = Split(str, delim, maxNb)
  if content[#content] == "" then
    table.remove(content, #content)
  end
  return content
end


function get_tags(file)
  local cmd = tag_path .. " " .. file
  local tags = {}
  -- output consists of one line per tag
  local extracted_tags = os.capture(cmd, true)

  if string.len(extracted_tags) == 0 then
    return tags
  else
    for k,v in pairs(SplitWithoutLastEmpty(extracted_tags, "\r?\n")) do
      print(file,k,v)
    end
  end



end


return Hazel
