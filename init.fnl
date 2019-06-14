(let [
      ;; spoons
      ;; speedmenu (hs.loadSpoon "SpeedMenu")
      ;; hsearch (hs.loadSpoon "HSearch")
      bretzel (require "bretzel")
      ;; my configuration
      mashift [:cmd, :alt, :ctrl :shift]
      bretzelConfig {
      :Desktop {
      :path (.. (os.getenv :HOME) "/Desktop")
      :tagsAndAge {
      :Orange (* 86400 4) 
      :Rouge (* 86400 8)
      }
      :archiveAge (* 86400 12)
      :sortRoot false
      }
      :Downloads {
      :path (.. (os.getenv :HOME) "/Downloads")
      :tagsAndAge {
      :Vert (* 86400) 
      :Orange (* 86400)
      }
      :archiveAge (* 86400 10)
      :sortRoot true
      }
      }
      ]

  (set hs.window.animationDuration 0.3)
  (each [kind settings (pairs bretzelConfig)]
        (bretzel.boot
         (. settings :path)
         (. settings :tagsAndAge)
         (. settings :archiveAge)
         (. settings :sortRoot)
         )
        )


  )
