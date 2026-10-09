case "${1:-menu}" in
  grid|monocle|scrolling)
    hyprctl eval "desktop.layout_set(\"$1\")" ;;
  cycle) hyprctl eval 'desktop.layout_cycle()' ;;
@extraCases@
  wake) hyprctl eval 'desktop.wake()' ;;
  sleep) hyprctl eval 'hl.dispatch(hl.dsp.dpms({action="disable"}))' ;;
  status) exec desktop-panel --once ;;
  help)
    hyprctl -j binds | jq -r 'map(select(.description != "")) | .[] |
      ([if (.modmask % 128 >= 64) then "Super" else empty end,
        if (.modmask % 8 >= 4) then "Ctrl" else empty end,
        if (.modmask % 16 >= 8) then "Alt" else empty end,
        if (.modmask % 2 == 1) then "Shift" else empty end,
        .key] | join("+")) + "  -  " + .description' |
      wofi --dmenu --prompt 'Shortcuts' --width 750 --height 650 >/dev/null ;;
  menu)
    choice=$(printf '%s\n' @menuEntries@ |
      wofi --dmenu --prompt 'Desktop') || exit 0
    case "$choice" in
      Grid) desktopctl grid ;; Monocle) desktopctl monocle ;; Scroll) desktopctl scrolling ;;
@menuCases@
      Lock) uwsm app -- hyprlock ;; Suspend) systemctl suspend ;;
      'Log out') uwsm stop ;;
    esac ;;
  *) echo 'Usage: desktopctl {grid|monocle|scrolling|cycle|wake|sleep|status|help|menu}' >&2; exit 2 ;;
esac
