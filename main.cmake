if (NOT DEFINED PSI_CMAKE_DIR)
    message(FATAL_ERROR "PSI_CMAKE_DIR is not set")
endif()

# ENABLE_ASAN_UBSAN is a per-preset / per-configure cache option. Default
# to OFF when the caller has not made a choice; presets / commandline
# -DENABLE_ASAN_UBSAN=ON take precedence.
option(ENABLE_ASAN_UBSAN "Enable AddressSanitizer + UndefinedBehaviorSanitizer" OFF)

include (${PSI_CMAKE_DIR}/compiler.cmake)

# dependencies.cmake is no longer required: modules declare their deps via
# psi_link() inside psi/CMakeLists.txt, which lazily brings in sibling
# psi-<name> subprojects. Kept as an optional include for backward compat.
if (EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/dependencies.cmake")
    include (${CMAKE_CURRENT_SOURCE_DIR}/dependencies.cmake)
endif()

add_subdirectory (${CMAKE_CURRENT_SOURCE_DIR}/psi)
