directory="${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
mkdir -p "$directory"
file="$directory/$(date +%Y-%m-%d_%H-%M-%S_%N).png"
case "${1:-monitor}" in
  region)
    geometry=$(slurp) || exit 0
    [ -n "$geometry" ] || exit 0
    grim -g "$geometry" "$file" ;;
  monitor)
    output=$(hyprctl -j monitors | jq -r '.[] | select(.focused) | .name')
    grim -o "$output" "$file" ;;
  all) grim "$file" ;;
  *) echo 'Usage: desktop-screenshot {monitor|all|region}' >&2; exit 2 ;;
esac
wl-copy --type image/png < "$file"
notify-send -i "$file" 'Screenshot saved and copied' "$file"
