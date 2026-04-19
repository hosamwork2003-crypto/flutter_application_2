cmake_minimum_required(VERSION 3.22.1)

project(native_piano)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_subdirectory(oboe)

add_library(
    native_piano
    SHARED
    native_piano.cpp
)

target_include_directories(
    native_piano
    PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}/oboe/include
    ${CMAKE_CURRENT_SOURCE_DIR}/oboe/include/oboe
)

find_library(
    log-lib
    log
)

target_link_libraries(
    native_piano
    oboe
    ${log-lib}
)