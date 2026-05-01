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
if(NOT COMMAND find_submodule)
    function(find_submodule name path isDependent)
        get_filename_component(submodules_base_dir ${CMAKE_CURRENT_LIST_DIR} DIRECTORY BASE_DIR)

        # message ("submodules_base_dir: ${submodules_base_dir}/${name}")
        if(EXISTS ${submodules_base_dir}/${name})
            set(${path} ${submodules_base_dir}/${name} PARENT_SCOPE)
            set(${isDependent} "no" PARENT_SCOPE)
        elseif(EXISTS ${3rdPARTY_DIR}/${name})
            set(${path} ${3rdPARTY_DIR}/${name} PARENT_SCOPE)
            set(${isDependent} "yes" PARENT_SCOPE)
        else()
        endif()
    endfunction()
endif()

if(NOT COMMAND include_psi_dependency)
    function(include_psi_dependency name)
        find_submodule(psi-${name} dep_path is_dependent)
        message("[${projectName}] psi_${name}_dir: ${dep_path}, is_dependent: ${is_dependent}")

        if(NOT EXISTS ${dep_path})
            return()
        endif()

        include_directories(${dep_path}/psi/include)
    endfunction()
endif()

if(NOT COMMAND add_psi_dependency)
    function(add_psi_dependency name)
        find_submodule(psi-${name} dep_path is_dependent)
        message("[${projectName}] psi_${name}_dir: ${dep_path}, is_dependent: ${is_dependent}")

        if(NOT EXISTS ${dep_path})
            return()
        endif()

        # Global include path for legacy modules that don't use
        # target_link_libraries to consume the dependency yet.
        include_directories(${dep_path}/psi/include)

        # Bring the dependency in as a CMake subproject so that its targets
        # (psi-<name> / psi::<name>) become available, with PUBLIC includes
        # propagating transitively via target_link_libraries.
        if(NOT TARGET psi-${name})
            set(PSI_BUILD_TESTS false)
            set(PSI_BUILD_EXAMPLES false)
            message("[${projectName}] configuring [psi-${name}]... ${dep_path}")
            add_subdirectory(${dep_path} ${CMAKE_BINARY_DIR}/_deps/psi-${name})
        endif()

        if(TARGET psi-${name})
            set(PSI_DEP_LIBS "${PSI_DEP_LIBS};psi-${name};" PARENT_SCOPE)
        endif()

        if(${name} STREQUAL "logger")
            message("[${projectName}] found psi-logger")
            add_compile_definitions(PSI_LOGGER)
        endif()
    endfunction()
endif()

if(NOT COMMAND psi_make_tests)
    function(psi_make_tests name src libs)
        if(NOT ${PSI_BUILD_TESTS})
            return()
        endif()

        # psi-test target is brought in via add_psi_dependency(test) in
        # the module's dependencies.cmake. Its PUBLIC include directory
        # propagates transitively through target_link_libraries.
        if(NOT TARGET psi-test)
            message(WARNING "[psi_make_tests] target 'psi-test' not found; "
                "did you call add_psi_dependency(test) in dependencies.cmake?")
            return()
        endif()

        set(fileName PSI_TEST_${name})
        add_executable(${fileName} ${PROJECT_SOURCE_DIR}/tests/EntryPoint.cpp ${src})
        psi_config_target(${fileName})
        target_link_libraries(${fileName} ${libs} psi-test ${PSI_DEP_LIBS})
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
        if(ENABLE_ASAN_UBSAN)
            set(PSI_DEP_LIBS "${PSI_DEP_LIBS};clang_rt.asan_dynamic-x86_64;clang_rt.asan_dynamic_runtime_thunk-x86_64")
        endif()
        target_link_libraries(${fileName} ${libs} ${PSI_DEP_LIBS})
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
            return()
        endif()

        target_compile_features(${target_name} PUBLIC cxx_std_20)

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