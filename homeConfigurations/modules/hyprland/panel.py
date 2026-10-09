import argparse
import ctypes
import json
import os
from pathlib import Path
import re
import select
import struct

IN_CLOSE_WRITE, IN_MOVED_TO, IN_DELETE, IN_Q_OVERFLOW = 0x8, 0x80, 0x200, 0x4000


def status(path, output):
    mode, ratio = "grid", 1.2
    try:
        lines = path.read_text().splitlines()
    except FileNotFoundError:
        lines = []
    for line in lines:
        fields = line.split()
        if len(fields) != 5 or fields[:2] != ["panel", output]:
            continue
        if fields[3] not in ("grid", "monocle", "scrolling"):
            continue
        try:
            candidate = float(fields[4])
        except ValueError:
            continue
        if 0.25 <= candidate <= 4:
            mode, ratio = fields[3], candidate
    labels = {"grid": "Grid", "monocle": "Monocle", "scrolling": "Scroll"}
    text = f"Grid {ratio:.2f}:1" if mode == "grid" else labels[mode]
    return {
        "text": text,
        "class": mode,
        "tooltip": (
            f"Grid target width/height: {ratio:.2f}:1\n"
            "Super+Ctrl+-: taller windows, split into columns sooner\n"
            "Super+Ctrl+=: wider windows, split into columns later\n"
            "Super+Ctrl+Backspace: reset to 1.20:1\n"
            "Click: cycle layouts | Right click: desktop controls"
        ),
    }


def watch(path, output):
    # Watch the directory: the controller replaces the state file atomically.
    libc = ctypes.CDLL(None, use_errno=True)
    libc.inotify_init1.argtypes = [ctypes.c_int]
    libc.inotify_init1.restype = ctypes.c_int
    libc.inotify_add_watch.argtypes = [ctypes.c_int, ctypes.c_char_p, ctypes.c_uint32]
    libc.inotify_add_watch.restype = ctypes.c_int
    fd = libc.inotify_init1(os.O_NONBLOCK | os.O_CLOEXEC)
    if fd < 0:
        raise OSError(ctypes.get_errno(), "inotify_init1")
    try:
        if libc.inotify_add_watch(fd, os.fsencode(path.parent), IN_CLOSE_WRITE | IN_MOVED_TO | IN_DELETE) < 0:
            raise OSError(ctypes.get_errno(), "inotify_add_watch")
        last = None
        changed = True
        header = struct.Struct("iIII")
        while True:
            if changed:
                current = json.dumps(status(path, output))
                if current != last:
                    print(current, flush=True)
                    last = current
            select.select([fd], [], [])
            events = os.read(fd, 65536)
            changed = False
            offset = 0
            while offset < len(events):
                _, mask, _, length = header.unpack_from(events, offset)
                offset += header.size
                name = events[offset : offset + length].split(b"\0", 1)[0]
                changed |= name == os.fsencode(path.name) or bool(mask & IN_Q_OVERFLOW)
                offset += length
    finally:
        os.close(fd)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--once", action="store_true")
    args = parser.parse_args()
    signature = re.sub(r"[^a-zA-Z0-9_-]", "_", os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", "verify"))
    path = Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp")) / f"hypr-desktop-{signature}.state"
    output = os.environ.get("WAYBAR_OUTPUT_NAME") or "*"
    if args.once:
        print(json.dumps(status(path, output)))
    else:
        watch(path, output)


if __name__ == "__main__":
    main()
