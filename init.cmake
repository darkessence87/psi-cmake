if(DEFINED PSI_CMAKE_DIR)
    return()
endif()

# init.cmake lives next to project.cmake/main.cmake/compiler.cmake — its
# own directory IS psi-cmake. No need to search anywhere else.
set(PSI_CMAKE_DIR "${CMAKE_CURRENT_LIST_DIR}" CACHE PATH "Resolved psi-cmake root" FORCE)
message(STATUS "PSI_CMAKE_DIR : ${PSI_CMAKE_DIR}")
