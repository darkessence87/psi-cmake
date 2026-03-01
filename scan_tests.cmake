if(CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)

    file(GLOB_RECURSE PSI_TEST_SOURCES
         CONFIGURE_DEPENDS
         ${CMAKE_CURRENT_SOURCE_DIR}/psi/tests/*.cpp)

    set(GENERATED ${CMAKE_BINARY_DIR}/psi_tests_generated.cpp)

    if(NOT EXISTS "${PSI_CMAKE_DIR}/generate_tests.cmake")
        message(FATAL_ERROR "generate_tests.cmake not found at ${PSI_CMAKE_DIR}")
    endif()

    add_custom_command(
        OUTPUT ${GENERATED}
        COMMAND ${CMAKE_COMMAND}
            -DINPUTS="${PSI_TEST_SOURCES}"
            -DOUTPUT=${GENERATED}
            -P ${PSI_CMAKE_DIR}/generate_tests.cmake
        DEPENDS
            ${PSI_TEST_SOURCES}
            ${PSI_CMAKE_DIR}/generate_tests.cmake
    )

    add_library(psi-test-registry OBJECT ${GENERATED})
    psi_config_target(psi-test-registry)
    target_link_libraries(psi-test-registry psi-test)

endif()
