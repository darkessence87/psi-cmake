file(GLOB_RECURSE PSI_TEST_SOURCES
     CONFIGURE_DEPENDS
     ${CMAKE_CURRENT_SOURCE_DIR}/psi/tests/*.cpp)

set(GENERATED ${CMAKE_BINARY_DIR}/psi_tests_generated.cpp)

add_custom_command(
    OUTPUT ${GENERATED}
    COMMAND ${CMAKE_COMMAND}
        -DINPUTS="${PSI_TEST_SOURCES}"
        -DOUTPUT=${GENERATED}
        -P ${CMAKE_SOURCE_DIR}/3rdparty/psi-cmake/generate_tests.cmake
    DEPENDS
        ${PSI_TEST_SOURCES}
        ${CMAKE_SOURCE_DIR}/3rdparty/psi-cmake/generate_tests.cmake
)

add_library(psi-test-registry OBJECT ${GENERATED})
psi_config_target(psi-test-registry)
target_link_libraries(psi-test-registry "psi-test")
