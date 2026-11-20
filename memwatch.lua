-- memwatch.lua — find out what this configuration is leaking, and where.
--
-- Why RSS watching alone does not work here. Every Hammerspoon object is a Lua
-- userdatum wrapping an Objective-C object. Lua schedules its GC on the Lua
-- heap alone, so a userdatum that costs ~40 bytes in Lua while holding ~18 KB
-- of AppKit memory (an hs.task does: NSTask + 3 NSPipes + 6 NSFileHandles + its
-- KVO graph) can sit uncollected for hours. Lua sees a tiny heap and never
-- feels pressure to run a full collection; the process footprint climbs anyway.
-- On top of that, most of what leaks here gets swapped out, so `ps -o rss=`
-- reads flat while the real footprint triples.
--
-- So this module measures the thing that actually matters: for each object
-- constructor, how many objects are STILL ALIVE after a forced full GC, and
-- which line of config created them. A count that climbs across reports is a
-- leak; one that collapses after gcTest() was only lazy collection.
--
-- Usage from the Hammerspoon console:
--   memwatch = require("memwatch")
--   memwatch.report()   -- forced GC, then a live-object census by call site
--   memwatch.gcTest()   -- footprint before/after a full GC: leak vs. lazy GC
--   memwatch.start()    -- append a census to ~/.hammerspoon/memwatch.log every 60s
--   memwatch.stop()
--
-- Require it FIRST in init.lua, before anything else builds objects, or it will
-- only see what is constructed after it loads.

local M = {}

local LOG_PATH = os.getenv("HOME") .. "/.hammerspoon/memwatch.log"
local SAMPLE_INTERVAL = 60

-- Constructors worth watching: everything in this config that wraps an AppKit
-- object. Ordered roughly by how much native memory one instance costs.
local TARGETS = {
	"hs.task.new",
	"hs.timer.new",
	"hs.timer.doAfter",
	"hs.timer.doEvery",
	"hs.timer.delayed.new",
	"hs.canvas.new",
	"hs.image.imageFromAppBundle",
	"hs.image.imageFromPath",
	"hs.image.imageFromName",
	"hs.drawing.rectangle",
	"hs.drawing.text",
	"hs.chooser.new",
	"hs.menubar.new",
	"hs.webview.new",
	"hs.notify.new",
	"hs.eventtap.new",
	"hs.application.watcher.new",
	"hs.caffeinate.watcher.new",
	"hs.window.filter.new",
	"hs.axuielement.applicationElement",
	"hs.styledtext.new",
}

-- object -> "constructor ← call site". Weak keys, so an entry vanishes the
-- moment the object is collected: what remains after a full GC is what leaked.
local tracked = setmetatable({}, { __mode = "k" })

local created = {} -- call site -> total ever constructed
local originals = {} -- path -> the unwrapped function, for M.uninstall()
local sampler = nil
local lastAlive = {} -- previous census, so reports can show the delta

-- The frame that called the constructor, skipping memwatch's own frames.
local function callSite()
	for level = 3, 10 do
		local info = debug.getinfo(level, "Sl")
		if not info then
			break
		end
		local src = info.short_src or "?"
		if not src:match("memwatch%.lua$") then
			return src:gsub(".*/", "") .. ":" .. (info.currentline or 0)
		end
	end
	return "?"
end

