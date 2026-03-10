#include <hyprland/src/plugins/PluginAPI.hpp>

#include "bspLayout.hpp"

inline HANDLE PHANDLE = nullptr;

// Do NOT change this function.
APICALL EXPORT std::string PLUGIN_API_VERSION() {
	return HYPRLAND_API_VERSION;
}

APICALL EXPORT PLUGIN_DESCRIPTION_INFO PLUGIN_INIT(HANDLE handle) {
	PHANDLE = handle;

	const std::string HASH = __hyprland_api_get_hash();

	if (HASH != __hyprland_api_get_client_hash()) {
		HyprlandAPI::addNotification(PHANDLE, "[hyprland-bsp-layout] Failure in initialization: Version mismatch (headers ver is not equal to running hyprland ver)",
									 CHyprColor{1.0, 0.2, 0.2, 1.0}, 5000);
		throw std::runtime_error("[bsp] Version mismatch");
	}

	// Register the BSP tiled algorithm via factory
	HyprlandAPI::addTiledAlgo(PHANDLE, "bsp", &typeid(CBSPAlgorithm), []() -> UP<Layout::ITiledAlgorithm> {
		return makeUnique<CBSPAlgorithm>();
	});

	HyprlandAPI::addNotification(PHANDLE, "[hyprland-bsp-layout] Initialized successfully!",
								 CHyprColor{0.2, 1.0, 0.2, 1.0}, 5000);

	return {"hyprland-bsp-layout", "BSP layout plugin", "illustris", "1.0"};
}

APICALL EXPORT void PLUGIN_EXIT() {
	HyprlandAPI::removeAlgo(PHANDLE, "bsp");
}
