# project name
message("Working dir: ${CMAKE_CURRENT_SOURCE_DIR}")
get_filename_component(projectName ${CMAKE_CURRENT_SOURCE_DIR} NAME)
string(REPLACE " " "_" projectName ${projectName})
message("Project: ${projectName}")

# default build type
if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_BUILD_TYPE Debug CACHE STRING "Debug")
endif()

# create build folder
if(NOT DEFINED ${BUILD_DIR})
    set(BUILD_DIR ${CMAKE_CURRENT_SOURCE_DIR}/build)
    STRING(REGEX REPLACE "\\\\" "/" BUILD_DIR ${BUILD_DIR})
    file(MAKE_DIRECTORY ${BUILD_DIR}/bin/)
endif()

# tests
if(NOT DEFINED PSI_BUILD_TESTS)
    set(PSI_BUILD_TESTS TRUE)
endif()

# examples
if(NOT DEFINED PSI_BUILD_EXAMPLES)
    set(PSI_BUILD_EXAMPLES TRUE)
endif()

message("[${projectName}] Build dir: ${BUILD_DIR}")
message("[${projectName}] PSI_BUILD_TESTS: [${PSI_BUILD_TESTS}]")
message("[${projectName}] PSI_BUILD_EXAMPLES: [${PSI_BUILD_EXAMPLES}]")

# create output folder
if(NOT DEFINED ${BUILD_OUT})
    set(BUILD_OUT ${BUILD_DIR}/bin/${CMAKE_BUILD_TYPE})
    set(CMAKE_RUNTIME_OUTPUT_DIRECTORY_DEBUG ${BUILD_OUT})
    set(CMAKE_RUNTIME_OUTPUT_DIRECTORY_RELEASE ${BUILD_OUT})
    set(CMAKE_LIBRARY_OUTPUT_DIRECTORY_DEBUG ${BUILD_OUT})
    set(CMAKE_LIBRARY_OUTPUT_DIRECTORY_RELEASE ${BUILD_OUT})
    set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY_DEBUG ${BUILD_OUT})
    set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY_RELEASE ${BUILD_OUT})
    file(MAKE_DIRECTORY ${BUILD_OUT})
endif()

message("[${projectName}] Build out: ${BUILD_OUT}")

# functions
# Capture the location of psi-cmake itself at include-time so that helper
# functions can resolve sibling modules regardless of where they are called
# from. CMAKE_CURRENT_LIST_DIR inside a function refers to the caller's
# file, not the file that defined the function.
set(_PSI_CMAKE_DIR "${CMAKE_CURRENT_LIST_DIR}")

if(NOT COMMAND psi_use)
    # Bring a sibling psi-<name> module in as a CMake subproject. Sibling
    # checkouts under ${submodules_root}/psi-<name> are preferred; fall back
    # to a vendored copy under 3rdparty/psi-<name>. The dependency's CMake
    # target (psi-<name>) becomes available with PUBLIC includes propagating
    # transitively via target_link_libraries.
    function(psi_use name)
        if(TARGET psi-${name})
            return()
        endif()

        get_filename_component(_psi_submodules_root "${_PSI_CMAKE_DIR}" DIRECTORY)
        set(_psi_dep_path "")
        if(EXISTS "${_psi_submodules_root}/psi-${name}/CMakeLists.txt")
            set(_psi_dep_path "${_psi_submodules_root}/psi-${name}")
        elseif(EXISTS "${PROJECT_SOURCE_DIR}/3rdparty/psi-${name}/CMakeLists.txt")
            set(_psi_dep_path "${PROJECT_SOURCE_DIR}/3rdparty/psi-${name}")
        endif()

        if(NOT _psi_dep_path)
            message(FATAL_ERROR "[${projectName}] psi-${name} not found "
                "(looked in ${_psi_submodules_root}/psi-${name} and "
                "${PROJECT_SOURCE_DIR}/3rdparty/psi-${name})")
        endif()

        message("[${projectName}] using psi-${name}: ${_psi_dep_path}")
        set(PSI_BUILD_TESTS false)
        set(PSI_BUILD_EXAMPLES false)
        add_subdirectory(${_psi_dep_path} ${CMAKE_BINARY_DIR}/_deps/psi-${name})

        if(${name} STREQUAL "logger")
            add_compile_definitions(PSI_LOGGER)
        endif()
    endfunction()
endif()

if(NOT COMMAND psi_link)
    # target_link_libraries wrapper that auto-loads sibling psi-<name>
    # subprojects via psi_use() before linking. Lets a module declare its
    # dependencies in exactly one place (the psi/CMakeLists.txt that builds
    # the target) instead of duplicating them in dependencies.cmake.
    #
    # Usage: psi_link(<target> [INTERFACE] dep1 dep2 ...)
    #   Each dep that starts with "psi-" is brought in via psi_use() if its
    #   target does not already exist; everything else is forwarded to
    #   target_link_libraries as-is (system libs, absolute paths, etc.).
    function(psi_link target_name)
        set(_link_keyword "")
        set(_libs "")
        foreach(_arg ${ARGN})
            if(_arg STREQUAL "INTERFACE" OR _arg STREQUAL "PUBLIC" OR _arg STREQUAL "PRIVATE")
                set(_link_keyword "${_arg}")
                continue()
            endif()
            if(_arg MATCHES "^psi-(.+)$")
                psi_use(${CMAKE_MATCH_1})
            endif()
            list(APPEND _libs "${_arg}")
        endforeach()

        if(_link_keyword)
            target_link_libraries(${target_name} ${_link_keyword} ${_libs})
        else()
            target_link_libraries(${target_name} ${_libs})
        endif()
    endfunction()
endif()

