cmake_minimum_required(VERSION 3.22.1)
project(zync_raw LANGUAGES C CXX)

set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
set(ENABLE_OPENMP OFF CACHE BOOL "" FORCE)
set(ENABLE_LCMS OFF CACHE BOOL "" FORCE)
set(ENABLE_JASPER OFF CACHE BOOL "" FORCE)
set(ENABLE_EXAMPLES OFF CACHE BOOL "" FORCE)
set(ENABLE_RAWSPEED OFF CACHE BOOL "" FORCE)
set(ENABLE_X3FTOOLS OFF CACHE BOOL "" FORCE)
set(ENABLE_6BY9RPI OFF CACHE BOOL "" FORCE)
set(LIBRAW_INSTALL OFF CACHE BOOL "" FORCE)
set(LIBRAW_UNINSTALL_TARGET OFF CACHE BOOL "" FORCE)

add_subdirectory(libraw)

add_library(zync_raw SHARED
    raw_processor_jni.cpp
)

target_compile_features(zync_raw PRIVATE cxx_std_17)
target_compile_options(zync_raw PRIVATE -O2 -ffast-math -fvisibility=hidden)
target_include_directories(zync_raw PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}/libraw
)
target_link_libraries(zync_raw
    raw
    android
    log
    jnigraphics
)