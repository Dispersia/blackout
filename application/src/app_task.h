#pragma once

#include "board/board.h"

#include <platform/CHIPDeviceLayer.h>

struct Identify;

#ifndef CONFIG_NCS_SAMPLE_MATTER_USE_DEFAULT_BUTTON_HANDLER
enum class ButtonState { None, SoftwareUpdate, UAT };
#endif

class AppTask {
public:
  static AppTask &Instance() {
    static AppTask sAppTask;
    return sAppTask;
  };

  CHIP_ERROR StartApp();

private:
  CHIP_ERROR Init();

  static void ButtonEventHandler(Nrf::ButtonState state,
                                 Nrf::ButtonMask hasChanged);
};
