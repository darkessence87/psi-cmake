set (ENABLE_ASAN_UBSAN TRUE)
set (3rdPARTY_DIR "${CMAKE_CURRENT_SOURCE_DIR}/3rdparty")

include (${3rdPARTY_DIR}/psi-cmake/compiler.cmake)
include (${CMAKE_CURRENT_SOURCE_DIR}/dependencies.cmake)

add_subdirectory (${CMAKE_CURRENT_SOURCE_DIR}/psi)
