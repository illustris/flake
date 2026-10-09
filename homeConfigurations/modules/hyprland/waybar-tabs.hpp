#pragma once

#include <giomm/file.h>
#include <giomm/filemonitor.h>
#include "AModule.hpp"
#include "bar.hpp"

namespace waybar::modules::hyprland {

// A tab strip must never contribute to the bar's minimum width. The center
// receives only the space left by the launcher/workspaces and status/tray.
class TabViewport : public Gtk::ScrolledWindow {
 protected:
  void get_preferred_width_vfunc(int& minimum, int& natural) const override {
    minimum = natural = 0;
  }
};

class DesktopTabs : public AModule {
 public:
  DesktopTabs(const std::string& id, const Bar& bar, const Json::Value& config);
  ~DesktopTabs() override;
  void update() override;

 private:
  void revealSelected();
  const Bar& bar_;
  TabViewport viewport_;
  Gtk::Box tabs_{Gtk::ORIENTATION_HORIZONTAL};
  Glib::RefPtr<Gio::FileMonitor> monitor_;
  sigc::connection monitor_connection_;
  std::string path_, snapshot_;
  Gtk::Widget* selected_ = nullptr;
  bool reveal_ = false;
};

}  // namespace waybar::modules::hyprland
