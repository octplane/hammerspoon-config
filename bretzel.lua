-- Hazel like tag coloring feature
Bretzel = {}

local fnutils = require "hs.fnutils"
local fs = require "hs.fs"

local subfolders = { mp3 = "Musics",
 app = "Apps",
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
 rtf = "Documents",
 mobi = "Books",
 epub = "Books",
 chm = "Books",
 deb = "DEBPackages",
 exe = "Programs",
 msi = "Programs",
 rpm = "RPMPackages",
 yml = "Code",
 smc = "Roms",
 torrent = "Torrents",
 ttf = "Fonts"
}

-- sortRoot: if set to true, will sort path
--           if set to false, sort only inside the Archive folder

function Bretzel.boot(path, tagsAndAge, archiveAge, sortRoot)

  local function ScanFiles()
    print("Bretzel waking up for " .. path)
    ProcessDirectory(path, path, tagsAndAge, archiveAge, sortRoot)
  end

  bretzelTimer = hs.timer.new(3600, ScanFiles)
  bretzelTimer:start()
  ScanFiles()

end

function ProcessDirectory(directory_root, scan_root, tagsAndAge, archiveAge, sortHere)
  print("Scanning Directory " .. directory_root)
   -- every file in here should be relocated to directory_root .. subfolder
  local iter, dir_data = hs.fs.dir(directory_root)
  while true do
    local basename = iter(dir_data)
    if basename == ".." or basename == "." then
    else
      if basename == nil then break end
      local fname = directory_root .. "/" .. basename
      local mode = hs.fs.attributes(fname, "mode")
      if mode == nil then
        print(fname .. " nil")
      else
        print(fname .. " " .. mode)
      end

      if mode == "file" and sortHere then
        ProcessFile(directory_root, scan_root, fname, basename, tagsAndAge, archiveAge)
      elseif mode == "directory" then
        local s,e = string.find(basename, "%.app$")
        if s then
          ProcessFile(fname, scan_root, fname, basename, tagsAndAge, archiveAge)
        else
          ProcessDirectory(fname, scan_root, tagsAndAge, archiveAge, true)
        end
      end
    end
  end
end

function ProcessFile(directory_root, scan_root, fname, basename, tagsAndAge, archiveAge, archiveFolder)
  local now = os.time()
  local since = now - hs.fs.attributes(fname, "modification")
  local tag = ""
  local sf = "Default"

  local s,e = string.find(basename, "%.[^%.]+$")
  if s then
    local ext = string.lower(string.sub(basename, s + 1))
    sf = subfolders[ext]
    if sf == nil then
      sf = "Default"
    end
  else
    print("No extensions for ".. basename)
  end

  if since > archiveAge then
    -- remove tags
    existingTags = hs.fs.tagsGet(fname)
    if existingTags then
      hs.fs.tagsRemove(fname, existingTags)
    end

    local archiveFolder = scan_root .. "/Archive/" .. sf .. "/"
    hs.fs.mkdir(archiveFolder)
    -- move to archive
    print(scan_root .. " X " .. fname .. " -> " .. archiveFolder .. " | " .. basename)
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
