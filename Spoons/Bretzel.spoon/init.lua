-- Hazel like tag coloring feature
local obj = {}

obj.__index = obj
-- Metadata
obj.name = "Bretzel"
obj.version = "0.1"
obj.author = "Pierre Baillet <pierre@baillet.name>"
obj.homepage = "https://github.com/Hammerspoon/Spoons"
obj.license = "MIT - https://opensource.org/licenses/MIT"

obj.logger = hs.logger.new("Bretzel")

local subfolders = {
  mp3 = "Musics",
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

function obj:init()
  -- is the emojis file available?
  print("Starting Bretzel Spoon...")
end

--           if set to false, sort only inside the Archive folder
function obj:boot(path, tagsAndAge, archiveAge)
  self.logger.i("Starting for " .. path)
  local function ScanFiles()
    self.logger.i("Waking up for " .. path)
    self:processDirectory(path, path, tagsAndAge, archiveAge)
  end

  BretzelTimer = hs.timer.new(100, ScanFiles)
  BretzelTimer:start()
  ScanFiles()
end

function obj:processDirectory(directory_root, scan_root, tagsAndAge, archiveAge)
  -- every file in here should be relocated to directory_root .. subfolder
  local iter, dir_data = hs.fs.dir(directory_root)
  while true do
    local basename = iter(dir_data)
    if basename == ".." or basename == "." then
    else
      if basename == nil then
        break
      end
      local fname = directory_root .. "/" .. basename

      if basename == "Archive" and directory_root == scan_root then
        -- do nothing
      else
        -- process every item as if they were files
        self:processFile(scan_root, fname, basename, tagsAndAge, archiveAge)
      end
    end
  end
end

function obj:processFile(scan_root, fname, basename, tagsAndAge, archiveAge)
  local now = os.time()
  local since = now - hs.fs.attributes(fname, "modification")
  local tag = ""
  local sf = "Default"
  self.logger.i(fname .. ", since:" .. since)

  local s, _ = string.find(basename, "%.[^%.]+$")
  if s then
    local ext = string.lower(string.sub(basename, s + 1))
    sf = subfolders[ext]
    if sf == nil then
      sf = "Default"
    end
  else
    self.logger.i("No extensions for " .. basename)
  end

  if since > archiveAge then
    -- remove tags
    local existingTags = hs.fs.tagsGet(fname)
    if existingTags then
      hs.fs.tagsRemove(fname, existingTags)
    end

    local archiveFolder = scan_root .. "/Archive/" .. sf .. "/"
    self.logger.i("Archive folder: " .. archiveFolder)
    local dest = archiveFolder .. basename
    if dest ~= fname then
      hs.fs.mkdir(scan_root .. "/Archive")
      hs.fs.mkdir(archiveFolder)
      -- move to archive
      self.logger.i(fname .. " -> " .. archiveFolder .. " | " .. basename)
      os.rename(fname, archiveFolder .. basename)
    else
      os.remove(fname)
    end
  else
    for tagName, duration in pairs(tagsAndAge) do
      if since > duration then
        self.logger.i(fname .. "(since:" .. since .. ", archiveAge:" .. archiveAge .. "): " .. tagName)
        tag = tagName
      end
    end

    if tag ~= "" then
      -- we actually SET the tag and erase all others.
      -- this kinda sucks if you have your tags in this folder
      local existingTags = hs.fs.tagsGet(fname)
      if existingTags ~= nil then
        hs.fs.tagsRemove(fname, existingTags)
      end
      local newTags = {}
      newTags[1] = tag
      local ok, err = pcall(hs.fs.tagsSet, fname, newTags)
      if not ok then
        print("Unable to set tag on " .. fname .. ": " .. err)
      end
    end
  end
end

return obj
