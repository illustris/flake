"""Brief, non-interactive full-title headers for visible Hyprland windows."""
import hashlib
import json
import os
import subprocess


def header_specs(monitors, clients):
    outputs = {m["id"]: m for m in monitors}
    result = []
    for client in clients:
        if (not client.get("mapped") or client.get("hidden")
                or not client.get("visible") or not client.get("acceptsInput")):
            continue
        monitor = outputs.get(client.get("monitor"))
        if not monitor:
            continue
        width, height = monitor["width"], monitor["height"]
        if monitor.get("transform", 0) % 2:
            width, height = height, width
        width, height = round(width / monitor["scale"]), round(height / monitor["scale"])
        x, y = client["at"][0] - monitor["x"], client["at"][1] - monitor["y"]
        left, top = max(0, x), max(0, y)
        right, bottom = min(width, x + client["size"][0]), min(height, y + client["size"][1])
        if right <= left or bottom <= top:
            continue
        result.append({"monitor": monitor, "left": left, "top": top,
                       "right": width - right, "width": right - left,
                       "title": client.get("title") or client.get("class") or "Window"})
    return result


def main():
    # Keep pure geometry/filtering importable without GTK for controller checks.
    import gi
    gi.require_version("Gtk", "3.0")
    gi.require_version("Gdk", "3.0")
    gi.require_version("GtkLayerShell", "0.1")
    from gi.repository import Gdk, GLib, Gtk, GtkLayerShell, Pango
    import cairo

    class Headers(Gtk.Application):
        def __init__(self):
            session = hashlib.sha256(os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", "").encode()).hexdigest()[:16]
            super().__init__(application_id=f"tech.illustris.WindowHeaders.s{session}")
            self.timeout = None

        def clear(self):
            for window in self.get_windows():
                window.destroy()

        def expire(self):
            self.timeout = None
            self.clear()
            return GLib.SOURCE_REMOVE

        def do_activate(self):
            self.hold()
            try:
                if self.timeout is not None:
                    GLib.source_remove(self.timeout)
                    self.timeout = None
                self.clear()
                def query(name):
                    return json.loads(subprocess.check_output(["@hyprctl@", "-j", name], timeout=2))
                specs = header_specs(query("monitors"), query("clients"))
                display = Gdk.Display.get_default()
                monitors = [display.get_monitor(i) for i in range(display.get_n_monitors())]
                for spec in specs:
                    # GDK and Hyprland both expose monitor origins in logical coordinates.
                    output = next((m for m in monitors if
                                   (m.get_geometry().x, m.get_geometry().y) ==
                                   (spec["monitor"]["x"], spec["monitor"]["y"])), None)
                    if output is None:
                        continue
                    window = Gtk.ApplicationWindow(application=self)
                    window.set_name("window-header")
                    window.set_accept_focus(False)
                    GtkLayerShell.init_for_window(window)
                    GtkLayerShell.set_namespace(window, "desktop-window-headers")
                    GtkLayerShell.set_monitor(window, output)
                    GtkLayerShell.set_layer(window, GtkLayerShell.Layer.OVERLAY)
                    GtkLayerShell.set_keyboard_mode(window, GtkLayerShell.KeyboardMode.NONE)
                    # -1 positions against the output edges, ignoring panel exclusive zones.
                    GtkLayerShell.set_exclusive_zone(window, -1)
                    for edge, margin in ((GtkLayerShell.Edge.TOP, spec["top"]),
                                         (GtkLayerShell.Edge.LEFT, spec["left"]),
                                         (GtkLayerShell.Edge.RIGHT, spec["right"])):
                        GtkLayerShell.set_anchor(window, edge, True)
                        GtkLayerShell.set_margin(window, edge, int(margin))
                    label = Gtk.Label(label=spec["title"], xalign=0)
                    label.set_line_wrap(True)
                    label.set_line_wrap_mode(Pango.WrapMode.WORD_CHAR)
                    label.set_ellipsize(Pango.EllipsizeMode.NONE)
                    # Give GTK a real wrapping width before the initial layer
                    # configure, otherwise its height-for-width request is enormous.
                    label.set_size_request(max(1, int(spec["width"]) - 18), -1)
                    label.set_max_width_chars(max(1, int(spec["width"]) // 8))
                    window.add(label)
                    window.connect("realize", lambda w: w.get_window().input_shape_combine_region(cairo.Region(), 0, 0))
                    window.show_all()
                # Repeated Meta+H replaces headers and restarts the complete 3-second interval.
                self.timeout = GLib.timeout_add(3000, self.expire)
            finally:
                self.release()

    app = Headers()
    provider = Gtk.CssProvider()
    provider.load_from_data(b"#window-header { background: #232629; color: #eff0f1; border: 1px solid #00ccff; } #window-header label { padding: 5px 8px; font: 13px 'Noto Sans'; }")
    Gtk.StyleContext.add_provider_for_screen(Gdk.Screen.get_default(), provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)
    app.run([])


if __name__ == "__main__":
    main()
