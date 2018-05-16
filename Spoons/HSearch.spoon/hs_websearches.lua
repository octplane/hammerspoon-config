local obj = {}

obj.name = "webSearches"

-- Internal function used to find our location, so we know where to load files from
local function script_path()
    local str = debug.getinfo(2, "S").source:sub(2)
    return str:match("(.*/)")
end

obj.spoonPath = script_path()

obj.supported = {
    {
        key = "dd",
        text = "dd:Datadog Wiki search",
        url = "https://github.com/DataDog/devops/search?q={query}&type=Wikis&utf8=%E2%9C%93",
        image = hs.image.imageFromPath(obj.spoonPath .. "/resources/justnote.png")
    },
    {
        key = "pd",
        text = "pd:Prod Datadog",
        url = "https://github.com/DataDog/devops/search?q={query}&type=Wikis&utf8=%E2%9C%93",
        image = hs.image.imageFromPath(obj.spoonPath .. "/resources/justnote.png")
    },
    {
        key = "sd",
        text = "sd:Staging Datadog",
        url = "https://github.com/DataDog/devops/search?q={query}&type=Wikis&utf8=%E2%9C%93",
        image = hs.image.imageFromPath(obj.spoonPath .. "/resources/justnote.png")
    }
}

-- Define the source's overview. A unique `keyword` key should exist, so this source can be found.
obj.overview = {
    text = "w⇥: Web searches",
    image = hs.image.imageFromPath(obj.spoonPath .. "/resources/justnote.png"),
    keyword = "w"
}
-- Define the notice when a long-time request is being executed. It could be `nil`.
obj.notice = nil
-- Define the hotkeys, which will be enabled/disabled automatically. You need to add your keybindings into this table manually.
obj.hotkeys = {}

local function webSearches()
    local f = function()
        print("f is called!")
        return obj.supported
    end
    return f
end
-- Define the function which will be called when the `keyword` triggers a new source. The returned value is a table. Read more: http://www.hammerspoon.org/docs/hs.chooser.html#choices
obj.init_func = webSearches

local action =
    hs.hotkey.new(
    "",
    "return",
    nil,
    function()
        print(hs.inspect(spoon.HSearch.chooser:selectedRowContents()))
    end
)

table.insert(obj.hotkeys, action)

obj.callback = function(querystr)
    local matchstr = string.match(querystr, "^%w+")
    local found = false
    for _, search in pairs(obj.supported) do
        if search.key == matchstr then
            found = true
            local subText = "Type your search query"
            if #querystr > #matchstr + 1 then
                subText = "Search for " .. string.sub(querystr, #matchstr + 2)
            end

            chooser_data = {
                {
                    text = search.text,
                    subText = subText
                }
            }
        end
    end
    if not found then
        chooser_data = obj.supported
    end
    if spoon.HSearch then
        -- Make sure HSearch spoon is running now
        spoon.HSearch.chooser:choices(chooser_data)
        spoon.HSearch.chooser:refreshChoicesCallback()
    end
end

return obj
