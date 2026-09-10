cmake_minimum_required(VERSION 3.20)

project(canghui_scene3d_bgfx_native_supply LANGUAGES C CXX OBJCXX)

set(BGFX4CJ_ROOT "" CACHE PATH "Pinned bgfx4cj source checkout")
if(NOT BGFX4CJ_ROOT)
    message(FATAL_ERROR "BGFX4CJ_ROOT is required")
endif()

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_OSX_ARCHITECTURES arm64)
set(CMAKE_OSX_DEPLOYMENT_TARGET 12.0)

set(BGFX_ROOT "${BGFX4CJ_ROOT}/cxx/bgfx")
set(BIMG_ROOT "${BGFX4CJ_ROOT}/cxx/bimg")
set(BX_ROOT "${BGFX4CJ_ROOT}/cxx/bx")

add_compile_options(
    "-ffile-prefix-map=${BGFX4CJ_ROOT}=bgfx4cj"
    "-fmacro-prefix-map=${BGFX4CJ_ROOT}=bgfx4cj"
    "-fdebug-prefix-map=${BGFX4CJ_ROOT}=bgfx4cj"
)

set(COMMON_DEFINES
    __STDC_LIMIT_MACROS
    __STDC_FORMAT_MACROS
    __STDC_CONSTANT_MACROS
    BX_CONFIG_DEBUG=0
    BX_PLATFORM_OSX=1
    NDEBUG
)

file(GLOB BX_SOURCES CONFIGURE_DEPENDS "${BX_ROOT}/src/*.cpp")
add_library(bx STATIC ${BX_SOURCES})
target_include_directories(bx PUBLIC
    "${BX_ROOT}/include"
    "${BX_ROOT}/include/compat/osx"
    "${BX_ROOT}/3rdparty"
)
target_compile_definitions(bx PRIVATE ${COMMON_DEFINES})
target_compile_options(bx PRIVATE -fPIC -fno-rtti -fno-exceptions)

file(GLOB ASTC_ENCODER_SOURCES CONFIGURE_DEPENDS
    "${BIMG_ROOT}/3rdparty/astc-encoder/source/*.cpp"
)
add_library(bimg STATIC
    ${ASTC_ENCODER_SOURCES}
    "${BIMG_ROOT}/src/image.cpp"
    "${BIMG_ROOT}/src/image_gnf.cpp"
)
target_include_directories(bimg PUBLIC
    "${BIMG_ROOT}/include"
    "${BIMG_ROOT}/3rdparty"
    "${BIMG_ROOT}/3rdparty/astc-encoder/include"
    "${BX_ROOT}/include"
    "${BX_ROOT}/include/compat/osx"
)
target_compile_definitions(bimg PRIVATE ${COMMON_DEFINES})
target_compile_options(bimg PRIVATE -fPIC -fno-rtti -fno-exceptions)
target_link_libraries(bimg PUBLIC bx)

add_library(bgfx STATIC
    "${BGFX_ROOT}/src/bgfx.cpp"
    "${BGFX_ROOT}/src/debug_renderdoc.cpp"
    "${BGFX_ROOT}/src/dxgi.cpp"
    "${BGFX_ROOT}/src/glcontext_egl.cpp"
    "${BGFX_ROOT}/src/glcontext_html5.cpp"
    "${BGFX_ROOT}/src/glcontext_wgl.cpp"
    "${BGFX_ROOT}/src/nvapi.cpp"
    "${BGFX_ROOT}/src/renderer_agc.cpp"
    "${BGFX_ROOT}/src/renderer_d3d11.cpp"
    "${BGFX_ROOT}/src/renderer_d3d12.cpp"
    "${BGFX_ROOT}/src/renderer_gl.cpp"
    "${BGFX_ROOT}/src/renderer_gnm.cpp"
    "${BGFX_ROOT}/src/renderer_mtl.mm"
    "${BGFX_ROOT}/src/renderer_noop.cpp"
    "${BGFX_ROOT}/src/renderer_nvn.cpp"
    "${BGFX_ROOT}/src/renderer_vk.cpp"
    "${BGFX_ROOT}/src/shader.cpp"
    "${BGFX_ROOT}/src/shader_dxbc.cpp"
    "${BGFX_ROOT}/src/shader_spirv.cpp"
    "${BGFX_ROOT}/src/topology.cpp"
    "${BGFX_ROOT}/src/vertexlayout.cpp"
)
target_include_directories(bgfx PUBLIC
    "${BGFX_ROOT}/include"
    "${BGFX_ROOT}/3rdparty"
    "${BGFX_ROOT}/3rdparty/khronos"
    "${BIMG_ROOT}/include"
    "${BX_ROOT}/include"
    "${BX_ROOT}/include/compat/osx"
)
target_compile_definitions(bgfx PRIVATE
    ${COMMON_DEFINES}
    BGFX_CONFIG_RENDERER_METAL=1
    BGFX_CONFIG_RENDERER_AGC=0
    BGFX_CONFIG_RENDERER_DIRECT3D11=0
    BGFX_CONFIG_RENDERER_DIRECT3D12=0
    BGFX_CONFIG_RENDERER_GNM=0
    BGFX_CONFIG_RENDERER_NVN=0
    BGFX_CONFIG_RENDERER_OPENGL=0
    BGFX_CONFIG_RENDERER_OPENGLES=0
    BGFX_CONFIG_RENDERER_VULKAN=0
)
target_compile_options(bgfx PRIVATE -fPIC -fno-rtti -fno-exceptions)
set_source_files_properties("${BGFX_ROOT}/src/renderer_mtl.mm" PROPERTIES
    COMPILE_OPTIONS "-fno-objc-msgsend-selector-stubs"
)
target_link_libraries(bgfx PUBLIC
    bimg
    bx
    "-framework Metal"
    "-framework QuartzCore"
    "-framework Cocoa"
    "-framework Foundation"
    "-framework IOKit"
)
