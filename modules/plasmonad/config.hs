import XMonad
import XMonad.Hooks.ManageDocks
import XMonad.Config.Kde
import XMonad.Util.Run
import XMonad.Util.EZConfig -- This library provides the functions for managing keybindings
import XMonad.Layout.GridVariants
import XMonad.Layout.Tabbed

import XMonad.Hooks.EwmhDesktops (ewmh)
import qualified XMonad.StackSet as W

main = xmonad $ ewmh $ kdeConfig
       { modMask = mod4Mask -- Use Super instead of Alt
       , terminal = "st"
       , manageHook = (className =? "plasmashell" <&&> title =? "Plasma" --> doFloat) <+> manageDocks <+> manageHook kdeConfig
       , layoutHook = avoidStruts (Grid (16/10) ||| simpleTabbed ||| layoutHook kdeConfig)
       , normalBorderColor  = "#808080" -- grey
       , focusedBorderColor = "#00ccff" -- blue
       -- more changes
       }
       `removeKeys`                -- Removed old keybindings
       [ (mod4Mask .|. shiftMask, xK_Return)
       , (mod4Mask, xK_Return)
       , (mod4Mask, xK_m)
       ]
       `additionalKeys`
       [ ((mod4Mask .|. shiftMask, xK_Return), windows W.swapMaster) -- make master
       , ((mod4Mask .|. shiftMask, xK_space), withFocused $ windows . W.sink) -- retiling a floating window
       , ((mod4Mask .|. controlMask, xK_m), windows W.focusMaster)
       , ((mod4Mask, xK_Return), spawn "st") -- open terminal
       , ((mod4Mask, xK_d), spawn "dmenu_run")
       , ((mod4Mask, xK_m), sendMessage $ JumpToLayout "Full")
       , ((mod4Mask, xK_g), sendMessage $ JumpToLayout "Grid")
       , ((mod4Mask, xK_t), sendMessage $ JumpToLayout "Tabbed Simplest")
       ]
