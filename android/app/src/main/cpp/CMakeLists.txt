cmake_minimum_required(VERSION 3.22.1)

project("jniseline_read")

add_library(jniseline_read SHARED
    seline_read.cpp)


target_include_directories(jniseline_read
    PRIVATE seline_read.h
)

target_link_libraries(jniseline_read
    android
    log)
