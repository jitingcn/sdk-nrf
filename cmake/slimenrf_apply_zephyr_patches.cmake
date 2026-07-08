find_package(Git REQUIRED)

set(SLIMENRF_ZEPHYR_BASE "$ENV{ZEPHYR_BASE}")
if(NOT SLIMENRF_ZEPHYR_BASE AND DEFINED ZEPHYR_BASE)
  set(SLIMENRF_ZEPHYR_BASE "${ZEPHYR_BASE}")
endif()

if(NOT SLIMENRF_ZEPHYR_BASE)
  message(FATAL_ERROR "ZEPHYR_BASE is required to apply SlimeNRF Zephyr patches")
endif()

set(SLIMENRF_ZEPHYR_PATCHES
  "${CMAKE_CURRENT_LIST_DIR}/../patches/zephyr/0001-usbd-cdc-acm-reprime-rx-after-stale-busy.patch"
)

foreach(patch_file IN LISTS SLIMENRF_ZEPHYR_PATCHES)
  if(NOT EXISTS "${patch_file}")
    message(FATAL_ERROR "Missing Zephyr patch: ${patch_file}")
  endif()

  execute_process(
    COMMAND ${GIT_EXECUTABLE} -C "${SLIMENRF_ZEPHYR_BASE}" apply --check "${patch_file}"
    RESULT_VARIABLE patch_check_result
    OUTPUT_VARIABLE patch_check_output
    ERROR_VARIABLE patch_check_error
  )

  if(patch_check_result EQUAL 0)
    execute_process(
      COMMAND ${GIT_EXECUTABLE} -C "${SLIMENRF_ZEPHYR_BASE}" apply "${patch_file}"
      RESULT_VARIABLE patch_apply_result
      OUTPUT_VARIABLE patch_apply_output
      ERROR_VARIABLE patch_apply_error
    )

    if(NOT patch_apply_result EQUAL 0)
      message(FATAL_ERROR
        "Failed to apply Zephyr patch ${patch_file}\n"
        "${patch_apply_output}${patch_apply_error}"
      )
    endif()

    message(STATUS "Applied Zephyr patch: ${patch_file}")
  else()
    execute_process(
      COMMAND ${GIT_EXECUTABLE} -C "${SLIMENRF_ZEPHYR_BASE}" apply --reverse --check "${patch_file}"
      RESULT_VARIABLE patch_reverse_check_result
      OUTPUT_VARIABLE patch_reverse_check_output
      ERROR_VARIABLE patch_reverse_check_error
    )

    if(patch_reverse_check_result EQUAL 0)
      message(STATUS "Zephyr patch already applied: ${patch_file}")
    else()
      message(FATAL_ERROR
        "Zephyr patch is neither applicable nor already applied: ${patch_file}\n"
        "apply --check:\n${patch_check_output}${patch_check_error}\n"
        "apply --reverse --check:\n${patch_reverse_check_output}${patch_reverse_check_error}"
      )
    endif()
  endif()
endforeach()