-- "hs.timer.delayed.new" -> the `hs.timer.delayed` table and "new". Indexing is
-- deliberately non-raw: `hs` loads its submodules through __index, and we want
-- that load to happen so there is something to wrap.
local function resolve(path)
	local parts = {}
	for part in path:gmatch("[^.]+") do
		parts[#parts + 1] = part
	end
	local tbl = _G
	for i = 1, #parts - 1 do
		local ok, next_ = pcall(function()
			return tbl[parts[i]]
		end)
		if not ok or type(next_) ~= "table" then
			return nil
		end
		tbl = next_
	end
	return tbl, parts[#parts]
end

local function wrap(path)
	if originals[path] then
		return true
	end
	local tbl, key = resolve(path)
	if not tbl then
		return false
	end
	local orig = tbl[key]
	if type(orig) ~= "function" then
		return false
	end

	local ok = pcall(function()
		tbl[key] = function(...)
			local returned = table.pack(orig(...))
			local obj = returned[1]
			local kind = type(obj)
			if kind == "userdata" or kind == "table" then
				local where = path .. "  ←  " .. callSite()
				created[where] = (created[where] or 0) + 1
				tracked[obj] = where
			end
			return table.unpack(returned, 1, returned.n)
		end
	end)
	if not ok then
		return false
	end

	originals[path] = orig
	return true
end

function M.install()
	local wrapped, skipped = 0, {}
	for _, path in ipairs(TARGETS) do
		if wrap(path) then
			wrapped = wrapped + 1
		else
			skipped[#skipped + 1] = path
		end
	end
	print(("memwatch: instrumented %d constructors"):format(wrapped))
	if #skipped > 0 then
		print("memwatch: could not wrap " .. table.concat(skipped, ", "))
	end
	return M
end

function M.uninstall()
	for path, orig in pairs(originals) do
		local tbl, key = resolve(path)
		if tbl then
			pcall(function()
				tbl[key] = orig
			end)
		end
	end
	originals = {}
end

-- Two full collections: the first runs finalizers, the second reclaims what
-- those finalizers released. Anything still in `tracked` afterwards is held by
-- a live reference somewhere in the config.
local function fullGC()
	collectgarbage("collect")
	collectgarbage("collect")
end

-- Physical footprint, not RSS. This process swaps out most of what it leaks;
-- footprint counts swapped pages, RSS does not. io.popen, not hs.task, so
-- measuring does not add to the thing being measured.
local function footprintMB()
	local out = hs.execute(
		"/usr/bin/vmmap -summary "
			.. hs.processInfo.processID
			.. " 2>/dev/null | awk '/Physical footprint:/{print $3; exit}'"
	)
	return (out or ""):gsub("%s+", "")
end

local function census()
	fullGC()
	local alive = {}
	for _, where in pairs(tracked) do
		alive[where] = (alive[where] or 0) + 1
	end
	return alive
end

M.census = census

function M.report()
	local alive = census()

	local rows = {}
	for where, count in pairs(alive) do
		rows[#rows + 1] = {
			where = where,
			alive = count,
			created = created[where] or count,
			delta = count - (lastAlive[where] or 0),
		}
	end
	table.sort(rows, function(a, b)
		return a.alive > b.alive
	end)

	print(("\nmemwatch — live objects after a full GC   (footprint %s, Lua heap %.0f KB)")
		:format(footprintMB(), collectgarbage("count")))
	print(("%7s %8s %8s   %s"):format("ALIVE", "CREATED", "Δ", "CONSTRUCTOR  ←  CALL SITE"))
	print(("-"):rep(96))
	for _, row in ipairs(rows) do
		print(("%7d %8d %+8d   %s"):format(row.alive, row.created, row.delta, row.where))
	end
	if #rows == 0 then
		print("  (nothing tracked yet — was memwatch required before the rest of init.lua?)")
	end
	print("")

	lastAlive = alive
	return rows
end

-- Is memory held by a live reference, or is Lua just not collecting? Compare
-- the footprint before and after a forced full GC. A big drop means the objects
-- were garbage all along and Lua had no reason to notice; no drop means
-- something in the config is still holding them.
function M.gcTest()
	local before = footprintMB()
	local beforeLua = collectgarbage("count")
	local held = 0
	for _ in pairs(tracked) do
		held = held + 1
	end

	fullGC()

	local after = footprintMB()
	local stillHeld = 0
	for _ in pairs(tracked) do
		stillHeld = stillHeld + 1
	end

	print(("\nmemwatch gcTest\n  footprint  %s -> %s\n  Lua heap   %.0f KB -> %.0f KB\n  tracked    %d -> %d objects")
		:format(before, after, beforeLua, collectgarbage("count"), held, stillHeld))
	print("  a large footprint drop = lazy GC, not a leak; no drop = something holds a reference\n")
end

-- Periodic sample. `held` is counted before the forced GC and `leaked` after,
-- so one line separates the two failure modes: `held` climbing while `leaked`
-- stays flat is Lua collecting too rarely; both climbing is a real leak.
-- Note that sampling forces a collection, which is itself a change in
-- behaviour — stop() the sampler before measuring the config's natural growth.
local function logLine()
	local rss = hs.execute("ps -o rss= -p " .. hs.processInfo.processID):gsub("%s+", "")

	local held = 0
	for _ in pairs(tracked) do
		held = held + 1
	end

	local alive = census()
	local total = 0
	local top, topCount = "-", 0
	for where, count in pairs(alive) do
		total = total + count
		if count > topCount then
			top, topCount = where, count
		end
	end

	local line = ("%s rss=%sKB lua=%.0fKB held=%d leaked=%d top=%d×%s\n")
		:format(os.date("%Y-%m-%dT%H:%M:%S"), rss, collectgarbage("count"), held, total, topCount, top)

	local f = io.open(LOG_PATH, "a")
	if f then
		f:write(line)
		f:close()
	end
	return line
end

function M.start(interval)
	if sampler then
		return M
	end
	sampler = hs.timer.doEvery(interval or SAMPLE_INTERVAL, logLine)
	logLine()
	print("memwatch: sampling every " .. (interval or SAMPLE_INTERVAL) .. "s to " .. LOG_PATH)
	return M
end

function M.stop()
	if sampler then
		sampler:stop()
		sampler = nil
	end
	return M
end

return M
