#include "modules/hyprland/desktop_tabs.hpp"

#include <algorithm>
#include <cstdlib>
#include <fstream>
#include <sstream>
#include "modules/hyprland/backend.hpp"

namespace waybar::modules::hyprland {

DesktopTabs::DesktopTabs(const std::string& id, const Bar& bar, const Json::Value& config)
    : AModule(config, "desktop-tabs", id), bar_(bar) {
  const char* runtime = std::getenv("XDG_RUNTIME_DIR");
  const char* signature = std::getenv("HYPRLAND_INSTANCE_SIGNATURE");
  std::string session = signature ? signature : "verify";
  for (char& c : session) {
    if (!((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') ||
          (c >= '0' && c <= '9') || c == '_' || c == '-')) c = '_';
  }
  path_ = std::string(runtime ? runtime : "/tmp") + "/hypr-desktop-" + session + ".state";
  event_box_.set_name("desktop-tabs");
  event_box_.add(viewport_);
  viewport_.set_policy(Gtk::POLICY_EXTERNAL, Gtk::POLICY_NEVER);
  viewport_.set_shadow_type(Gtk::SHADOW_NONE);
  viewport_.add(tabs_);
  // Scroll at readable natural tab widths instead of compressing every title
  // down to its ellipsis before allowing overflow.
  dynamic_cast<Gtk::Viewport*>(viewport_.get_child())->set_hscroll_policy(Gtk::SCROLL_NATURAL);
  viewport_.get_hadjustment()->signal_changed().connect([this] { revealSelected(); });
  viewport_.add_events(Gdk::SCROLL_MASK | Gdk::SMOOTH_SCROLL_MASK);
  viewport_.signal_scroll_event().connect([this](GdkEventScroll* event) {
    double delta = 0;
    if (event->direction == GDK_SCROLL_SMOOTH) delta = event->delta_x + event->delta_y;
    else if (event->direction == GDK_SCROLL_UP || event->direction == GDK_SCROLL_LEFT) delta = -1;
    else delta = 1;
    auto adjustment = viewport_.get_hadjustment();
    adjustment->set_value(adjustment->get_value() + delta * 100);
    return true;
  }, false);
  viewport_.signal_size_allocate().connect([this](Gtk::Allocation&) {
    reveal_ = true;
    revealSelected();
  });
  // Monitor the directory because the Lua controller replaces the file atomically.
  monitor_ = Gio::File::create_for_path(runtime ? runtime : "/tmp")->monitor_directory();
  monitor_connection_ = monitor_->signal_changed().connect(
      [this](const Glib::RefPtr<Gio::File>& file, const Glib::RefPtr<Gio::File>& other,
             Gio::FileMonitorEvent) {
        if ((file && file->get_path() == path_) || (other && other->get_path() == path_)) dp.emit();
      });
  dp.emit();
}

DesktopTabs::~DesktopTabs() {
  monitor_connection_.disconnect();
  monitor_->cancel();
}

void DesktopTabs::revealSelected() {
  if (!reveal_ || !selected_) return;
  auto adjustment = viewport_.get_hadjustment();
  const auto allocation = selected_->get_allocation();
  if (allocation.get_width() <= 1 || adjustment->get_page_size() <= 1) return;
  const auto right = allocation.get_x() + allocation.get_width();
  if (adjustment->get_upper() < right) return; // wait for the viewport's final allocation
  adjustment->clamp_page(allocation.get_x(), right);
  reveal_ = false;
}

void DesktopTabs::update() {
  std::ifstream file(path_);
  std::string line, snapshot;
  const std::string prefix = "tab " + bar_.output->name + " ";
  while (std::getline(file, line)) {
    if (line.compare(0, prefix.size(), prefix) == 0) snapshot += line.substr(prefix.size()) + '\n';
  }
  if (snapshot == snapshot_) return;
  snapshot_ = snapshot;
  selected_ = nullptr;
  for (auto* child : tabs_.get_children()) delete child;
  std::istringstream records(snapshot);
  while (std::getline(records, line)) {
    std::istringstream record(line);
    std::string id, encoded;
    int selected;
    if (!(record >> id >> selected >> encoded) ||
        id.find_first_not_of("0123456789") != std::string::npos || encoded.size() % 2 ||
        encoded.find_first_not_of("0123456789abcdef") != std::string::npos) continue;
    std::string title;
    for (size_t i = 0; i < encoded.size(); i += 2)
      title += static_cast<char>(std::stoi(encoded.substr(i, 2), nullptr, 16));
    if (!g_utf8_validate(title.c_str(), title.size(), nullptr)) continue;
    auto* button = Gtk::manage(new Gtk::Button());
    auto* label = Gtk::manage(new Gtk::Label(title));
    label->set_ellipsize(Pango::ELLIPSIZE_END);
    label->set_max_width_chars(28);
    label->set_single_line_mode(true);
    button->add(*label);
    button->set_tooltip_text(title);
    button->set_focus_on_click(false);
    button->signal_clicked().connect([id] {
      IPC::inst().getSocket1Reply("eval desktop.focus_id(\"" + id + "\")");
    });
    tabs_.pack_start(*button, false, false);
    if (selected) {
      button->get_style_context()->add_class("active");
      selected_ = button;
    }
    button->signal_size_allocate().connect([this](Gtk::Allocation&) { revealSelected(); });
  }
  reveal_ = true;
  event_box_.show_all();
  // Keep the zero-width expandable center present even without tabs.
  AModule::update();
}

}  // namespace waybar::modules::hyprland
