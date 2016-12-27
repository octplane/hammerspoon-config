-- Hazel like tag coloring feature
Bretzel = {}

local fnutils = require "hs.fnutils"
local fs = require "hs.fs"

local subfolders = { mp3 = "Musics",
 aac = "Musics",
 flac = "Musics",
 ogg = "Musics",
 wma = "Musics",
 m4a = "Musics",
 aiff = "Musics",
 wav = "Musics",
 amr = "Musics",
 flv = "Videos",
 ogv = "Videos",
 avi = "Videos",
 mp4 = "Videos",
 mpg = "Videos",
 mpeg = "Videos",
 ["3gp"] = "Videos",
 mkv = "Videos",
 m4v = "Videos",
 ts = "Videos",
 webm = "Videos",
 vob = "Videos",
 wmv = "Videos",
 png = "Pictures",
 webp = "Pictures",
 ico = "Pictures",
 gif = "Pictures",
 jpg = "Pictures",
 bmp = "Pictures",
 svg = "Pictures",
 webp = "Pictures",
 psd = "Pictures",
 tiff = "Pictures",
 rar = "Archives",
 zip = "Archives",
 ["7z"] = "Archives",
 gz = "Archives",
 bz2 = "Archives",
 tar = "Archives",
 dmg = "Archives",
 tgz = "Archives",
 xz = "Archives",
 iso = "Archives",
 cpio = "Archives",
 txt = "Documents",
 pdf = "Documents",
 doc = "Documents",
 docx = "Documents",
 odf = "Documents",
 xls = "Documents",
 xlsv = "Documents",
 xlsx = "Documents",
 ppt = "Documents",
 pptx = "Documents",
 ppsx = "Documents",
 odp = "Documents",
 odt = "Documents",
 ods = "Documents",
 md = "Documents",
 json = "Documents",
 csv = "Documents",
 mobi = "Books",
 epub = "Books",
 chm = "Books",
 deb = "DEBPackages",
 exe = "Programs",
 msi = "Programs",
 rpm = "RPMPackages"
}

function Bretzel.boot(path, tagsAndAge, archiveAge)

  local function ScanFiles()
    print("cleaner waking up for " .. path)
    local iter, dir_data = hs.fs.dir(path)
    while true do
  	  local basename = iter(dir_data)
      if basename == ".." or basename == "." then
      else
        if basename == nil then break end
        local fname = path .. basename
        ProcessFile(path, fname, basename, tagsAndAge, archiveAge)
      end
    end
  end

  bretzelTimer = hs.timer.new(3600, ScanFiles)
  bretzelTimer:start()
  ScanFiles()

end

function ProcessFile(path, fname, basename, tagsAndAge, archiveAge)
  local now = os.time()
  local since = now - hs.fs.attributes(fname, "modification")
  local tag = ""
  local sf = "Default"

  print(basename)
  local s,e = string.find(basename, "%.[^%.]+$")
  print(s)
  if s then
    local ext = string.lower(string.sub(basename, s + 1))
    print("Extension is " .. ext)
    sf = subfolders[ext]
    if sf == nil then
      sf = "Default"
    end
    print(basename .. " -> " .. sf .. "/" .. basename)
  else
    print("No extensions for ".. basename)
  end

  if since > archiveAge then
    local archiveFolder = path .. "Archive/" .. sf .. "/"
    hs.fs.mkdir(archiveFolder)

    -- remove tags
    existingTags = hs.fs.tagsGet(fname)
    hs.fs.tagsRemove(fname, existingTags)

    -- move to archive
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
