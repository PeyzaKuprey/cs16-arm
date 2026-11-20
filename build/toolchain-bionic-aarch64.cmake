# Android NDK (Bionic) — aarch64.  CMake native Android support: set
# CMAKE_SYSTEM_NAME=Android and point CMAKE_ANDROID_NDK at an NDK checkout.
# API 24 = dladdr/dl_iterate_phdr floor; matches Termux (Android 7+).
set(CMAKE_SYSTEM_NAME Android)
set(CMAKE_SYSTEM_VERSION 24)
set(CMAKE_ANDROID_ARCH_ABI arm64-v8a)
set(CMAKE_ANDROID_NDK "$ENV{ANDROID_NDK}" CACHE PATH "")
set(CMAKE_ANDROID_STL_TYPE c++_static)
set(CMAKE_ANDROID_SKIP_ANNOYING_WARNINGS ON)
# no -static-libstdc++/libgcc: libc++ comes via CMAKE_ANDROID_STL_TYPE,
# libgcc is built into bionic
