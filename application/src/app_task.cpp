#include "app_task.h"

#include "app/matter_init.h"
#include "app/task_executor.h"
#include "board/board.h"
#include "clusters/identify.h"

#include <app/clusters/window-covering-server/window-covering-server.h>

#include <zephyr/logging/log.h>

LOG_MODULE_DECLARE(app, CONFIG_CHIP_APP_LOG_LEVEL);

using namespace ::chip;
using namespace ::chip::app;
using namespace ::chip::DeviceLayer;

namespace {
constexpr chip::EndpointId kWindowCoveringEndpointId = 1;

Nrf::Matter::IdentifyCluster sIdentifyCluster(kWindowCoveringEndpointId);

#ifdef CONFIG_CHIP_ICD_UAT_SUPPORT
#ifdef CONFIG_NCS_SAMPLE_MATTER_USE_DEFAULT_BUTTON_HANDLER
#define UAT_BUTTON_MASK DK_BTN3_MSK
#endif
#endif

#ifndef CONFIG_NCS_SAMPLE_MATTER_USE_DEFAULT_BUTTON_HANDLER
constexpr int kSoftwareUpdateTimeout = 1500;
constexpr int kUatTimeout = 1500;
constexpr int kFactoryResetTimeout = 3000;
constexpr int kUatBlinkPeriod = 200;
ButtonState sBtnState = ButtonState::None;
k_timer sBtn1Timer;
#endif

} /* namespace */

void HandleUAT() {
#ifdef CONFIG_CHIP_ICD_UAT_SUPPORT
  LOG_INF("ICD UserActiveMode has been triggered.");
  Server::GetInstance().GetICDManager().OnNetworkActivity();
#endif
}

void AppTask::ButtonEventHandler(Nrf::ButtonState state,
                                 Nrf::ButtonMask hasChanged) {
#ifdef CONFIG_NCS_SAMPLE_MATTER_USE_DEFAULT_BUTTON_HANDLER
  if (UAT_BUTTON_MASK & state & hasChanged) {
    HandleUAT();
  }
#else
  if (DK_BTN1_MSK & hasChanged) {
    if (DK_BTN1_MSK & state) {
      LOG_INF("Release the button within %ums to trigger Software Update",
              kSoftwareUpdateTimeout);
      k_timer_start(&sBtn1Timer, K_MSEC(kSoftwareUpdateTimeout), K_NO_WAIT);
      sBtnState = ButtonState::SoftwareUpdate;
    } else {
      if (sBtnState == ButtonState::SoftwareUpdate) {
#ifndef CONFIG_NCS_SAMPLE_MATTER_CUSTOM_BLUETOOTH_ADVERTISING
        if (Nrf::GetBoard().GetDeviceState() ==
            Nrf::DeviceState::DeviceProvisioned) {
#ifdef CONFIG_MCUMGR_TRANSPORT_BT
          GetDFUOverSMP().StartServer();
#else
          LOG_INF("Software update is disabled");
#endif
        } else {
          Nrf::GetBoard().StartBLEAdvertisement();
        }
#endif
      } else if (sBtnState == ButtonState::UAT) {
        HandleUAT();
      }
      k_timer_stop(&sBtn1Timer);
      sBtnState = ButtonState::None;
      Nrf::GetBoard().RestoreAllLedsState();
      Nrf::GetBoard().RunLedStateHandler();
    }
  }
#endif
}

#ifndef CONFIG_NCS_SAMPLE_MATTER_USE_DEFAULT_BUTTON_HANDLER
void ButtonTimerEventHandler() {
  if (sBtnState == ButtonState::SoftwareUpdate) {
    LOG_INF("Release the button within %ums to trigger UAT", kUatTimeout);
    k_timer_start(&sBtn1Timer, K_MSEC(kUatTimeout), K_NO_WAIT);
    sBtnState = ButtonState::UAT;

    Nrf::GetBoard().ResetAllLeds();
    Nrf::GetBoard().ForEachLED(
        [](Nrf::LEDWidget &led) { led.Blink(kUatBlinkPeriod); });
  } else if (sBtnState == ButtonState::UAT) {
    LOG_INF("Factory reset has been triggered. Release button within %ums to "
            "cancel.",
            kFactoryResetTimeout);

    k_timer_start(&sBtn1Timer, K_MSEC(kFactoryResetTimeout), K_NO_WAIT);
    sBtnState = ButtonState::None;

    Nrf::GetBoard().ForEachLED(
        [](Nrf::LEDWidget &led) { led.Blink(Nrf::LedConsts::kBlinkRate_ms); });
  } else if (sBtnState == ButtonState::None) {
    chip::Server::GetInstance().ScheduleFactoryReset();
  }
}

void ButtonTimerTimeoutCallback(k_timer *timer) {
  Nrf::PostTask([] { ButtonTimerEventHandler(); });
}

#endif

CHIP_ERROR AppTask::Init() {
  ReturnErrorOnFailure(Nrf::Matter::PrepareServer());

  if (!Nrf::GetBoard().Init(ButtonEventHandler)) {
    LOG_ERR("User interface initialization failed.");
    return CHIP_ERROR_INCORRECT_STATE;
  }

  ReturnErrorOnFailure(Nrf::Matter::RegisterEventHandler(
      Nrf::Board::DefaultMatterEventHandler, 0));

  ReturnErrorOnFailure(sIdentifyCluster.Init());

  return Nrf::Matter::StartServer();
}

CHIP_ERROR AppTask::StartApp() {
  ReturnErrorOnFailure(Init());

#ifndef CONFIG_NCS_SAMPLE_MATTER_USE_DEFAULT_BUTTON_HANDLER
  k_timer_init(&sBtn1Timer, &ButtonTimerTimeoutCallback, nullptr);
#endif

  while (true) {
    Nrf::DispatchNextTask();
  }

  return CHIP_NO_ERROR;
}
