
hs.loadSpoon("Bretzel")

local bretzelConfig = {
  Desktop = {
    archiveAge = (86400 * 12),
    sortRoot = false,
    tagsAndAge = {
      Orange = (86400 * 4),
      Rouge = (86400 * 8)
    },
    path = os.getenv("HOME") .. "/Desktop"
  },
  Downloads = {
    archiveAge = (86400 * 10),
    sortRoot = true,
    tagsAndAge = {
      Vert = 86400,
      Orange = 86400
    },
    path = os.getenv("HOME") .. "/Downloads"
  }
}

for _, conf in pairs(bretzelConfig) do
  spoon.Bretzel:boot(conf["path"], conf["tagsAndAge"], conf["archiveAge"], conf["sortRoot"])
end
