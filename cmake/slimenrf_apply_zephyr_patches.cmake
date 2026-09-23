# Applies the SlimeNRF Zephyr patch series to the Zephyr tree used by this SDK.
#
# The list below is ordered: every patch applies on top of the previous ones,
# and several patches may touch the same file. The helper resolves that with a
# simulated series so an already or partially applied tree is recognised
# instead of failing the build. See patches/apply_zephyr_patches.py.

set(SLIMENRF_ZEPHYR_BASE "${ZEPHYR_BASE}")
if(NOT SLIMENRF_ZEPHYR_BASE)
  set(SLIMENRF_ZEPHYR_BASE "$ENV{ZEPHYR_BASE}")
endif()

if(NOT SLIMENRF_ZEPHYR_BASE)
  message(FATAL_ERROR "ZEPHYR_BASE is required to apply SlimeNRF Zephyr patches")
endif()

find_package(Python3 3.6 COMPONENTS Interpreter)
if(NOT Python3_EXECUTABLE)
  find_program(Python3_EXECUTABLE NAMES python3 python)
endif()
if(NOT Python3_EXECUTABLE)
  message(FATAL_ERROR "Python 3 is required to apply SlimeNRF Zephyr patches")
endif()

set(SLIMENRF_ZEPHYR_PATCHES
  "${CMAKE_CURRENT_LIST_DIR}/../patches/zephyr/0001-usbd-cdc-acm-reprime-rx-after-stale-busy.patch"
  "${CMAKE_CURRENT_LIST_DIR}/../patches/zephyr/0002-usbd-cdc-acm-bdatainterface-per-instance.patch"
  "${CMAKE_CURRENT_LIST_DIR}/../patches/zephyr/0003-usbd-ctrl-data-in-alloc-cap.patch"
  "${CMAKE_CURRENT_LIST_DIR}/../patches/zephyr/0004-uf2-prefer-hex-output.patch"
  "${CMAKE_CURRENT_LIST_DIR}/../patches/zephyr/0005-led-strip-ws2812-i2s-recover-after-failed-trigger.patch"
  "${CMAKE_CURRENT_LIST_DIR}/../patches/zephyr/0006-led-strip-ws2812-i2s-reject-oversized-updates.patch"
  "${CMAKE_CURRENT_LIST_DIR}/../patches/zephyr/0007-led-strip-ws2812-i2s-serialize-updates.patch"
  "${CMAKE_CURRENT_LIST_DIR}/../patches/zephyr/0008-led-strip-ws2812-i2s-retry-failed-transfer.patch"
  "${CMAKE_CURRENT_LIST_DIR}/../patches/zephyr/0009-led-strip-ws2812-i2s-wait-for-previous-frame.patch"
  "${CMAKE_CURRENT_LIST_DIR}/../patches/zephyr/0010-led-strip-ws2812-spi-reject-oversized-updates.patch"
  "${CMAKE_CURRENT_LIST_DIR}/../patches/zephyr/0011-led-strip-ws2812-spi-serialize-updates.patch"
  "${CMAKE_CURRENT_LIST_DIR}/../patches/zephyr/0012-led-strip-ws2812-i2s-bound-the-tx-waits.patch"
  "${CMAKE_CURRENT_LIST_DIR}/../patches/zephyr/0013-led-strip-ws2812-i2s-pad-frames-to-a-minimum.patch"
  "${CMAKE_CURRENT_LIST_DIR}/../patches/zephyr/0014-led-strip-ws2812-i2s-drain-without-preemption.patch"
  "${CMAKE_CURRENT_LIST_DIR}/../patches/zephyr/0015-led-strip-ws2812-i2s-reset-the-latch-before-the-first-bit.patch"
)

set(slimenrf_patch_args)
foreach(patch_file IN LISTS SLIMENRF_ZEPHYR_PATCHES)
  if(NOT EXISTS "${patch_file}")
    message(FATAL_ERROR "Missing Zephyr patch: ${patch_file}")
  endif()
  list(APPEND slimenrf_patch_args --patch "${patch_file}")
endforeach()

execute_process(
  COMMAND "${Python3_EXECUTABLE}"
          "${CMAKE_CURRENT_LIST_DIR}/../patches/apply_zephyr_patches.py"
          --zephyr-base "${SLIMENRF_ZEPHYR_BASE}"
          ${slimenrf_patch_args}
  RESULT_VARIABLE slimenrf_patch_result
  OUTPUT_VARIABLE slimenrf_patch_output
  ERROR_VARIABLE slimenrf_patch_error
)

if(NOT slimenrf_patch_result EQUAL 0)
  message(FATAL_ERROR
    "Failed to apply SlimeNRF Zephyr patches\n"
    "${slimenrf_patch_output}${slimenrf_patch_error}"
  )
endif()

string(REPLACE "\n" "\n-- " slimenrf_patch_output "${slimenrf_patch_output}")
message(STATUS "${slimenrf_patch_output}")