if(NOT COMMAND psi_deps)
    # Declare module dependencies at the top level of a module's
    # CMakeLists.txt. Each name (without the "psi-" prefix) is brought in
    # as a CMake subproject via psi_use(). The full target list is also
    # remembered in PSI_MODULE_DEPS so that psi_config_target can link the
    # module's library against them automatically — no need to repeat the
    # list inside psi/CMakeLists.txt.
    #
    # Usage: psi_deps(tools thread comm)
    macro(psi_deps)
        set(PSI_MODULE_DEPS "")
        foreach(_dep ${ARGN})
            psi_use(${_dep})
            list(APPEND PSI_MODULE_DEPS "psi-${_dep}")
        endforeach()
    endmacro()
endif()

if(NOT COMMAND psi_make_tests)
    function(psi_make_tests name src libs)
        if(NOT ${PSI_BUILD_TESTS})
            return()
        endif()

        # Make sure the psi-test target is available; bring it in lazily so
        # callers don't have to declare it themselves.
        psi_use(test)

        set(fileName PSI_TEST_${name})
        add_executable(${fileName} ${PROJECT_SOURCE_DIR}/tests/EntryPoint.cpp ${src})
        psi_config_target(${fileName})
        psi_link(${fileName} ${libs} psi-test)
    endfunction()
endif()

if(NOT COMMAND psi_make_examples)
    function(psi_make_examples name src libs)
        if(NOT ${PSI_BUILD_EXAMPLES})
            return()
        endif()

        set(fileName PSI_EXAMPLE_${name})
        add_executable(${fileName} ${src})
        psi_config_target(${fileName})
        psi_link(${fileName} ${libs})
    endfunction()
endif()

if(NOT COMMAND psi_config_target)
    function(psi_config_target target_name)
        # INTERFACE libraries (header-only) have no compile/link of their own,
        # so propagate only the C++ standard via INTERFACE and skip warnings,
        # sanitizers and runtime linkage (consumers get those when they call
        # psi_config_target on their own STATIC/EXECUTABLE targets).
        get_target_property(_psi_target_type ${target_name} TYPE)
        if(_psi_target_type STREQUAL "INTERFACE_LIBRARY")
            target_compile_features(${target_name} INTERFACE cxx_std_20)
            # If this is the module's own library target (named after the
            # project directory), auto-link PSI_MODULE_DEPS declared via
            # psi_deps() at the top level — saves the user from repeating
            # the list inside psi/CMakeLists.txt.
            if(target_name STREQUAL projectName AND PSI_MODULE_DEPS)
                target_link_libraries(${target_name} INTERFACE ${PSI_MODULE_DEPS})
            endif()
            return()
        endif()

        target_compile_features(${target_name} PUBLIC cxx_std_20)

        # Auto-link module deps for the module's own STATIC library target.
        if(target_name STREQUAL projectName AND PSI_MODULE_DEPS)
            target_link_libraries(${target_name} ${PSI_MODULE_DEPS})
        endif()

        # Common Clang warnings (apply to both clang.exe and clang-cl since
        # CMAKE_CXX_COMPILER_ID == "Clang" in both cases).
        set(_psi_clang_warnings
            -Wall
            -Wextra
            -Wpedantic
            -Wno-c++98-compat
            -Wno-c++98-compat-pedantic
            -Wswitch
            -Wswitch-enum
            -Wcovered-switch-default
            -Wno-switch-default
            -Wno-padded
        )
        foreach(_w IN LISTS _psi_clang_warnings)
            target_compile_options(${target_name} PRIVATE
                $<$<CXX_COMPILER_ID:Clang>:${_w}>)
        endforeach()

        if(ENABLE_ASAN_UBSAN)
            # Detect MSVC-like driver (cl.exe or clang-cl) vs GNU-like driver
            # (gcc, clang.exe). MSVC and clang-cl share /Foo flag syntax.
            if(MSVC OR CMAKE_CXX_COMPILER_FRONTEND_VARIANT STREQUAL "MSVC")
                target_compile_options(${target_name} PRIVATE
                    /O2
                    /fsanitize=address
                    /RTC-
                )
                # UBSan is only supported by clang-cl, not by MSVC cl.exe.
                if(CMAKE_CXX_COMPILER_ID STREQUAL "Clang")
                    target_compile_options(${target_name} PRIVATE
                        -fsanitize=undefined
                    )
                    # Link ASAN runtime explicitly. /fsanitize=address normally
                    # injects /defaultlib comments, but lld-link's auto-resolution
                    # is unreliable across module boundaries (especially for
                    # static libs embedded in executables), so we force-link
                    # them on every target. Use the plain signature to stay
                    # consistent with the rest of the codebase.
                    target_link_libraries(${target_name}
                        clang_rt.asan_dynamic-x86_64
                        clang_rt.asan_dynamic_runtime_thunk-x86_64
                    )
                    # Copy the ASAN runtime DLL next to the executable so
                    # tests/examples can run without extending PATH manually.
                    if(_psi_target_type STREQUAL "EXECUTABLE")
                        set(_psi_asan_dll "$ENV{LLVM_LIB}/clang_rt.asan_dynamic-x86_64.dll")
                        if(EXISTS "${_psi_asan_dll}")
                            add_custom_command(TARGET ${target_name} POST_BUILD
                                COMMAND ${CMAKE_COMMAND} -E copy_if_different
                                        "${_psi_asan_dll}"
                                        "$<TARGET_FILE_DIR:${target_name}>"
                                VERBATIM)
                        endif()
                    endif()
                endif()
            else()
                target_compile_options(${target_name} PRIVATE
                    -O2
                    -fsanitize=address
                    -fsanitize=undefined
                )
                target_link_options(${target_name} PRIVATE
                    -fsanitize=address
                    -fsanitize=undefined
                )
            endif()
        endif()
    endfunction()
endif()