#include "bridge.h"

#include <Cesium3DTilesSelection/Tileset.h>
#include <Cesium3DTilesSelection/TilesetExternals.h>
#include <Cesium3DTilesSelection/ViewState.h>
#include <Cesium3DTilesSelection/ViewUpdateResult.h>
#include <Cesium3DTilesSelection/Tile.h>
#include <CesiumGeospatial/Ellipsoid.h>
#include <CesiumGeospatial/Cartographic.h>
#include <CesiumAsync/AsyncSystem.h>
#include <CesiumAsync/IAssetAccessor.h>
#include <CesiumAsync/ITaskProcessor.h>

#include <glm/vec3.hpp>
#include <glm/vec2.hpp>
#include <glm/trigonometric.hpp>

#include <cstring>
#include <memory>
#include <mutex>
#include <string>
#include <unordered_map>
#include <vector>

namespace {

struct BridgeState {
  std::unique_ptr<Cesium3DTilesSelection::Tileset> tileset;
  CesiumAsync::AsyncSystem asyncSystem;
  std::shared_ptr<CesiumAsync::IAssetAccessor> assetAccessor;
  bridge_error_callback_t errorCallback;
  void* errorUserData;
  bridge_camera_changed_callback_t cameraCallback;
  void* cameraUserData;
  std::string lastError;
  std::mutex mutex;
  bool initialized;
};

std::unordered_map<bridge_handle_t, std::unique_ptr<BridgeState>> g_states;
std::mutex g_statesMutex;
bridge_handle_t g_nextHandle = 1;

class NullAssetAccessor : public CesiumAsync::IAssetAccessor {
public:
  CesiumAsync::Future<std::shared_ptr<CesiumAsync::IAssetRequest>> get(
      const CesiumAsync::AsyncSystem&, const std::string&,
      const std::vector<CesiumAsync::IAssetAccessor::THeader>&) override {
    return CesiumAsync::Future<std::shared_ptr<CesiumAsync::IAssetRequest>>::createResolved(nullptr);
  }
  CesiumAsync::Future<std::shared_ptr<CesiumAsync::IAssetRequest>> request(
      const CesiumAsync::AsyncSystem&, const std::string&, const std::string&,
      const std::vector<CesiumAsync::IAssetAccessor::THeader>&, const std::vector<uint8_t>&) override {
    return CesiumAsync::Future<std::shared_ptr<CesiumAsync::IAssetRequest>>::createResolved(nullptr);
  }
  void tick() noexcept override {}
};

class NullTaskProcessor : public CesiumAsync::ITaskProcessor {
public:
  void startTask(std::function<void()> f) override { if (f) f(); }
};

} // namespace

bridge_handle_t bridge_initialize(
    const bridge_tileset_config_t* config,
    bridge_error_callback_t on_error,
    void* user_data) {

  if (!config) {
    return BRIDGE_ERR_INIT;
  }

  std::lock_guard<std::mutex> lock(g_statesMutex);
  bridge_handle_t handle = g_nextHandle++;

  try {
    auto state = std::make_unique<BridgeState>();
    state->asyncSystem = CesiumAsync::AsyncSystem(std::make_shared<NullTaskProcessor>());
    state->assetAccessor = std::make_shared<NullAssetAccessor>();
    state->errorCallback = on_error;
    state->errorUserData = user_data;
    state->cameraCallback = nullptr;
    state->cameraUserData = nullptr;
    state->initialized = false;

    Cesium3DTilesSelection::TilesetExternals externals;
    externals.asyncSystem = state->asyncSystem;
    externals.pAssetAccessor = state->assetAccessor;

    Cesium3DTilesSelection::TilesetOptions options;
    options.maximumSimultaneousTileLoads = config->max_simultaneous_tile_loads > 0
        ? static_cast<uint32_t>(config->max_simultaneous_tile_loads) : 20;

    if (config->tileset_url && strlen(config->tileset_url) > 0) {
      state->tileset = std::make_unique<Cesium3DTilesSelection::Tileset>(externals, config->tileset_url, options);
      state->initialized = true;
    }

    g_states[handle] = std::move(state);
    return handle;

  } catch (const std::exception& e) {
    g_states.erase(handle);
    if (on_error) {
      on_error(BRIDGE_ERR_INIT, e.what(), user_data);
    }
    return BRIDGE_ERR_INIT;
  }
}

