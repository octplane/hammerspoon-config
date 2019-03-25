-- This is a bunch of code to use a Philips Hue Motion Sensor as a trigger for doing work

local hueBridge = {}

hueBridge.ip = nil
hueBridge.username = hs.settings.get("hueBridgeUsername") -- This will store the username the Hue bridge gave us
hueBridge.apiURLBase = nil
hueBridge.apiURLUser = nil
hueBridge.authTimer = nil
hueBridge.pollingTimer = nil
hueBridge.pollingBeginTimer = nil
hueBridge.pollingInterval = 2
hueBridge.defaultHeaders = {}
hueBridge.defaultHeaders["Accept"] = "application/json"
hueBridge.isGettingIP = false
hueBridge.isGettingUsername = false
hueBridge.isPolling = false
hueBridge.userCallback = nil

function hueBridge:debug(msg)
  print(string.format("DEBUG: hueMotionSensor: %s", msg))
end

function hueBridge:init()
  self:isReadyForPolling()
  return self
end

function hueBridge:start()
  self.pollingBeginTimer = hs.timer.waitUntil(function() return self:isReadyForPolling() end, function() self:pollingStart() end, 5)
  return self
end

function hueBridge:pollingStart()
  self.pollingTimer = hs.timer.new(2, function() self:doPoll() end)
  self.pollingTimer:start()
  return self
end

function hueBridge:doPoll()
  self:debug("Waking up...")
  if not self.isPolling then
    self.isPolling = true
    self:debug("Polling... " .. self.apiURLUser)
    hs.http.asyncGet(self.apiURLUser, self.defaultHeaders, function(code, body, headers)
                        hs.inspect(code)
                        self.isPolling = false
                        if code == 200 then
                          rawJSON = hs.json.decode(body)
                          hs.inspect(rawJSON)
                        end
    end)
  end
end

function hueBridge:stop()
  print("Stopping hueMotionSensor polling")
  if self.pollingBeginTimer then
    self.pollingBeginTimer:stop()
  end
  if self.authTimer then
    self.authTimer:stop()
  end
  if self.pollingTimer then
    self.pollingTimer:stop()
  end
  return self
end

function hueBridge:updateURLs()
  if (self.ip and not self.apiURLBase) then
    self.apiURLBase = string.format("http://%s/api", self.ip)
  end
  if (self.apiURLBase and self.username and not self.apiURLUser) then
    self.apiURLUser = string.format("%s/%s", self.apiURLBase, self.username)
  end
  return self
end

function hueBridge:isReadyForPolling()
  if not self.ip then
    self:getIP()
    return false
  end
  if not self.username then
    self:getAuth()
    return false
  end
  return true
end

function hueBridge:getIP()
  if self.isGettingIP then
    return self
  end
  self.isGettingIP = true
  hs.http.asyncGet("https://www.meethue.com/api/nupnp", nil, function(code, body, headers)
                     self.isGettingIP = false
                     --        print(string.format("Debug: getIP() callback, %d, %s, %s", code, body, hs.inspect(headers)))
                     -- FIXME: Handle error codes
                     if code == 200 then
                       rawJSON = hs.json.decode(body)[1]
                       self.ip = rawJSON["internalipaddress"]
                       self:updateURLs()
                       self:debug("Bridge discovered at: "..self.ip)
                     end
  end)
  return self
end

function hueBridge:getAuth()
  if self.isGettingUsername then
    return self
  end
  self.isGettingUsername = true
  hs.http.asyncPost(self.apiURLBase, '{"devicetype":"Hammerspoon#hammerspoon hammerspoon"}', self.defaultHeaders, function(code, body, headers)
                      self.isGettingUsername = false
                      --        print(string.format("Debug: getAuth() callback, %d, %s, %s", code, body, hs.inspect(headers)))
                      -- FIXME: Handle error codes
                      if code == 200 then
                        rawJSON = hs.json.decode(body)[1]
                        if rawJSON["error"] and rawJSON["error"]["type"] == 101 then
                          -- FIXME: Don't spam the user, create a notification, track its lifecycle properly
                          hs.notify.show("Hammerspoon", "Hue Bridge authentication", "Please press the button on your Hue bridge")
                          return
                        end
                        if rawJSON["success"] ~= nil then
                          self.username = rawJSON["success"]["username"]
                          hs.settings.set("hueBridgeUsername", self.username)
                          self:updateURLs()
                          self:debug("Created username: "..self.username)
                        end
                      end
  end)
  return self
end
return hueBridge

