#!/usr/bin/env bash

###############################################################################
#                               環境設定                                      #
###############################################################################

#
#コンパイルに影響する変数をアンセットする
#
unset CROSS_COMPILE
unset ARCH
unset CPU
unset KERN_ARCH
unset TARGET_CPU
unset QEMU_CPU
unset HOSTCC
unset KERN_MAJOR
unset KERN_MINOR
unset KERN_REV

#エラーメッセージの文字化けを避けるためにCロケールで動作させる
LANG=C

if [ $# -ne 1 ]; then
    echo "build.sh environment-def.sh"
    exit 1
fi

# LLVM_ENABLE_PROJECTSのフルリストは,
# clang;clang-tools-extra;compiler-rt;debuginfo-tests;libc;libclc;libcxx;libcxxabi;
# libunwind;lld;lldb;openmp;parallel-libs;polly;pstl
# ( https://llvm.org/docs/CMake.html 参照)
# 以下はコンパイルエラーになるため除外
# - libc
if [ "x${USE_FLANG}" != 'x' ]; then
    LLVM_PROJECTS="clang;clang-tools-extra;compiler-rt;debuginfo-tests;libclc;libcxx;libcxxabi;libunwind;lld;lldb;mlir;openmp;parallel-libs;polly;pstl;flang"
else
    LLVM_PROJECTS="clang;clang-tools-extra;compiler-rt;debuginfo-tests;libclc;libcxx;libcxxabi;libunwind;lld;lldb;mlir;openmp;parallel-libs;polly;pstl"
fi
#
#環境ファイル読み込み
#
ENV_FILE=$1
if [ ! -f "${ENV_FILE}" ]; then
    echo "File not found: ${ENV_FILE}"
    exit 1
else
    echo "Load ${ENV_FILE}"
    source "${ENV_FILE}"
fi
## begin
#  環境変数の設定を行う
## end 
setup_variables(){

    echo "@@@ Setup variables @@@"

    TODAY=`date "+%F"`

    RTLD=/lib64/ld-2.17.so
    
    OSNAME=`uname`

    if [ "x${CPUS}" = "x" ]; then
	if [ "x${OSNAME}" = "xLinux" ]; then
	    CPUS=`nproc`
	else
	    if [ "x${OSNAME}" = "xFreeBSD" ]; then
		CPUS=`sysctl -a|grep kern.smp.cpus|awk -F':' '{print $2;}'|tr -d ' '`
	    fi
	fi
    fi

    if [ "x${NO_SMP}" = 'x' -a "x${CPUS}" != "x" ]; then
	SMP_OPT="-j${CPUS}"
    fi

    if [ "x${BUILD}" = "x" ]; then
	if [ -x /usr/bin/gcc ]; then
	    BUILD=`/usr/bin/gcc -dumpmachine`
	else
	    if [ -x /usr/bin/clang ]; then
		BUILD=`/usr/bin/clang -v 2>&1|grep Target|awk -F ':' '{print $2;}'|tr -d ' '`
	    fi
	fi
    fi

    if [ "x${OSNAME}" = "xLinux" ]; then
	KERN_MAJOR=`uname -r|awk -F'-' '{print $1;}'|awk -F '.' '{print $1}'`
	KERN_MINOR=`uname -r|awk -F'-' '{print $1;}'|awk -F '.' '{print $2}'`
	KERN_REV=`uname -r|awk -F'-' '{print $1;}'|awk -F '.' '{print $3}'`
	
	echo "Host Linux kernel ${KERN_MAJOR}.${KERN_MINOR}.${KERN_REV}"
	
	if [ ${KERN_MAJOR} -ge 4 -a ${KERN_MINOR} -ge 3 ]; then
	    QEMU_CONFIG_MEMBARRIER="--enable-membarrier"
	else
	    QEMU_CONFIG_MEMBARRIER=""
	fi

	QEMU_CONFIG_USERLAND="--enable-user --enable-linux-user"
    else
	if [ "x${QEMU_CPU}" = "xx86_64" -o "x${QEMU_CPU}" = "xi386" ]; then
	    QEMU_CONFIG_USERLAND="--enable-user --enable-bsd-user"
	fi
    fi

    #カレントディレクトリ配下で構築作業を進める
    WORKDIR=`pwd`

    #カレントディレクトリ直下のディレクトリのリスト
    SUBDIRS="downloads build src cross tools"

    #ソース展開先ディレクトリ
    SRCDIR=${WORKDIR}/src

    #構築ディレクトリ
    #srcとは別のディレクトリを用意する
    BUILDDIR=${WORKDIR}/build

    #パッチ格納先ディレクトリ
    PATCHDIR=${WORKDIR}/patches

    #アーカイブダウンロードディレクトリ
    DOWNLOADDIR=${WORKDIR}/downloads

    #ビルドツールディレクトリ
    BUILD_TOOLS_DIR=${WORKDIR}/tools

    #コンパイラを格納するディレクトリ
    if [ "x${CROSS_PREFIX}" = "x" ]; then
	CROSS_PREFIX=${HOME}/cross/llvm
    fi
    CROSS=${CROSS_PREFIX}/${TODAY}
    
    # 構築に使用するツールを選択
    if [ "x${NO_NINJA}" = "x" ]; then
	LLVM_BUILD_TYPE="Ninja"
    else
	LLVM_BUILD_TYPE="Unix Makefiles"
    fi

    #
    #パスの設定
    #
    OLD_PATH=${PATH}
    DEFAULT_PATH=/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/bin:/sbin
    PATH=${BUILD_TOOLS_DIR}/bin:${CROSS}/bin:${DEFAULT_PATH}
    LD_LIBRARY_PATH=${CROSS}/lib64:${CROSS}/lib:${BUILD_TOOLS_DIR}/lib64:${BUILD_TOOLS_DIR}/lib

    export PATH
    export LD_LIBRARY_PATH
}    
## begin
# 環境情報を表示する
## end
show_info(){

    echo "@@@ Build information @@@"
    echo "Tool chain type: LLVM"
    echo "Build: ${BUILD}"
    echo "Build OS: ${OSNAME}"
    echo "Python: ${PYTHON_VER}"
    if [ "x${NO_NINJA}" = "x" ]; then
	echo "Build with: ninja"
    else
	echo "Build with: make"
    fi
    if [ "x${SMP_OPT}" != "x" ]; then
	echo "SMP_OPT: ${SMP_OPT}"
    else
	echo "SMP_OPT: None"
    fi

}

## begin note
# 一時ディレクトリを削除
## end note
cleanup_temporary_directories(){
    local dname

    for dname in build src tools
    do
	if [ -d "${WORKDIR}" -a -d "${WORKDIR}/${dname}" ]; then 
	    echo "Cleanup ${dname}"
	    rm -fr "${WORKDIR}/${dname}"
	fi
    done
}

## begin note
# 機能:コンパイラ構築環境用ディレクトリを作成する
## end note
cleanup_directories() {
    local pname
    local linkname

    echo "@@@ Preparation:CLEANUP-directories @@@"
    cleanup_temporary_directories
    
    pname=`dirname ${CROSS}`
    linkname=`readlink ${CROSS}`
    if [ -L "${CROSS}" ]; then


	if [ -d "${pname}/${linkname}" ]; then
	    echo "Cleanup ${pname}/${linkname}"
	    rm -fr "${pname}/${linkname}"
	fi

	if [ -d "${linkname}" ]; then
	    echo "Cleanup ${linkname}"
	    rm -fr "${linkname}"
	fi
	
    fi

    if [ -d "${CROSS}" ]; then
	echo "Cleanup ${CROSS}"
	rm -fr ${CROSS}
    fi

    rm -f ${CROSS_PREFIX}/current ${CROSS}
}

## begin note
# 機能:アーカイブを展開する
## end note 
extract_archive() {
    local basename

    basename=$1
    
    if [ -d ${SRCDIR}/${basename} ]; then
	rm -fr  ${SRCDIR}/${basename}
    fi
    mkdir -p ${SRCDIR}
    pushd ${SRCDIR}
    if [ -f ${DOWNLOADDIR}/${basename}.tar.gz ]; then
	tar zxf ${DOWNLOADDIR}/${basename}.tar.gz
    else
	if [ -f ${DOWNLOADDIR}/${basename}.tar.bz2 ]; then
	    tar jxf ${DOWNLOADDIR}/${basename}.tar.bz2
	else
	    if [ -f ${DOWNLOADDIR}/${basename}.tar.xz ]; then
		tar Jxf ${DOWNLOADDIR}/${basename}.tar.xz
	    fi
	fi
    fi
    popd
}

## begin note
# 機能:開発環境をそろえる
## end note
prepare_devenv(){
    local DNF_CMD=/bin/dnf
    local YUM_CMD=/bin/yum
    local YUM_BUILDDEP_CMD=yum-builddep

    if [ "x${OSNAME}" = "xLinux" ]; then

	if [ -e ${DNF_CMD} ]; then
    
	    sudo ${DNF_CMD} config-manager --set-enabled BaseOS
	    # clang needs AppStream
	    sudo ${DNF_CMD} config-manager --set-enabled AppStream
	    sudo ${DNF_CMD} config-manager --set-enabled PowerTools
	    sudo ${DNF_CMD} config-manager --set-enabled extras

            sudo ${DNF_CMD} install -y epel-release
	    sudo ${DNF_CMD} config-manager --set-enabled epel
	    sudo ${DNF_CMD} config-manager --set-enabled epel-modular

	    sudo ${DNF_CMD} install -y dnf-plugins-core \
		 dnf-plugins-extras-repoclosure dnf-plugins-extras-repograph \
		 dnf-plugins-extras-repomanage dnf-plugins-extras-debug \
		 dnf-plugins-extras-debug 
	else
	    DNF_CMD=/bin/yum
	    sudo ${YUM_CMD} install -y yum-priorities epel-release yum-utils	    	    
	fi

	# Basic commands
	sudo ${DNF_CMD} install -y sudo passwd bzip2 patch nano which tar xz wget

	# Prerequisites header/commands for GCC
	sudo ${DNF_CMD} install -y glibc-devel binutils gcc bash gawk \
	     gzip bzip2-devel make tar perl libmpc-devel
	sudo ${DNF_CMD} install -y m4 automake autoconf gettext-devel libtool \
	     libtool-ltdl-devel gperf autogen guile texinfo texinfo-tex texlive texlive* \
	     python3-sphinx git openssh diffutils patch

	# Prerequisites library for GCC
	sudo ${DNF_CMD} install -y glibc-devel zlib-devel elfutils-devel \
	     gmp-devel mpfr-devel libstdc++-devel binutils-devel libzstd-devel

	# Multilib
	sudo ${DNF_CMD} install -y glibc-devel.i686 zlib-devel.i686 elfutils-devel.i686 \
	     gmp-devel.i686 mpfr-devel.i686 libstdc++-devel.i686 binutils-devel.i686 \
	     libzstd-devel.i686

	# Prerequisites CMake
	sudo ${DNF_CMD} install -y openssl-devel
	
	# Prerequisites for LLVM
	sudo ${DNF_CMD} install -y libedit-devel libxml2-devel cmake

	# Prerequisites for SWIG
	sudo ${DNF_CMD} install -y boost-devel

	# Python
	sudo ${DNF_CMD} install -y python3-devel swig
	
	# Version manager
	sudo ${DNF_CMD} install -y git subversion 

	# Document commands
	sudo ${DNF_CMD} install -y re2c graphviz doxygen
	sudo ${DNF_CMD} install -y docbook-utils docbook-style-xsl 

	# patchelf
	sudo ${DNF_CMD} install -y patchelf
	
        # For UEFI
	sudo ${DNF_CMD} install -y nasm iasl acpica-tools

	# QEmu
	sudo ${DNF_CMD} install -y giflib-devel libpng-devel libtiff-devel gtk3-devel \
	     ncurses-devel gnutls-devel nettle-devel libgcrypt-devel SDL2-devel \
	     libguestfs-devel curl-devel brlapi-devel bluez-libs-devel \
	     libusb-devel libcap-devel libcap-ng-devel libiscsi-devel libnfs-devel \
	     libcacard-devel lzo-devel snappy-devel bzip2-devel libseccomp-devel \
	     libxml2-devel libssh-devel libssh2-devel xfsprogs-devel mesa-libGL-devel \
	     mesa-libGLES-devel mesa-libGLU-devel mesa-libGLw-devel spice-server-devel \
	     libattr-devel libaio-devel libtasn1-devel \
	     gperftools-devel virglrenderer device-mapper-multipath-devel \
	     cyrus-sasl-devel libjpeg-turbo-devel glusterfs-api-devel \
	     libpmem-devel libudev-devel capstone-devel numactl-devel \
	     librdmacm-devel  libibverbs-devel libibumad-devel libvirt-devel \
	     iasl

	# Ceph for QEmu
	sudo ${DNF_CMD} install -y libcephfs-devel librbd-devel \
	     librados2-devel libradosstriper1-devel librbd1-devel

	# for graphviz
	sudo ${DNF_CMD} install -y freeglut-devel guile-devel lua-devel \
	     gtk3-devel lasi-devel poppler-devel librsvg2-devel gd-devel libwebp-devel \
	     libXaw-devel tcl-devel ruby-devel R ocaml php-devel qt5-devel
	
	if [  -e ${DNF_CMD} ]; then	

	    #
	    # For CentOS8
	    #

	    # Go for LLVM bindings for Go lang
	    sudo ${DNF_CMD} module -y install go-toolset:rhel8

	    # LLVM/clang for bootstrap
	    sudo ${DNF_CMD} module -y install llvm-toolset:rhel8
	    sudo ${DNF_CMD} install -y llvm-devel clang-devel
	    
	    # Python2 devel
	    sudo ${DNF_CMD} install -y python2-devel

	    # KVM for QEmu
	    sudo ${DNF_CMD} module -y install virt

	    # for graphviz
	    sudo ${DNF_CMD} install -y libgs-devel

	    # Build dep
	    sudo ${DNF_CMD} builddep -y binutils gcc texinfo-tex texinfo cmake \
		 qemu-kvm-common graphviz

	else

	    #
	    # For CentOS7
	    #
	    
	    # Go for LLVM bindings for Go lang
	    sudo ${YUM_CMD} install -y golang

	    # LLVM/clang for bootstrap
	    sudo ${YUM_CMD} install -y clang
	    sudo ${YUM_CMD} install -y llvm-devel clang-devel
	    
	    # Python2 devel
	    sudo ${YUM_CMD} install -y python-devel

	    # KVM for QEmu
	    sudo ${YUM_CMD} install -y qemu-kvm libvirt virt-install

	    # Xen for QEmu
	    sudo ${YUM_CMD} -y centos-release-xen

	    # for graphviz
	    sudo ${YUM_CMD} install -y --skip-broken libgs-devel
	
	    # Build dep	
	    sudo ${YUM_BUILDDEP_CMD} -y binutils gcc texinfo-tex texinfo cmake qemu-kvm \
		 graphviz
	fi
    fi
}

## begin note
# 機能:ソースアーカイブを収集する
## end note
prepare_archives(){
    local file
    local tmpdir

    echo "@@@ Preparation:fetch-archives @@@"

    mkdir -p ${DOWNLOADDIR}
    pushd ${DOWNLOADDIR}
    for url in ${DOWNLOAD_URLS}
      do
	file=`basename ${url}`
	if [ ! -f ${DOWNLOADDIR}/${file} ]; then
	    echo "Fetch ${url}"
	    wget --no-check-certificate ${url}
	else
	    echo "${file} already exists."
	fi
    done
    popd
}

## begin note
# 機能:コンパイル用のディレクトリを生成する
## end note
create_directories(){

    echo "@@@ Preparation:create-directories @@@"
    
    pushd ${WORKDIR}
    for dir in ${SUBDIRS}
    do
	if [ -d  ${dir} ]; then
	    if [ "x${dir}" != "xdownloads" -a "x${dir}" != "xcross" ]; then
		rm -fr ${dir}
	    fi
	fi

	if [ "x${dir}" != "xcross" ]; then
	    mkdir -p ${dir}
	fi
    done

    mkdir -p ${CROSS_PREFIX}/${TODAY}
    pushd ${CROSS_PREFIX}
    ln -sv ${TODAY} current
    popd

    popd
}

## begin note
# 機能: コマンドのストリップ処理
## end note
do_strip_binaries(){
	local cpu

	if [ -d "${CROSS}" ]; then

	    pushd "${CROSS}"

	    cpu=`uname -m|sed -e 's|_|-|g' -e 's|X86|x86|g'`
	    echo "Build cpu:${cpu}"
	    find .|while read file
	    do
	    file ${file}|grep executable|grep ELF|grep ${cpu} > /dev/null
	    if [ $? -eq 0 ]; then
		echo "${file} is an ELF file on build, try to strip it."
		strip ${file}
	    fi
	    done

	    popd
	fi
}

## begin note
# 機能:構築環境用のbintuils(構築環境用のgccから使用されるbintuils)を作成する
## end note
do_build_binutils_for_build(){

    echo "@@@ BuildTool:binutils @@@"

    extract_archive ${BINUTILS}

    rm -fr ${BUILDDIR}/${BINUTILS}
    mkdir -p ${BUILDDIR}/${BINUTILS}
    pushd  ${BUILDDIR}/${BINUTILS}

    #
    # configureの設定
    #
    # --prefix=${BUILD_TOOLS_DIR}        
    #          ${BUILD_TOOLS_DIR}配下にインストールする
    # --target=${BUILD}
    #          ビルド環境向けのコードを扱うbinutilsを生成する
    # --program-prefix="${BUILD}-"
    #          ターゲット用のコンパイラやシステムにインストールされている
    #          コンパイラと区別するために, プログラムのプレフィクスに
    #          ${BUILD}-をつける。
    # --with-local-prefix=${BUILD_TOOLS_DIR}/${TARGET}
    #        ${BUILD_TOOLS_DIR}/${TARGET}にbinutils内部で使用するファイルを配置する
    # --with-sysroot=/
    #         システム標準のヘッダやライブラリを参照して生成したbinutilsを動作させる
    # --disable-shared                     
    #         共有ライブラリでBFDを作らず, binutils内に内蔵する
    #         (LD_LIBRARY_PATH環境変数を設定せずに使用するために必要)
    # --disable-werror
    #         警告をエラーと見なさない
    # --disable-nls
    #         Native Language Supportを無効化
    #
    ${SRCDIR}/${BINUTILS}/configure            \
	--prefix=${BUILD_TOOLS_DIR}            \
	--target=${BUILD}                      \
	--program-prefix="${BUILD}-"           \
	--with-local-prefix=${BUILD_TOOLS_DIR}/${BUILD}  \
	--with-sysroot=/                       \
	--disable-shared                       \
	--disable-werror                       \
	--disable-nls


    make ${SMP_OPT} 
    ${SUDO} make install

    echo "Remove .la files"
    pushd ${BUILD_TOOLS_DIR}
    find . -name '*.la'|while read file
    do
	echo "Remove ${file}"
	${SUDO} rm -f ${file}
    done
    popd

    popd

    #
    #ビルド環境のツールと混在しないようにする
    #
    pushd ${BUILD_TOOLS_DIR}/bin
    echo "rm addr2line ar as c++filt elfedit gprof ld ld.bfd nm objcopy objdump ranlib readelf size strings strip on ${BUILD_TOOLS_DIR}/bin"
    rm -f addr2line ar as c++filt elfedit gprof ld ld.bfd nm objcopy objdump ranlib readelf size strings strip
    popd
}

## begin note
# 機能:gccのコンパイルに必要なGMP(多桁計算ライブラリ)を生成する
## end note
do_build_gmp(){

    echo "@@@ CompanionLibrary:gmp @@@"

    extract_archive ${GMP}

    mkdir -p ${BUILDDIR}/${GMP}
    pushd  ${BUILDDIR}/${GMP}

    #
    # configureの設定
    #
    # --prefix=${CROSS}        
    #          ${CROSS}配下にインストールする
    # --enable-cxx
    #          gccがC++で書かれているため, c++向けのライブラリを構築する
    # --disable-shared
    # --enable-static
    #         共有ライブラリを作らずgccに対して静的リンクでgmpをリンクさせる
    #         (LD_LIBRARY_PATH環境変数を設定せずに使用するために必要)
    ${SRCDIR}/${GMP}/configure            \
	--prefix=${CROSS}                 \
	--enable-cxx                      \
	--disable-shared                  \
	--enable-static
    
    make ${SMP_OPT} 
    ${SUDO} make install

    echo "Remove .la files"
    pushd ${CROSS}
    find . -name '*.la'|while read file
    do
	echo "Remove ${file}"
	${SUDO} rm -f ${file}
    done
    popd

    popd
}

## begin note
# 機能:gccのコンパイルに必要なMPFR(多桁浮動小数点演算ライブラリ)を生成する
## end note
do_build_mpfr(){

    echo "@@@ CompanionLibrary:mpfr @@@"

    extract_archive ${MPFR}

    mkdir -p ${BUILDDIR}/${MPFR}
    pushd  ${BUILDDIR}/${MPFR}

    #
    # configureの設定
    #
    # --prefix=${CROSS}        
    #          ${CROSS}配下にインストールする
    # --with-gmp=${CROSS}
    #          gmpのインストール先を指定する
    # --disable-shared
    # --enable-static
    #         共有ライブラリを作らずgccに対して静的リンクでmpfrをリンクさせる
    #         (LD_LIBRARY_PATH環境変数を設定せずに使用するために必要)
    #
    ${SRCDIR}/${MPFR}/configure           \
	--prefix=${CROSS}                 \
	--with-gmp=${CROSS}               \
	--disable-shared                  \
	--enable-static
    
    make ${SMP_OPT} 
    ${SUDO} make install

    echo "Remove .la files"
    pushd ${CROSS}
    find . -name '*.la'|while read file
    do
	echo "Remove ${file}"
	${SUDO} rm -f ${file}
    done
    popd

    popd
}

## begin note
# 機能:gccのコンパイルに必要なMPC(多桁複素演算ライブラリ)を生成する
## end note
do_build_mpc(){

    echo "@@@ CompanionLibrary:mpc @@@"

    extract_archive ${MPC}

    mkdir -p ${BUILDDIR}/${MPC}
    pushd  ${BUILDDIR}/${MPC}

    #
    # configureの設定
    #
    # --prefix=${CROSS}        
    #          ${CROSS}配下にインストールする
    #
    # --with-gmp=${CROSS}
    #          gmpのインストール先を指定する
    #
    # --with-mpfr=${CROSS}
    #          mpfrのインストール先を指定する
    #
    # --disable-shared
    # --enable-static
    #         共有ライブラリを作らずgccに対して静的リンクでmpcをリンクさせる
    #         (LD_LIBRARY_PATH環境変数を設定せずに使用するために必要)
    #
    ${SRCDIR}/${MPC}/configure   \
	--prefix=${CROSS}        \
	--with-gmp=${CROSS}      \
	--with-mpfr=${CROSS}     \
	--disable-shared         \
	--enable-static

    make ${SMP_OPT} 
    ${SUDO} make install

    echo "Remove .la files"
    pushd ${CROSS}
    find . -name '*.la'|while read file
    do
	echo "Remove ${file}"
	${SUDO} rm -f ${file}
    done
    popd

    popd
}

## begin note
# 機能:gccのコンパイルに必要なISL(整数集合ライブラリ)を生成する
## end note
do_build_isl(){

    echo "@@@ CompanionLibrary:isl @@@"

    extract_archive ${ISL}

    mkdir -p ${BUILDDIR}/${ISL}
    pushd  ${BUILDDIR}/${ISL}

    #
    # configureの設定
    #
    # --prefix=${CROSS}        
    #          ${CROSS}配下にインストールする
    # --disable-silent-rules
    #          コンパイル時にコマンドラインを表示する
    # --with-gmp=system
    #          インストール済みのGMPを使用する
    # --with-gmp-prefix=${CROSS}
    #          ${CROSS}配下のGMPを使用する
    # --disable-shared
    # --enable-static
    #         共有ライブラリを作らずgccに対して静的リンクでislをリンクさせる
    #         (LD_LIBRARY_PATH環境変数を設定せずに使用するために必要)
    #
    ${SRCDIR}/${ISL}/configure           \
	--prefix=${CROSS}                \
	--disable-silent-rules           \
	--with-gmp=system                \
	--with-gmp-prefix=${CROSS}       \
	--disable-shared                 \
	--enable-static

    make ${SMP_OPT} 
    ${SUDO} make install

    echo "Remove .la files"
    pushd ${CROSS}
    find . -name '*.la'|while read file
    do
	echo "Remove ${file}"
	${SUDO} rm -f ${file}
    done
    popd

    popd
}

## begin note
# 機能: gcc/glibcのコンパイルに必要なlibelf(バックトレース解析処理などに使用)を生成する
## end note
do_build_elfutils(){

    echo "@@@ CompanionLibrary:elfutils @@@"

    extract_archive ${ELFUTILS}

    #
    #--disable-werrorを追加するためにRHELのパッチを適用
    #
    echo "Apply elfutils patches from RHEL"
    pushd ${SRCDIR}/${ELFUTILS}
    patch -p1 < ../../../cross-gcc/patches/elfutils/elfutils-portability.patch
    patch -p1 < ../../../cross-gcc/patches/elfutils/elfutils-robustify.patch
    popd

    mkdir -p ${BUILDDIR}/${ELFUTILS}
    pushd  ${BUILDDIR}/${ELFUTILS}

    #
    # configureの設定
    #
    # --prefix=${CROSS}        
    #          ${CROSS}配下にインストールする
    # --program-prefix="${TARGET}-
    #          システムにインストールされているbinutilsと区別するために, 
    #          プログラムのプレフィクスに${TARGET}-をつける。
    # --enable-cxx
    #          gccがC++で書かれているため, c++向けのライブラリを構築する
    # --enable-compat
    #          互換機能を有効にする(現在のlibelfでは無視される)
    # --enable-elf64
    #          64bitのELFフォーマットの解析を有効にする
    # --enable-extended-format
    #          ELF拡張フォーマットに対応する
    #--disable-werror
    #         警告をエラーと見なさない
    # --disable-shared
    # --enable-static
    #         共有ライブラリを作らずgcc/glibcに対して静的リンクでlibelfをリンクさせる
    #         (LD_LIBRARY_PATH環境変数を設定せずに使用するために必要)
    #
    ${SRCDIR}/${ELFUTILS}/configure       \
	--prefix=${CROSS}                 \
	--program-prefix="${TARGET}-"     \
	--enable-cxx                      \
        --enable-compat                   \
        --enable-elf64                    \
        --enable-extended-format          \
	--disable-werror                  \
	--disable-shared                  \
        --enable-static
    
    make ${SMP_OPT} 
    ${SUDO} make install

    echo "Remove .la files"
    pushd ${CROSS}
    find . -name '*.la'|while read file
    do
	echo "Remove ${file}"
	${SUDO} rm -f ${file}
    done
    popd

    #
    #gccから共有ライブラリ版のlibelfがリンクされないように
    #共有ライブラリを削除する
    #
    if [ -d ${CROSS}/lib ]; then
	echo "Remove shared elf libraries"
	pushd ${CROSS}/lib
	rm -f libasm*.so*
	rm -f libdw*.so*
	rm -f libelf*.so*
	popd
    fi

    if [ -d ${CROSS}/lib64 ]; then
	echo "Remove shared elf 64bit libraries"
	pushd ${CROSS}/lib64
	rm -f libasm*.so*
	rm -f libdw*.so*
	rm -f libelf*.so*
	popd
    fi
    popd
}

## begin note
# 機能: ビルド環境向けのgccを生成する(binutils/gcc/glibcの構築に必要なC/C++までを生成)
## end note
do_build_gcc_for_build(){

    echo "@@@ BuildTool:gcc @@@"

    extract_archive ${GCC}

    pushd ${BUILD_TOOLS_DIR}/bin
    echo "Remove old gcc"
    rm -f ${BUILD}-gcc*
    popd

    rm -fr  ${BUILDDIR}/${GCC}
    mkdir -p ${BUILDDIR}/${GCC}
    pushd  ${BUILDDIR}/${GCC}

    #
    # configureの設定
    #
    #--prefix=${CROSS}
    #          ${CROSS}配下にインストールする
    #--target=${BUILD}
    #          ビルド環境向けのコードを生成する
    #--with-local-prefix=${CROSS}/${BUILD}
    #          gcc内部で使用するファイルを${CROSS}/${BUILD}に格納する
    #--with-sysroot=/
    #          コンパイラの実行時にシステムのルートファイルシステムを優先してヘッダや
    #          ライブラリを探査する
    #--enable-shared
    #          gccの共有ランタイムライブラリを生成する
    #--enable-languages="c,c++"
    #          binutils/gcc/glibcの構築に必要なC/C++までを生成する
    #--disable-bootstrap
    #          ビルド環境もgccを使用することから, 時間削減のためビルド環境とホスト環境が
    #          同一CPUの場合でも, 3stageコンパイルを無効にする
    #--disable-werror
    #         警告をエラーと見なさない
    #--enable-multilib
    #          IA32版UEFI構築用にバイアーキ(32/64bit両対応)版gccの生成する.
    #--enable-lto
    #          UEFI構築に必要なltoプラグインを生成する.
    #--enable-threads=posix
    #          posix threadと連動して動作するようTLS
    #          (スレッドローカルストレージ)を扱う
    #--enable-symvers=gnu
    #          GNUのツールチェインで標準的に使用されるシンボルバージョニング
    #          を行う。
    #--enable-__cxa_atexit
    #          C++の例外処理とatexitライブラリコールとを連動させる
    #--enable-c99
    #          C99仕様を受け付ける
    #--enable-long-long
    #          long long型を有効にする
    #--enable-libmudflap
    #          mudflap( バッファオーバーフロー、メモリリーク、
    #          ポインタの誤使用等を実行時に検出するライブラリ)
    #          を構築する.
    #--enable-libssp
    #           -fstack-protector-all オプションを使えるようにする
    #           (Stack Smashing Protector機能を有効にする)
    #--enable-libgomp
    #           GNU OpenMPライブラリを生成する
    #--disable-libsanitizer
    #           libsanitizerを無効にする(gcc-4.9のlibsanitizerはバグのためコンパイルできないため)
    #--with-gmp=${CROSS}
    #          gmpをインストールしたディレクトリを指定
    #--with-mpfr=${CROSS} 
    #          mpfrをインストールしたディレクトリを指定
    #--with-mpc=${CROSS}
    #          mpcをインストールしたディレクトリを指定
    #--with-isl=${CROSS} 
    #          islをインストールしたディレクトリを指定
    #--with-libelf=${CROSS}
    #          libelfをインストールしたディレクトリを指定
    #--program-prefix="${BUILD}-"
    #          ターゲット用のコンパイラやシステムにインストールされている
    #          コンパイラと区別するために, プログラムのプレフィクスに
    #          ${BUILD}-をつける。
    #${LINK_STATIC_LIBSTDCXX} 
    #          libstdc++を静的リンクしパスに依存せず動作できるようにする
    #
    ${SRCDIR}/${GCC}/configure                               \
	--prefix=${BUILD_TOOLS_DIR}                          \
	--target=${BUILD}                                    \
	--with-local-prefix=${BUILD_TOOLS_DIR}/${BUILD}                \
	--with-build-sysroot=/                               \
	--with-sysroot=/                                     \
	--enable-shared                                      \
	--enable-languages="c,c++"                           \
	--disable-bootstrap                                  \
	--disable-werror                                     \
	--enable-multilib                                    \
	--enable-lto                                         \
	--enable-threads=posix                               \
	--enable-symvers=gnu                                 \
	--enable-__cxa_atexit                                \
	--enable-c99                                         \
	--enable-long-long                                   \
	--enable-libmudflap                                  \
	--enable-libssp                                      \
	--enable-libgomp                                     \
	--disable-libsanitizer                               \
	--with-gmp=${CROSS}                                  \
	--with-mpfr=${CROSS}                                 \
	--with-mpc=${CROSS}                                  \
	--with-isl=${CROSS}                                  \
	--with-libelf=${CROSS}                               \
	--program-prefix="${BUILD}-"                         \
	"${LINK_STATIC_LIBSTDCXX}"                           \
	--with-long-double-128 				     \
	--disable-nls

    make ${SMP_OPT} 
    ${SUDO} make  install
    popd

    echo "Remove .la files"
    pushd ${CROSS}
    find . -name '*.la'|while read file
    do
	echo "Remove ${file}"
	${SUDO} rm -f ${file}
    done
    popd

    #
    #ホストのgccとの混乱を避けるため以下を削除
    #
    echo "rm cpp gcc gcc-ar gcc-nm gcc-ranlib gcov on ${CROSS}/bin"
    pushd ${CROSS}/bin
    rm -f cpp gcc gcc-ar gcc-nm gcc-ranlib gcov ${TARGET}-cc
    #
    # コンパイラへのリンクを張る
    #
    ln -sf ${TARGET}-gcc ${TARGET}-cc
    popd
}

## begin note
# 機能:lldbに必要なswigを構築する
## end note
do_build_swig_for_build(){

    echo "@@@ BuildTool:swig @@@"
    
    extract_archive ${SWIG}

    rm -fr ${BUILDDIR}/${SWIG}
    mkdir -p ${BUILDDIR}/${SWIG}
    pushd  ${BUILDDIR}/${SWIG}
    ${SRCDIR}/${SWIG}/configure \
	--prefix=${BUILD_TOOLS_DIR}
    gmake ${SMP_OPT}
    gmake install
    popd
}

## begin note
# 機能:llvmをコンパイルするために必要なcmakeを作成する。
## end note
do_build_cmake(){
    local para

    echo "@@@ Build:cmake @@@"

    extract_archive ${CMAKE}
    if [ "x${CPUS}" != "x" ]; then
	para=${CPUS}
    else
	para=1
    fi
    rm -fr ${BUILDDIR}/${CMAKE}
    mkdir -p ${BUILDDIR}/${CMAKE}
    pushd  ${BUILDDIR}/${CMAKE}
    ${SRCDIR}/${CMAKE}/configure \
	--parallel=${para}       \
	--prefix=${CROSS}
    gmake ${SMP_OPT}
    gmake install
    popd
}

## begin note
# 機能:ninjaを作成する。
## end note
do_build_ninja(){

    echo "@@@ BuildTool: ninja @@@"

    mkdir -p ${DOWNLOADDIR}

    if [ "x${FETCH_NINJA}" != 'x' -o ! -d ${DOWNLOADDIR}/ninja ]; then    
	pushd ${DOWNLOADDIR}
	git clone ${NINJA_URL}
	pushd ninja
	git checkout release
	popd
	popd
    fi

    if [ "x${FORCE_COPY_SOURCES}" != "x" ]; then
	if [ -d ${SRCDIR}/ninja ]; then
	    rm -fr ${SRCDIR}/ninja
	fi
	cp -a ${DOWNLOADDIR}/ninja ${SRCDIR}/ninja
    fi

    if [ -d ${BUILDDIR}/ninja ]; then
	rm -fr ${BUILDDIR}/ninja
    fi

    if [ "x${FORCE_COPY_SOURCES}" != "x" ]; then
	cp -a ${SRCDIR}/ninja ${BUILDDIR}/ninja
    else
	cp -a ${DOWNLOADDIR}/ninja ${BUILDDIR}/ninja
    fi
    pushd ${BUILDDIR}/ninja
    python2 ./configure.py --bootstrap
    mkdir -p ${CROSS}/bin
    sudo cp ninja ${CROSS}/bin

    popd
}

## begin note
# 機能:z3(定理証明ツール)を作成する。
## end note
do_build_z3(){

    echo "@@@ BuildTool: z3 @@@"

    extract_archive ${Z3}

    rm -fr ${BUILDDIR}/${Z3}
    cp -a ${SRCDIR}/z3-${Z3} ${BUILDDIR}/${Z3}
    pushd  ${BUILDDIR}/${Z3}

    #
    #z3の構築
    #
    python3 scripts/mk_make.py \
	--prefix=${CROSS}
    pushd build
    gmake ${SMP_OPT} 
    ${SUDO} gmake install
    popd
    popd
}

## begin note
#  機能: LLVMのソースを取得する
## end note
fetch_llvm_src(){

    echo "@@@ Fetch sources @@@"

    if [ -d ${DOWNLOADDIR}/llvm-project ]; then
	rm -fr ${DOWNLOADDIR}/llvm-project
    fi
    pushd  ${DOWNLOADDIR}
    git clone https://github.com/llvm/llvm-project.git    
    popd
}

## begin note
# 機能:llvmをコンパイルするためのllvmを構築する
## end note
do_build_llvm(){
    local llvm_src

    echo "@@@ Build LLVM @@@"

    if [ "x${FORCE_COPY_SOURCES}" != "x" ]; then
	llvm_src=${SRCDIR}/llvm-project
    else
	llvm_src=${DOWNLOADDIR}/llvm-project
    fi

    if [ "x${FORCE_COPY_SOURCES}" != "x" ]; then
	if [ -d ${SRCDIR}/llvm-project -o -e ${SRCDIR}/llvm-project ]; then
	    rm -fr ${SRCDIR}/llvm-project 
	fi
	mkdir -p ${SRCDIR}

	cp -a ${DOWNLOADDIR}/llvm-project ${SRCDIR}/llvm-project
    fi

    if [ -d ${BUILDDIR}/llvm-build ]; then
	rm -fr ${BUILDDIR}/llvm-build
    fi

    mkdir -p ${BUILDDIR}/llvm-build

    pushd  ${BUILDDIR}/llvm-build
    cmake -G  "${LLVM_BUILD_TYPE}"                \
    	-DCMAKE_BUILD_TYPE=Release                \
    	-DCMAKE_INSTALL_PREFIX=${CROSS}           \
	-DLLVM_ENABLE_LIBCXX=ON                   \
	-DCMAKE_C_COMPILER=${BUILD}-gcc           \
	-DCMAKE_CXX_COMPILER=${BUILD}-g++         \
	-DLLVM_ENABLE_PROJECTS="${LLVM_PROJECTS}" \
	${llvm_src}/llvm

    if [ "x${NO_NINJA}" = "x" ]; then
	ninja -v ${SMP_OPT}
    else
	gmake ${SMP_OPT} VERBOSE=1
    fi
    #
    #pythonライブラリのパスの誤りを修正
    #See: https://zhuanlan.zhihu.com/p/40793869
    #
    if [ -d lib64/${PYTHON_VER} -a ! -d lib/${PYTHON_VER} ]; then
	echo "@@@ Copy python libs @@@"
	cp -a lib64/${PYTHON_VER} lib
    fi

    if [ "x${NO_NINJA}" = "x" ]; then
	ninja install
    else
	gmake install
    fi

    popd
}

## begin note
# 機能:llvmをclang++でコンパイルする
# lldbが要求する標準C++ライブラリの機能をCentOS版libstdc++は満たさないため
# 再コンパイルが必要
## end note
do_build_llvm_with_clangxx(){
    local llvm_src

    echo "@@@ Build LLVM with clang++ @@@"

    if [ "x${FORCE_COPY_SOURCES}" != "x" ]; then
	llvm_src=${SRCDIR}/llvm-project
    else
	llvm_src=${DOWNLOADDIR}/llvm-project
    fi

    if [ "x${FORCE_COPY_SOURCES}" != "x" ]; then
	if [ -d ${SRCDIR}/llvm-project -o -e ${SRCDIR}/llvm-project ]; then
	    rm -fr ${SRCDIR}/llvm-project 
	fi
	mkdir -p ${SRCDIR}

	cp -a ${DOWNLOADDIR}/llvm-project ${SRCDIR}/llvm-project
    fi

    if [ -d ${BUILDDIR}/llvm-build ]; then
	rm -fr ${BUILDDIR}/llvm-build
    fi

    mkdir -p ${BUILDDIR}/llvm-build

    pushd ${BUILDDIR}/llvm-build

    cmake -G  "${LLVM_BUILD_TYPE}"                     \
    	-DCMAKE_BUILD_TYPE=Release                     \
    	-DCMAKE_INSTALL_PREFIX="${CROSS}"              \
	-DLLVM_ENABLE_LIBCXX=ON                        \
	-DLLVM_ENABLE_PROJECTS="${LLVM_PROJECTS}"      \
	-DCMAKE_C_COMPILER="${CROSS}/bin/clang"        \
	-DCMAKE_CXX_COMPILER="${CROSS}/bin/clang++"    \
	"${llvm_src}/llvm"

    if [ "x${NO_NINJA}" = "x" ]; then
	ninja -v ${SMP_OPT}
    else
	gmake ${SMP_OPT}
    fi
    #
    #pythonライブラリのパスの誤りを修正
    #See: https://zhuanlan.zhihu.com/p/40793869
    #
    if [ -d lib64/${PYTHON_VER} -a ! -d lib/${PYTHON_VER} ]; then
	echo "@@@ Copy python libs @@@"
	cp -a lib64/${PYTHON_VER} lib
    fi

    if [ "x${NO_NINJA}" = "x" ]; then
	ninja install
    else
	gmake install
    fi

    popd
}

## begin note
# 機能:実行環境エミュレータを生成する
## end note
do_build_emulator(){
    local glibcflags
    local glibldflags

    echo "@@@ Emulator @@@"

    extract_archive ${QEMU}

    rm -fr  ${BUILDDIR}/${QEMU}
    cp -a  ${SRCDIR}/${QEMU} ${BUILDDIR}/${QEMU}
    pushd  ${BUILDDIR}/${QEMU}

    mkdir build
    pushd build

    CC="clang"                           \
    CXX="clang++"                        \
    AR="llvm-ar"                         \
    LD="lld"                             \
    RANLIB="llvm-ranlib"                 \
    ../configure                         \
     --prefix=${CROSS}                   \
     --interp-prefix=${SYSROOT}          \
     --enable-system                     \
     ${QEMU_CONFIG_USERLAND}             \
     --enable-tcg-interpreter            \
     --enable-modules                    \
     --enable-debug-tcg                  \
     --enable-debug-info                 \
     ${QEMU_CONFIG_MEMBARRIER}           \
     --enable-profiler                   \
     --disable-pie                       \
     --disable-werror
    
    make ${SMP_OPT} V=1
    ${SUDO} make V=1 install

    echo "Remove .la files"
    pushd ${CROSS}
    find . -name '*.la'|while read file
    do
	echo "Remove ${file}"
	${SUDO} rm -f ${file}
    done
    popd

    popd

    popd
}

main(){

    setup_variables

    show_info

    if [ "x${NO_DEVENV}" = 'x' ]; then
    	prepare_devenv
    fi

    cleanup_directories

    create_directories

    prepare_archives

    do_build_binutils_for_build
    do_build_gmp
    do_build_mpfr
    do_build_mpc
    do_build_isl
    do_build_elfutils
    do_build_gcc_for_build

    do_build_swig_for_build
    
    if [ "x${FORCE_FETCH_LLVM}" != 'x' -o ! -d ${DOWNLOADDIR}/llvm-project ]; then    
      	fetch_llvm_src
    fi
    
    if [ "x${NO_CMAKE}" = 'x' ]; then    
       	do_build_cmake
    fi
    
    if [ "x${NO_NINJA}" = "x" ]; then
      	do_build_ninja
    else
      	echo "Skip build ninja"
    fi
    
    if [ "x${NO_Z3}" = 'x' ]; then
       	do_build_z3    
    fi
    
    if [ "x${NO_LLVM}" = 'x' ]; then
	
      	do_build_llvm
	
    fi
    
    if [ "x${NO_LLVM}" = 'x' -o "x${USE_HOST_CC}" = 'x' ]; then
	
      	do_build_llvm_with_clangxx
    fi

    if [ "x${NO_SIM}" = 'x' ]; then
    	do_build_emulator
    fi
    
    if [ "x${NO_STRIP}" = 'x' ]; then
     	do_strip_binaries
    fi
    
    if [ "x${NO_CLEAN_DIR}" = 'x' ]; then    
    	cleanup_temporary_directories
    fi
}

main $@