void bridge_shutdown(bridge_handle_t handle) {
  std::lock_guard<std::mutex> lock(g_statesMutex);
  g_states.erase(handle);
}

int32_t bridge_is_ready(bridge_handle_t handle) {
  std::lock_guard<std::mutex> lock(g_statesMutex);
  auto it = g_states.find(handle);
  if (it == g_states.end()) return 0;
  return it->second->initialized ? 1 : 0;
}

const char* bridge_get_last_error(bridge_handle_t handle) {
  std::lock_guard<std::mutex> lock(g_statesMutex);
  auto it = g_states.find(handle);
  if (it == g_states.end()) return "Invalid handle";
  return it->second->lastError.c_str();
}

int32_t bridge_update_camera(bridge_handle_t handle, const bridge_camera_t* camera) {
  if (!camera) return BRIDGE_ERR_CAMERA;

  std::lock_guard<std::mutex> lock(g_statesMutex);
  auto it = g_states.find(handle);
  if (it == g_states.end()) return BRIDGE_ERR_CAMERA;

  auto& state = *it->second;
  if (!state.tileset || !state.initialized) return BRIDGE_ERR_NOT_READY;

  try {
    const CesiumGeospatial::Ellipsoid& ellipsoid = state.tileset->getEllipsoid();

    CesiumGeospatial::Cartographic cartographic = CesiumGeospatial::Cartographic::fromDegrees(
        camera->longitude, camera->latitude, camera->altitude);

    glm::dvec3 position = ellipsoid.cartographicToCartesian(cartographic);

    glm::dvec3 direction(0.0, 0.0, -1.0);
    glm::dvec3 up(0.0, 1.0, 0.0);

    glm::dvec2 viewportSize(800.0, 600.0);
    double hFov = glm::radians(60.0);
    double vFov = glm::radians(45.0);

    Cesium3DTilesSelection::ViewState viewState(position, direction, up, viewportSize, hFov, vFov, ellipsoid);

    if (state.cameraCallback) {
      std::optional<CesiumGeospatial::Cartographic> posCarto = viewState.getPositionCartographic();
      if (posCarto) {
        state.cameraCallback(
            glm::degrees(posCarto->latitude),
            glm::degrees(posCarto->longitude),
            posCarto->height,
            camera->pitch,
            camera->heading,
            state.cameraUserData);
      }
    }

    return BRIDGE_OK;

  } catch (const std::exception& e) {
    state.lastError = e.what();
    return BRIDGE_ERR_CAMERA;
  }
}

int32_t bridge_register_camera_callback(
    bridge_handle_t handle,
    bridge_camera_changed_callback_t callback,
    void* user_data) {
  std::lock_guard<std::mutex> lock(g_statesMutex);
  auto it = g_states.find(handle);
  if (it == g_states.end()) return BRIDGE_ERR_CAMERA;

  it->second->cameraCallback = callback;
  it->second->cameraUserData = user_data;
  return BRIDGE_OK;
}

int32_t bridge_get_visible_tile_count(bridge_handle_t handle, int32_t* out_count) {
  if (!out_count) return BRIDGE_ERR_TILE;

  std::lock_guard<std::mutex> lock(g_statesMutex);
  auto it = g_states.find(handle);
  if (it == g_states.end()) return BRIDGE_ERR_TILE;

  auto& state = *it->second;
  if (!state.tileset) {
    *out_count = 0;
    return BRIDGE_OK;
  }

  try {
    auto loaded = state.tileset->loadedTiles();
    int32_t count = 0;
    for (auto it_tile = loaded.begin(); it_tile != loaded.end(); ++it_tile) {
      count++;
    }
    *out_count = count;
    return BRIDGE_OK;
  } catch (const std::exception&) {
    *out_count = 0;
    return BRIDGE_OK;
  }
}

