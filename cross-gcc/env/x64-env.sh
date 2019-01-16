# -*- mode: shell; coding:utf-8 -*-
###############################################################################
#
###############################################################################
KERN_ARCH=x86_64
TARGET_CPU=x86_64
QEMU_CPU=x86_64
_LIB=lib64

###############################################################################
#
###############################################################################
GMAKE=make-4.2
GTAR=tar-1.30
GMP=gmp-6.1.0
MPFR=mpfr-3.1.4
MPC=mpc-1.0.3
ISL=isl-0.18
KERNEL=linux-4.19.13
ELFUTILS=elfutils-0.157
BINUTILS=binutils-2.31
GCC=gcc-8.2.0
GLIBC=glibc-2.28
NEWLIB=newlib-3.0.0
GDB=gdb-8.2
QEMU=qemu-3.1.0
CMAKE=cmake-3.12.4
EDK2=edk2-current
DOWNLOAD_URLS="ftp://ftp.gnu.org/gnu/make/make-4.2.tar.gz
ftp://ftp.gnu.org/gnu/tar/tar-1.30.tar.gz
ftp://gcc.gnu.org/pub/gcc/infrastructure/gmp-6.1.0.tar.bz2
ftp://gcc.gnu.org/pub/gcc/infrastructure/mpfr-3.1.4.tar.bz2
ftp://gcc.gnu.org/pub/gcc/infrastructure/mpc-1.0.3.tar.gz
ftp://gcc.gnu.org/pub/gcc/infrastructure/isl-0.18.tar.bz2
ftp://sourceware.org/pub/elfutils/0.157/elfutils-0.157.tar.bz2
https://cdn.kernel.org/pub/linux/kernel/v4.x/linux-4.19.13.tar.gz
https://ftp.gnu.org/gnu/binutils/binutils-2.31.tar.gz
https://ftp.gnu.org/gnu/gcc/gcc-8.2.0/gcc-8.2.0.tar.gz
https://ftp.gnu.org/gnu/libc/glibc-2.28.tar.gz
https://ftp.gnu.org/gnu/gdb/gdb-8.2.tar.gz
https://download.qemu.org/qemu-3.1.0.tar.xz
https://cmake.org/files/v3.12/cmake-3.12.4.tar.gz
ftp://sourceware.org/pub/newlib/newlib-3.0.0.tar.gz"

EDK2_GIT_REPO="git@github.com:tianocore/edk2.git"

PATCHES_URLS="https://fedorahosted.org/releases/e/l/elfutils/0.157/elfutils-portability.patch
https://fedorahosted.org/releases/e/l/elfutils/0.157/elfutils-robustify.patch"
