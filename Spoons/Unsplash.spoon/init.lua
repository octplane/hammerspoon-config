--- === Unsplash ===
---

local obj = {}
obj.__index = obj

-- Metadata
obj.name = "Unsplash"
obj.version = "0.1"
obj.author = "Pierre Baillet <pierre@baillet.name>"
obj.homepage = "https://github.com/Hammerspoon/Spoons"
obj.license = "MIT - https://opensource.org/licenses/MIT"

obj.logger = hs.logger.new("Unsplash")

obj.clientID = nil
obj.baseFolder = nil

function obj:init()
    self.logger:i("Spoon loaded!")
end

function obj:start(secret, base_folder)
    self.clientID = secret
    self.baseFolder = base_folder
    self:fetchNewWallpaper()
    rwp_timer =
        hs.timer.new(
        600,
        function()
            self:fetchNewWallpaper()
        end
    ):start()
end

function obj:updateWallpaperFromData(data)
    local ix = math.floor(math.random() * 10)
    local fname = self.baseFolder .. "-" .. ix .. ".png"
    print("Setting wallpaper to " .. fname)
    local f = io.open(fname, "w")
    f:write(data)
    hs.fnutils.each(
        hs.screen.allScreens(),
        function(screen)
            screen:desktopImageURL("file://" .. fname)
        end
    )
end

function obj:fetchNewWallpaper()
    hs.http.asyncGet(
        "https://api.unsplash.com/photos/random?query=ocean&orientation=landscape",
        {Authorization = "Client-ID " .. self.clientID},
        function(code, body, headers)
            if code == 200 then
                local url = hs.json.decode(body)["urls"]["raw"]
                hs.http.asyncGet(
                    url,
                    nil,
                    function(code, image, headers)
                        if code == 200 then
                            self:updateWallpaperFromData(image)
                        end
                    end
                )
            end
        end
    )
end

return obj
