# -*- mode: shell; coding:utf-8 -*-
###############################################################################
#
###############################################################################
KERN_ARCH=i386
TARGET_CPU=i686
QEMU_CPU=i386
BUILD_UEFI=yes
_LIB=lib
TARGET_ELF=i686-pc-elf
###############################################################################
#
###############################################################################
GMAKE=make-4.3
GTAR=tar-1.32
GMP=gmp-6.1.0
MPFR=mpfr-3.1.4
MPC=mpc-1.0.3
ISL=isl-0.18
KERNEL=linux-4.19.13
BINUTILS=binutils-2.34
GCC=gcc-10.2.0
GLIBC=glibc-2.30
NEWLIB=newlib-3.1.0
GDB=gdb-9.2
QEMU=qemu-5.0.0
CMAKE=cmake-3.15.5
EDK2=edk2-current
DOWNLOAD_URLS="ftp://ftp.gnu.org/gnu/make/make-4.3.tar.gz
ftp://ftp.gnu.org/gnu/tar/tar-1.32.tar.gz
ftp://gcc.gnu.org/pub/gcc/infrastructure/gmp-6.1.0.tar.bz2
ftp://gcc.gnu.org/pub/gcc/infrastructure/mpfr-3.1.4.tar.bz2
ftp://gcc.gnu.org/pub/gcc/infrastructure/mpc-1.0.3.tar.gz
ftp://gcc.gnu.org/pub/gcc/infrastructure/isl-0.18.tar.bz2
https://cdn.kernel.org/pub/linux/kernel/v4.x/linux-4.19.13.tar.gz
https://ftp.gnu.org/gnu/binutils/binutils-2.34.tar.gz
https://ftp.gnu.org/gnu/gcc/gcc-10.2.0/gcc-10.2.0.tar.gz
https://ftp.gnu.org/gnu/libc/glibc-2.30.tar.gz
https://ftp.gnu.org/gnu/gdb/gdb-9.2.tar.gz
https://download.qemu.org/qemu-5.0.0.tar.xz
https://cmake.org/files/v3.15/cmake-3.15.5.tar.gz
ftp://sourceware.org/pub/newlib/newlib-3.1.0.tar.gz"

EDK2_GIT_REPO="git@github.com:tianocore/edk2.git"

PATCHES_URLS=""

