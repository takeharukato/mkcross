# -*- mode: shell; coding:utf-8 -*-
###############################################################################
###############################################################################
KERN_ARCH=arm64
TARGET_CPU=aarch64
QEMU_CPU=aarch64
SAMPLE_COMPILE_OPT="-O3 -march=armv8.2-a+sve"
ELF_SAMPLE_COMPILE_OPT="-DWITH_NEWLIB ${SAMPLE_COMPILE_OPT} --specs=rdimon.specs"
BUILD_UEFI=yes
_LIB=lib64
