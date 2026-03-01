if (NOT DEFINED PSI_CMAKE_DIR)
    message(FATAL_ERROR "PSI_CMAKE_DIR is not set")
endif()

set (ENABLE_ASAN_UBSAN TRUE)
set (3rdPARTY_DIR "${CMAKE_CURRENT_SOURCE_DIR}/3rdparty")

include (${PSI_CMAKE_DIR}/compiler.cmake)
include (${CMAKE_CURRENT_SOURCE_DIR}/dependencies.cmake)

add_subdirectory (${CMAKE_CURRENT_SOURCE_DIR}/psi)
