find_package(GTest REQUIRED)

add_executable(test_types test_types.cpp)
target_include_directories(test_types PRIVATE ${CMAKE_SOURCE_DIR}/include)
target_link_libraries(test_types PRIVATE GTest::gtest GTest::gtest_main)
add_test(NAME test_types COMMAND test_types)

add_executable(test_manager test_manager.cpp)
target_include_directories(test_manager PRIVATE
    ${CMAKE_SOURCE_DIR}/include
)
target_link_libraries(test_manager PRIVATE
    sdbus-c++
    GTest::gtest GTest::gtest_main
)
add_test(NAME test_manager COMMAND test_manager)

# Links the real pk_transaction.cpp so hint construction is tested as shipped,
# not reimplemented. dart_api_dl satisfies the Dart_PostCObject_DL references.
add_executable(test_transaction
    test_transaction.cpp
    ${CMAKE_SOURCE_DIR}/src/pk_transaction.cpp
    $<TARGET_OBJECTS:dart_api_dl>
)
target_include_directories(test_transaction PRIVATE
    ${CMAKE_SOURCE_DIR}/include
)
target_link_libraries(test_transaction PRIVATE
    sdbus-c++
    GTest::gtest GTest::gtest_main
)
add_test(NAME test_transaction COMMAND test_transaction)
