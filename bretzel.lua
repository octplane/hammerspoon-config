-- Hazel like tag coloring feature
Bretzel = {}

local fnutils = require "hs.fnutils"
local fs = require "hs.fs"

function Bretzel.boot(path, tagsAndAge, archiveAge)

  local function ScanFiles()
    print("cleaner waking up for " .. path)
    local iter, dir_data = hs.fs.dir(path)
    while true do
  	  local basename = iter(dir_data)
  	  if basename == nil then break end
      local fname = path .. basename
      ProcessFile(path, fname, basename, tagsAndAge, archiveAge)
    end
  end

  bretzelTimer = hs.timer.new(3600, ScanFiles)
  bretzelTimer:start()
  ScanFiles()

end

function ProcessFile(path, fname, basename, tagsAndAge, archiveAge)
  local mode = hs.fs.attributes(fname, "mode")

  local now = os.time()
  local since = now - hs.fs.attributes(fname, "modification")
  local tag = ""

  if since > archiveAge then
    local archiveFolder = path .. "Archive/"
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
      -- we actually SET the tag and erase all others.
      -- this kinda sucks if you have your tags in this folder
      existingTags = hs.fs.tagsGet(fname)
      if tags ~= nil then
	hs.fs.tagsRemove(fname, existingTags)
      end
      newTags = {}
      newTags[1] = tag
      hs.fs.tagsSet(fname, newTags)
    end

  end
end

return Bretzel
