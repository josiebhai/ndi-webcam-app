cmake_minimum_required(VERSION 3.22.1)
project("ndiwebcam")

# NDI SDK shared library.
# After downloading the NDI SDK, copy the .so files for each ABI into:
#   app/src/main/jniLibs/arm64-v8a/libndi.so
#   app/src/main/jniLibs/armeabi-v7a/libndi.so
#   app/src/main/jniLibs/x86_64/libndi.so
# And copy the NDI headers into:
#   app/src/main/cpp/include/
add_library(ndi SHARED IMPORTED)
set_target_properties(ndi PROPERTIES
    IMPORTED_LOCATION "${CMAKE_SOURCE_DIR}/../jniLibs/${ANDROID_ABI}/libndi.so"
)

add_library(ndiwebcam SHARED ndi_jni.cpp)

target_include_directories(ndiwebcam PRIVATE
    ${CMAKE_SOURCE_DIR}/include   # NDI SDK headers go here
)

target_link_libraries(ndiwebcam
    ndi
    android
    log
    mediandk
)
