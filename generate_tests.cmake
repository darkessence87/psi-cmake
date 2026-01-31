set(inputs ${INPUTS})
string(REPLACE " " ";" inputs "${inputs}")

file(WRITE ${OUTPUT}
"#include \"psi/test/psi_test.h\"\n"
"using namespace psi::test;\n\n"
)

set(SEEN_FUNCS "")
set(REGISTER_LINES "")
foreach(file IN LISTS inputs)
    file(READ "${file}" CONTENTS)

    string(REGEX REPLACE "//[^\n]*" "" CONTENTS "${CONTENTS}")
    string(REGEX REPLACE "/\\*([^*]|\\*+[^*/])*\\*+/" "" CONTENTS "${CONTENTS}")
    string(REGEX MATCHALL "TEST\\([ \t]*([A-Za-z0-9_]+)[ \t]*,[ \t]*([A-Za-z0-9_]+)[ \t]*\\)" MATCHES "${CONTENTS}")

    foreach(m IN LISTS MATCHES)
        string(REGEX MATCH "TEST\\([ \t]*([A-Za-z0-9_]+)[ \t]*,[ \t]*([A-Za-z0-9_]+)[ \t]*\\)" _ "${m}")

        set(TEST_GROUP "${CMAKE_MATCH_1}")
        set(TEST_CASE_NAME  "${CMAKE_MATCH_2}")
        if (TEST_CASE_NAME MATCHES "^DISABLED_")
            continue()
        endif()

        set(FN "${TEST_GROUP}_${TEST_CASE_NAME}_impl")

        list(FIND SEEN_FUNCS "${FN}" _idx)
        if (_idx EQUAL -1)
            list(APPEND SEEN_FUNCS "${FN}")
            file(APPEND ${OUTPUT} "extern void ${FN}();\n")
        endif()

        list(APPEND REGISTER_LINES "    TestLib::add_test({\"${TEST_GROUP}\", \"${TEST_CASE_NAME}\", &${FN}, {}})\;\n")

    endforeach()
endforeach()

file(APPEND ${OUTPUT}
"void register_all_tests();\n"
"void register_all_tests() {\n")

foreach(line IN LISTS REGISTER_LINES)
    file(APPEND ${OUTPUT} "${line}")
endforeach()

file(APPEND ${OUTPUT} "}\n")
