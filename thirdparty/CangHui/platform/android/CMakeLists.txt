cmake_minimum_required(VERSION 3.22.1)

project(canghui_android_surface LANGUAGES CXX)

add_library(canghui_android_surface SHARED
    src/main/cpp/canghui_android_surface.cpp
)

target_compile_features(canghui_android_surface PRIVATE cxx_std_17)
target_compile_options(canghui_android_surface PRIVATE
    -Wall
    -Wextra
    -Werror
    -fvisibility=hidden
)
target_link_libraries(canghui_android_surface PRIVATE android log)
