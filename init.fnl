(let [
        ;; spoons
        fadelogo (hs.loadSpoon "Fadelogo")
        speedmenu (hs.loadSpoon "SpeedMenu")
        mirowm (hs.loadSpoon "MiroWindowsManager")
        emojis (hs.loadSpoon "Emojis")
        
        bretzel (require "bretzel")
        
        ;;consts
        console hs.console
        hk hs.hotkey

        ;; my configuration
        mash [:cmd, :alt, :ctrl]
        mashift [:cmd, :alt, :ctrl :shift]
        cac [:ctrl :alt :cmd]

        ;; funcions
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
        [mash "/"] (fn [] (hs.toggleConsole))
        [mash :E] (fn []
            (hs.applescript "tell application \"Finder\" to eject (every disk whose ejectable is true)")
            (hs.notify.show "Hammerspoon" "" "Ejected all disks" "")
            )
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
        (console.clearConsole)
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
            :up [cac :up]
            :right [cac :right]
            :down [cac :down]
            :left [cac :left]
            :fullscreen [cac :f]
        })
        (emojis.bindHotkeys
            emojis
            {:toggle  [cac, :e]})

        ;; all set!
        (show_temporary_notification "Configuration", "Successfully loaded!")

)
