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
obj.currentImage = nil

function obj:init()
    self.logger.i("Spoon loaded!")
end

function obj:start(secret, base_folder)
    self.logger.d("Starting timer...")
    self.clientID = secret
    self.keyword = "ocean"
    self.baseFolder = base_folder
    self.favoriteFolder = base_folder .. "/favorites/" .. self.keyword .. "/"
    hs.fs.mkdir(self.baseFolder)
    hs.fs.mkdir(self.favoriteFolder)
    self:fetchNewWallpaper()
    rwp_timer =
        hs.timer.new(
        600,
        function()
            self:fetchNewWallpaper()
        end
    ):start()
    self:bindUrl()
end

function obj:updateWallpaperFromData(data)
    local ix = math.floor(math.random() * 10)
    local fname = self.baseFolder .. "/" .. ix .. ".png"
    self.logger.i("Setting wallpaper to " .. fname)
    local f = io.open(fname, "w")
    self.currentImage = fname
    f:write(data)
    f:close()
    -- self:preview()

    hs.fnutils.each(
        hs.screen.allScreens(),
        function(screen)
            screen:desktopImageURL("file://" .. fname)
        end
    )
end

function obj:fetchNewWallpaper()
    self.logger.i("Loading a new Wallpaper...")
    hs.http.asyncGet(
        "https://api.unsplash.com/photos/random?query=" .. self.keyword .. "&orientation=landscape",
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
            else
              self.logger.e("Unable to fetch images:" .. code)
            end
        end
    )
end

local function show_notification(subtitle, infotext, more)
    if not more == nil then
        local notification =
        hs.notify.new(
        more.cb,
        {
          title = "Unsplash Spoon",
          subtitle = subtitle,
          informativeText = infotext,
          autoWithdraw = true,
          hasActionButton = true,
          actionButtonTitle = more.title,
          withdrawAfter = 5
        }
        ):send()
    else
        local notification =
                hs.notify.new(
                {
                  title = "Unsplash Spoon",
                  subtitle = subtitle,
                  informativeText = infotext,
                  autoWithdraw = true,
                  hasActionButton = true,
                  withdrawAfter = 5
                }
                ):send()
    end
end

function obj:hide()
    self.canvas:hide(2)
    self.canvas = nil
end

function obj:preview()
    local image = hs.image.imageFromPath(self.currentImage)
    local size = hs.geometry.size(200, 200)
    local frame = hs.screen.mainScreen():frame()
    local a = hs.canvas.new({x=10, y = frame.h - size.h - 10, w = size.w, h = size.h })

    a:insertElement({
      type = 'image',
      image = image,
      imageAlpha = 1.0,
      imageScaling = 'scaleProportionally',
    })

    a:insertElement({ type = "rectangle", id = "part1", frame = { x = 0, y = 180, h = 20, w = 200}, fillColor = { black = 1.0 } })

    a:canvasMouseEvents(true, true, true, true)
    a:mouseCallback(function (canvas, msg, id, x, y)
        if msg == "mouseUp" then
            self:hide()
        end
        -- print(msg .. id .. " " .. x .. ", "..  y )
    end)

    fade_in_time = 2
    if not self.canvas == nil then 
        self.canvas:hide()
    end

    self.canvas = a
    self.canvas:show(fade_in_time)
    obj._timer = hs.timer.doAfter(fade_in_time, hs.fnutils.partial(self.hide, self))
end

function obj:bindUrl()
    hs.urlevent.bind("unsplash", function(event, params)
        local action = params["action"]
        if action == "open" then
            hs.open(self.currentImage)
        elseif action == "preview" then
            self:preview()
        elseif action == "favorite" then
            local image = hs.image.imageFromPath(self.currentImage)
            local basename = os.date("!%Y%m%d-%H%M") .. ".png"
            local fname = self.favoriteFolder ..  basename
            self.logger.i("Saving to " .. fname)
            image:saveToFile(fname)
            show_notification("Favorite saved", "Saved to " ..  basename,
                { action="Open",
                    cb= function(notif)
                        hs.open(fname)
                    end
                }
            )
        elseif action == "random_favorite" then
            for file in hs.fs.dir(self.favoriteFolder) do
                if file=="." or file==".." then goto continue end
                print(file)
                ::continue::
           end
        elseif action == "keyword" then
            self.keyword = params["keyword"]
            show_notification("Change keyword", "New keyword is " .. self.keyword)
            self:fetchNewWallpaper()
        elseif action == "next" then
            self:fetchNewWallpaper()
        end
    end)
    return self
end

return obj
