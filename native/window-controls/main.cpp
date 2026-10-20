#include <hyprland/src/plugins/PluginAPI.hpp>
#include <hyprland/src/desktop/view/Window.hpp>
#include <hyprland/src/protocols/XDGShell.hpp>
#include <hyprland/src/protocols/core/Compositor.hpp>
#include <hyprland/src/xwayland/XSurface.hpp>
#include <hyprland/src/managers/EventManager.hpp>
#include <format>
#include <stdexcept>
#include <unordered_map>

static std::vector<CHyprSignalListener> lifecycle;
static std::unordered_map<uintptr_t, CHyprSignalListener> requests;

static void track(PHLWINDOW window) {
    const auto id = reinterpret_cast<uintptr_t>(window.get());
    PHLWINDOWREF weak = window;
    if (const auto surface = window->m_xdgSurface.lock(); surface && surface->m_toplevel) {
        const auto top = surface->m_toplevel;
        requests.insert_or_assign(id, top->m_events.stateChanged.listen([weak]() {
            const auto window = weak.lock();
            if (!window || !window->m_isMapped) return;
            const auto surface = window->m_xdgSurface.lock();
            if (surface && surface->m_toplevel->m_state.requestsMinimize.value_or(false))
                g_pEventManager->postEvent({"minimized", std::format("{:x},1", reinterpret_cast<uintptr_t>(window.get()))});
        }));
        if (const auto wlSurface=surface->m_surface.lock()) {
            wl_client_for_each_resource(wlSurface->client(), [](wl_resource* resource,void* target) {
                if (std::string_view(wl_resource_get_class(resource))!="xdg_toplevel" || wl_resource_get_version(resource)<5)
                    return WL_ITERATOR_CONTINUE;
                if (CXDGToplevelResource::fromResource(resource).get()!=target) return WL_ITERATOR_CONTINUE;
            uint32_t capabilities[] = {XDG_TOPLEVEL_WM_CAPABILITIES_FULLSCREEN,
                                       XDG_TOPLEVEL_WM_CAPABILITIES_MAXIMIZE,
                                       XDG_TOPLEVEL_WM_CAPABILITIES_MINIMIZE};
            wl_array array{sizeof(capabilities), sizeof(capabilities), capabilities};
                static_cast<CXdgToplevel*>(wl_resource_get_user_data(resource))->sendWmCapabilities(&array);
                return WL_ITERATOR_STOP;
            },top.get());
            surface->scheduleConfigure();
        }
    } else if (const auto surface = window->m_xwaylandSurface.lock()) {
        requests.insert_or_assign(id, surface->m_events.stateChanged.listen([weak]() {
            const auto window = weak.lock();
            if (!window || !window->m_isMapped) return;
            const auto surface = window->m_xwaylandSurface.lock();
            if (surface && surface->m_state.requestsMinimize.value_or(false))
                g_pEventManager->postEvent({"minimized", std::format("{:x},1", reinterpret_cast<uintptr_t>(window.get()))});
        }));
    }
}

APICALL EXPORT std::string PLUGIN_API_VERSION() { return HYPRLAND_API_VERSION; }

APICALL EXPORT PLUGIN_DESCRIPTION_INFO PLUGIN_INIT(HANDLE) {
    if (std::string_view(__hyprland_api_get_hash()) != __hyprland_api_get_client_hash())
        throw std::runtime_error("Forynarch window controls require a rebuild for this Hyprland version.");
    lifecycle.push_back(Event::bus()->m_events.window.openEarly.listen(track));
    lifecycle.push_back(Event::bus()->m_events.window.close.listen([](PHLWINDOW window) {
        requests.erase(reinterpret_cast<uintptr_t>(window.get()));
    }));
    return {"forynarch-window-controls", "Native minimize requests for Forynarch", "Forynarch", "1.0.0"};
}

APICALL EXPORT void PLUGIN_EXIT() { lifecycle.clear(); requests.clear(); }
