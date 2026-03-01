if(DEFINED PSI_CMAKE_DIR)
    return()
endif()

set(PSI_CMAKE_NAME psi-cmake)
set(PSI_CMAKE_3RDPARTY_DIR
    "${CMAKE_CURRENT_SOURCE_DIR}/3rdparty/${PSI_CMAKE_NAME}"
)
set(PSI_CMAKE_BROTHER_DIR
    "${CMAKE_TOP_LEVEL_SOURCE_DIR}/../${PSI_CMAKE_NAME}"
)
if(EXISTS "${PSI_CMAKE_BROTHER_DIR}/project.cmake")
    message(STATUS "Using sibling ${PSI_CMAKE_NAME}: ${PSI_CMAKE_BROTHER_DIR}")
    set(PSI_CMAKE_DIR "${PSI_CMAKE_BROTHER_DIR}")
else()
    message(STATUS "Using 3rdparty ${PSI_CMAKE_NAME}: ${PSI_CMAKE_3RDPARTY_DIR}")
    set(PSI_CMAKE_DIR "${PSI_CMAKE_3RDPARTY_DIR}")
endif()
set(PSI_CMAKE_DIR "${PSI_CMAKE_DIR}" CACHE PATH "Resolved psi-cmake root" FORCE)
message("PSI_CMAKE_DIR : ${PSI_CMAKE_DIR}")
