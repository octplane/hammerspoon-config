-- === Webview Popouts ===
--
require 'libzen'


function popup(url, icon, shortcut, x ,y ,w ,h)
  local i = {}

  i.hidden = false
  i.url = url

  local rect = hs.geometry.rect(x, y, w, h)
  local ww = hs.webview.newBrowser(rect)
  ww:windowStyle(
    hs.webview.windowMasks['titled'] |
    hs.webview.windowMasks['resizable'] |
    hs.webview.windowMasks['closable'] |
    hs.webview.windowMasks['utility'] |
    hs.webview.windowMasks['HUD']
  )
  ww:userAgent('Mozilla/5.0 (Macintosh; Intel Mac OS X 10_11_1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/52.0.2725.0 Safari/537.36')
  -- ww:userAgent('Mozilla/5.0 (iPad; CPU OS 7_0 like Mac OS X) AppleWebKit/537.51.1 (KHTML, like Gecko) CriOS/30.0.1599.12 Mobile/11A465 Safari/8536.25 (3B92C18B-D9DE-4CB7-A02A-22FD2AF17C8F)')
  ww:allowNewWindows(true)
  ww:url(url)
  ww:level(hs.drawing.windowLevels.normal)

  local mash = {"cmd", "alt", "ctrl"}

  i.ww = ww

  function i:webViewClickHandler()
  print(self.url)
    if self.hidden then
      self.ww:show(.2)
      self.ww:level(hs.drawing.windowLevels.normal)
    else
      self.ww:hide(.2)
    end
    self.hidden = not self.hidden
  end

  hs.hotkey.bind(mash, shortcut, function()
    i:webViewClickHandler()
  end)

  local wch = function()
    i:webViewClickHandler()
  end


  local popoutMenuIcon = hs.menubar.new()
    :setIcon(getIcon(icon, 16))
    :setClickCallback(wch)

  end


return popup