int32_t bridge_get_visible_tile_id(bridge_handle_t handle, int32_t index, char** out_tile_id) {
  if (!out_tile_id) return BRIDGE_ERR_TILE;
  *out_tile_id = nullptr;

  std::lock_guard<std::mutex> lock(g_statesMutex);
  auto it = g_states.find(handle);
  if (it == g_states.end()) return BRIDGE_ERR_TILE;

  auto& state = *it->second;
  if (!state.tileset) return BRIDGE_ERR_TILE;

  try {
    auto loaded = state.tileset->loadedTiles();
    int32_t current = 0;
    for (auto it_tile = loaded.begin(); it_tile != loaded.end(); ++it_tile, ++current) {
      if (current == index) {
        const std::string& tileId = it_tile->getTileID();
        char* copy = static_cast<char*>(malloc(tileId.size() + 1));
        if (!copy) return BRIDGE_ERR_MEMORY;
        std::memcpy(copy, tileId.c_str(), tileId.size() + 1);
        *out_tile_id = copy;
        return BRIDGE_OK;
      }
    }
    return BRIDGE_ERR_TILE;
  } catch (const std::exception&) {
    return BRIDGE_ERR_TILE;
  }
}

int32_t bridge_request_tile_data(
    bridge_handle_t handle,
    const char* tile_id,
    bridge_tile_ready_callback_t callback,
    void* user_data) {
  if (!tile_id || !callback) return BRIDGE_ERR_TILE;
  return BRIDGE_OK;
}

void bridge_free_string(char* str) {
  free(str);
}

int32_t bridge_cartographic_to_ecef(
    double lat_deg,
    double lng_deg,
    double alt_m,
    double* out_x,
    double* out_y,
    double* out_z) {
  if (!out_x || !out_y || !out_z) return BRIDGE_ERR_CAMERA;

  try {
    const CesiumGeospatial::Ellipsoid& ellipsoid = CesiumGeospatial::Ellipsoid::WGS84;
    const CesiumGeospatial::Cartographic carto = CesiumGeospatial::Cartographic::fromDegrees(lng_deg, lat_deg, alt_m);
    const glm::dvec3 ecef = ellipsoid.cartographicToCartesian(carto);

    if (glm::any(glm::isnan(ecef)) || glm::any(glm::isinf(ecef))) {
      return BRIDGE_ERR_CAMERA;
    }

    *out_x = ecef.x;
    *out_y = ecef.y;
    *out_z = ecef.z;
    return BRIDGE_OK;
  } catch (const std::exception&) {
    return BRIDGE_ERR_CAMERA;
  }
}

int32_t bridge_ecef_to_cartographic(
    double x,
    double y,
    double z,
    double* out_lat_deg,
    double* out_lng_deg,
    double* out_alt_m) {
  if (!out_lat_deg || !out_lng_deg || !out_alt_m) return BRIDGE_ERR_CAMERA;

  try {
    const CesiumGeospatial::Ellipsoid& ellipsoid = CesiumGeospatial::Ellipsoid::WGS84;
    std::optional<CesiumGeospatial::Cartographic> carto = ellipsoid.cartesianToCartographic(glm::dvec3(x, y, z));

    if (!carto) {
      return BRIDGE_ERR_CAMERA;
    }

    *out_lat_deg = glm::degrees(carto->latitude);
    *out_lng_deg = glm::degrees(carto->longitude);
    *out_alt_m = carto->height;
    return BRIDGE_OK;
  } catch (const std::exception&) {
    return BRIDGE_ERR_CAMERA;
  }
}
