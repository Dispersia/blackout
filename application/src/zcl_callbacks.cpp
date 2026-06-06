#include <app-common/zap-generated/attributes/Accessors.h>
#include <app-common/zap-generated/callback.h>
#include <app-common/zap-generated/ids/Attributes.h>
#include <app-common/zap-generated/ids/Clusters.h>
#include <app/ConcreteAttributePath.h>
#include <app/clusters/window-covering-server/window-covering-delegate.h>
#include <app/clusters/window-covering-server/window-covering-server.h>

#include <zephyr/logging/log.h>

LOG_MODULE_DECLARE(app, CONFIG_CHIP_APP_LOG_LEVEL);

using namespace ::chip;
using namespace ::chip::app::Clusters;
using namespace ::chip::app::Clusters::WindowCovering;

namespace {
constexpr EndpointId kWindowCoveringEndpointId = 1;

class BlackoutDelegate : public Delegate {
public:
  CHIP_ERROR HandleMovement(WindowCoveringType type) override {
    switch (type) {
    case WindowCoveringType::Lift:
      LOG_INF("Window covering move: lift");
      break;
    case WindowCoveringType::Tilt:
      LOG_INF("Window covering move: tilt");
      break;
    default:
      break;
    }
    return CHIP_NO_ERROR;
  }

  CHIP_ERROR HandleStopMotion() override {
    LOG_INF("Window covering stop");
    return CHIP_NO_ERROR;
  }
};

BlackoutDelegate sDelegate;
} // namespace

void MatterPostAttributeChangeCallback(
    const app::ConcreteAttributePath &attributePath, uint8_t type,
    uint16_t size, uint8_t *value) {
  switch (attributePath.mClusterId) {
  case Identify::Id:
    break;
  case WindowCovering::Id:
    LOG_DBG("Window covering attribute " ChipLogFormatMEI " changed",
            ChipLogValueMEI(attributePath.mAttributeId));
    break;
  default:
    break;
  }
}

void MatterWindowCoveringClusterServerAttributeChangedCallback(
    const app::ConcreteAttributePath &attributePath) {
  if (attributePath.mEndpointId == kWindowCoveringEndpointId) {
    PostAttributeChange(attributePath.mEndpointId, attributePath.mAttributeId);
  }
}

void emberAfWindowCoveringClusterInitCallback(EndpointId endpoint) {
  if (endpoint == kWindowCoveringEndpointId) {
    SetDefaultDelegate(endpoint, &sDelegate);
    LOG_INF("Window covering cluster initialized on endpoint %u", endpoint);
  }
}
