# Bootlin armv7-eabihf toolchain (gcc 10.3, glibc 2.34) — target: Debian bookworm+ armhf / proot-distro
# NEON enabled explicitly (Bootlin default is VFP-only); Cortex-A53 (Redmi 9C) supports it.
# -mtune=cortex-a53 overrides the -mtune=generic used upstream (unsupported by gcc on ARM);
# the last -mtune wins on the command line.
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR armv7l)
get_filename_component(TC_ROOT "${CMAKE_CURRENT_LIST_DIR}/../toolchains/armv7" ABSOLUTE)
set(CMAKE_C_COMPILER   ${TC_ROOT}/bin/arm-buildroot-linux-gnueabihf-gcc)
set(CMAKE_CXX_COMPILER ${TC_ROOT}/bin/arm-buildroot-linux-gnueabihf-g++)
set(CMAKE_SYSROOT      ${TC_ROOT}/arm-buildroot-linux-gnueabihf/sysroot)
set(CMAKE_FIND_ROOT_PATH ${CMAKE_SYSROOT})
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
set(ARCH_ARM32_FLAGS "-march=armv7-a -mtune=cortex-a53 -mfpu=neon -mfloat-abi=hard")
set(CMAKE_C_FLAGS_INIT   "${ARCH_ARM32_FLAGS}")
set(CMAKE_CXX_FLAGS_INIT "${ARCH_ARM32_FLAGS}")