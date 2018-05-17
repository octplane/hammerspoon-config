(let [
        ;; spoons
        boo (hs.console.clearConsole)
        fadelogo (hs.loadSpoon "Fadelogo")
        clock (hs.loadSpoon "MultiCountryMenubarClock")
        speedmenu (hs.loadSpoon "SpeedMenu")
        mirowm (hs.loadSpoon "MiroWindowsManager")
        emojis (hs.loadSpoon "Emojis")
        ;; hsearch (hs.loadSpoon "HSearch")
        
        bretzel (require "bretzel")
        
        ;;consts
        console hs.console
        hk hs.hotkey

        ;; my configuration
        mashift [:cmd, :alt, :ctrl :shift]

        ;; functions
        show_temporary_notification (fn [subtitle infoText]
        (let [
            notification (hs.notify.new nil, {
            :title :Hammerspoon
            :subTitle subtitle
            :informativeText infoText
            :autoWithdraw true
            :hasActionButton false})
            fire_notif ((. notification :send) notification)
            withdraw (fn [] ((. notification :withdraw) notification))
            timer (hs.timer.delayed.new 5 withdraw)
        ]
            ((. timer :start) timer)
        ))

        ;; key bindings
        bindings {
        [mashift :R] (fn [] 
            (console.clearConsole)
            (print "Reloading")
            (hs.reload)
            )
        [mashift "/"] (fn [] (hs.toggleConsole))
        [mashift :E] (fn []
            (hs.applescript "tell application \"Finder\" to eject (every disk whose ejectable is true)")
            (hs.notify.show "Hammerspoon" "" "Ejected all disks" "")
            )
        ;; [mashift "space"] (fn [] (hsearch.toggleShow))
        }

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
        ((. fadelogo :start) fadelogo)
        ;; Bind keys
        (each [key fun (pairs bindings)]
        (hk.bind
            (. key 1)
            (. key 2)
            fun)
        )

        (each [kind settings (pairs bretzelConfig)]
            (bretzel.boot
                (. settings :path)
                (. settings :tagsAndAge)
                (. settings :archiveAge)
                (. settings :sortRoot)
            )
        )
        ;; Configure Miro WM
        (mirowm.bindHotkeys mirowm {
            :up [mashift :up]
            :right [mashift :right]
            :down [mashift :down]
            :left [mashift :left]
            :fullscreen [mashift :f]
        })
        (emojis.bindHotkeys
            emojis
            {:toggle  [mashift, :e]})

        ;; all set!
        (show_temporary_notification "Configuration", "Successfully loaded!")

)
