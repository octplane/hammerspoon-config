-- Lock Watcher

local watcher = {}

function watcher:start(locked, unlocked)
	function callback(ev)
		if ev == hs.caffeinate.watcher.screensDidLock then
			locked()
		end
		if ev == hs.caffeinate.watcher.screensDidUnlock then
			unlocked()
		end
	end

	self.w= hs.caffeinate.watcher.new(callback)
	self.w:start()

end



function watcher:stop()
	self.w:stop()

end

return watcher

