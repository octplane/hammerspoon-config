-- Hazel like tag coloring feature
Bretzel = {}

local fnutils = require "hs.fnutils"
local fs = require "hs.fs"

-- tag is https://github.com/jdberry/tag
-- -Ng = no display of filename
--       one tag per line
local tagCommand = os.getenv("HOME") .. "/bin/tag"
local tagCommandList= tagCommand .. " -Ng"


function Bretzel.boot(tagsAndAge, archiveAge)

  local function ScanFiles()
    print("Desktop cleaner waking up...")
    local desktop = os.getenv("HOME") .. "/Desktop/"
    local iter, dir_data = hs.fs.dir(desktop)
    while true do
  	  local basename = iter(dir_data)
  	  if basename == nil then break end
      local fname = desktop .. basename
      ProcessFile(fname, basename, tagsAndAge, archiveAge)
    end
  end

  bretzelTimer = hs.timer.new(3600, ScanFiles)
  bretzelTimer:start()
  ScanFiles()

end

function ProcessFile(fname, basename, tagsAndAge, archiveAge)
  local mode = hs.fs.attributes(fname, "mode")

  -- ignore non files
  if mode ~= "file" then
    return
  end

  local now = os.time()
  local since = now - hs.fs.attributes(fname, "access")
  local tag = ""

  if since > archiveAge then
    local archiveFolder = os.getenv("HOME") .. "/Desktop/" .. "Archive/"
    hs.fs.mkdir(archiveFolder)
    os.rename(fname, archiveFolder .. basename)
  else

    for tagName, duration in pairs(tagsAndAge) do
      if since > duration then
        tag = tagName
      end
    end

    local tagParams = ""
    if tag ~= "" then
      tagParams = " -s " .. tag
      efname = shell.escape(fname)
      print(tagCommand .. tagParams .. " " .. efname)
      os.execute(tagCommand .. tagParams .. " " .. efname)
    end

  end
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


function GetTags(fname)
  local cmd = tagCommand .. " " .. fname
  local tags = {}
  -- output consists of one line per tag
  local extracted_tags = os.capture(cmd, true)

  if string.len(extracted_tags) > 0 then
    tags = SplitWithoutLastEmpty(extracted_tags, "\r?\n")
  end
  return tags
end

function HasTag(fname, needle)
  local tags = GetTags(fname)
  for ix,tag in pairs(tags) do
    if tag == needle then
      return true
    end
  end
  return false
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

shell = {}

function shell.escape(...)
 local command = type(...) == 'table' and ... or { ... }
 for i, s in ipairs(command) do
  s = (tostring(s) or ''):gsub('"', '\\"')
  if s:find '[^A-Za-z0-9_."/-]' then
   s = '"' .. s .. '"'
  elseif s == '' then
   s = '""'
  end
  command[i] = s
 end
 return table.concat(command, ' ')
end

function shell.execute(...)
 return os.execute(shell.escape(...))
end


return Bretzel
