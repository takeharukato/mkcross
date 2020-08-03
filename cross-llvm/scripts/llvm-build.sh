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

#エラーメッセージの文字化けを避けるためにCロケールで動作させる
LANG=C

if [ $# -ne 1 ]; then
    echo "build.sh environment-def.sh"
    exit 1
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
    LD_LIBRARY_PATH=${CROSS}/lib

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
	    sudo ${DNF_CMD} config-manager --set-enabled epel
	    sudo ${DNF_CMD} config-manager --set-enabled epel-modular
	    sudo ${DNF_CMD} config-manager --set-enabled extras
	    sudo ${DNF_CMD} install -y dnf-plugins-core \
		 dnf-plugins-extras-repoclosure dnf-plugins-extras-repograph \
		 dnf-plugins-extras-repomanage dnf-plugins-extras-debug \
		 dnf-plugins-extras-debug 
	else
	    DNF_CMD=/bin/yum
	    sudo ${YUM_CMD} install -y yum-priorities epel-release yum-utils	    	    
	fi

	# Basic commands
	sudo ${DNF_CMD} install -y sudo passwd bzip2 patch nano which tar xz	

	# Build tools
	sudo ${DNF_CMD} groupinstall -y "Development tools"

	# Prerequisites header/commands for GCC
	sudo ${DNF_CMD} install -y glibc-devel binutils gcc bash gawk \
	     gzip bzip2-devel make tar perl
	sudo ${DNF_CMD} install -y m4 automake autoconf gettext gperf \
	     autogen guile texinfo texinfo-tex texlive texlive* \
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
	     libxml2-devel libssh2-devel xfsprogs-devel mesa-libGL-devel \
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
	
	if [  -e ${DNF_CMD} ]; then	

	    #
	    # For CentOS8
	    #

	    # Go for LLVM bindings for Go lang
	    sudo ${DNF_CMD} module -y install go-toolset:rhel8

	    # LLVM/clang for bootstrap
	    sudo ${DNF_CMD} module -y install llvm-toolset:rhel8

	    # Python2 devel
	    sudo ${DNF_CMD} install -y python2-devel

	    # KVM for QEmu
	    sudo ${DNF_CMD} module -y install virt

	    # Build dep
	    sudo ${DNF_CMD} builddep -y binutils gcc texinfo-tex texinfo cmake qemu-kvm-common

	else

	    #
	    # For CentOS7
	    #
	    
	    # Go for LLVM bindings for Go lang
	    sudo ${YUM_CMD} install -y golang

	    # LLVM/clang for bootstrap
	    sudo ${YUM_CMD} install -y clang

	    # Python2 devel
	    sudo ${YUM_CMD} install -y python-devel

	    # KVM for QEmu
	    sudo ${YUM_CMD} install -y qemu-kvm libvirt virt-install

	    # Xen for QEmu
	    sudo ${YUM_CMD} -y centos-release-xen
	
	    # Build dep	
	    sudo ${YUM_BUILDDEP_CMD} -y binutils gcc texinfo-tex texinfo cmake qemu-kvm

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
#  機能: LLVMのソースを取得する
## end note
fetch_llvm_src(){

    echo "@@@ Fetch sources @@@"

    if [ -d ${DOWNLOADDIR}/llvm-current ]; then
	rm -fr ${DOWNLOADDIR}/llvm-current
    fi
    mkdir -p ${DOWNLOADDIR}/llvm-current

    pushd  ${DOWNLOADDIR}/llvm-current
    # #
    # #See
    # #https://www.hiroom2.com/2016/05/28/centos-7-%E3%83%AA%E3%83%9D%E3%82%B8%E3%83%88%E3%83%AA%E3%81%AEllvm-clang%E3%82%92%E3%83%93%E3%83%AB%E3%83%89%E3%81%97%E3%81%A6%E3%82%A4%E3%83%B3%E3%82%B9%E3%83%88%E3%83%BC%E3%83%AB%E3%81%99%E3%82%8B/ 
    # #
    svn co http://llvm.org/svn/llvm-project/llvm/trunk llvm
    cd llvm/tools
    svn co http://llvm.org/svn/llvm-project/cfe/trunk clang
    svn co http://llvm.org/svn/llvm-project/lld/trunk lld
    svn co http://llvm.org/svn/llvm-project/lldb/trunk lldb
    git clone http://llvm.org/git/polly.git polly
    cd clang/tools
    svn co http://llvm.org/svn/llvm-project/clang-tools-extra/trunk extra
    cd ../../../projects
    svn co http://llvm.org/svn/llvm-project/libcxx/trunk    libcxx
    svn co http://llvm.org/svn/llvm-project/libcxxabi/trunk libcxxabi
    svn co http://llvm.org/svn/llvm-project/compiler-rt/trunk compiler-rt
    svn co http://llvm.org/svn/llvm-project/openmp/trunk openmp
    cd ../..
    popd
}

## begin note
# 機能:llvmをコンパイルする
## end note
do_build_llvm(){
    local llvm_src

    echo "@@@ Build LLVM @@@"

    if [ "x${FORCE_COPY_SOURCES}" != "x" ]; then
	llvm_src=${SRCDIR}/llvm-current
    else
	llvm_src=${DOWNLOADDIR}/llvm-current
    fi

    if [ "x${FORCE_COPY_SOURCES}" != "x" ]; then
	if [ -d ${SRCDIR}/llvm-current -o -e ${SRCDIR}/llvm-current ]; then
	    rm -fr ${SRCDIR}/llvm-current 
	fi
	mkdir -p ${SRCDIR}

	cp -a ${DOWNLOADDIR}/llvm-current ${SRCDIR}/llvm-current
    fi

    if [ -d ${BUILDDIR}/llvm-current ]; then
	rm -fr ${BUILDDIR}/llvm-current
    fi

    mkdir -p ${BUILDDIR}/llvm-current

    pushd  ${BUILDDIR}/llvm-current
    cmake -G  "${LLVM_BUILD_TYPE}"      \
    	-DCMAKE_BUILD_TYPE=Release      \
    	-DCMAKE_INSTALL_PREFIX=${CROSS} \
	-DLLVM_ENABLE_LIBCXX=ON         \
	${llvm_src}/llvm

    if [ "x${NO_NINJA}" = "x" ]; then
	ninja ${SMP_OPT}
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
# 機能:llvmをclang++でコンパイルする
# lldbが要求する標準C++ライブラリの機能をCentOS版libstdc++は満たさないため
# 再コンパイルが必要
## end note
do_build_llvm_with_clangxx(){
    local llvm_src

    echo "@@@ Build LLVM with clang++ @@@"

    if [ "x${FORCE_COPY_SOURCES}" != "x" ]; then
	llvm_src=${SRCDIR}/llvm-current
    else
	llvm_src=${DOWNLOADDIR}/llvm-current
    fi

    if [ "x${FORCE_COPY_SOURCES}" != "x" ]; then
	if [ -d ${SRCDIR}/llvm-current -o -e ${SRCDIR}/llvm-current ]; then
	    rm -fr ${SRCDIR}/llvm-current 
	fi
	mkdir -p ${SRCDIR}

	cp -a ${DOWNLOADDIR}/llvm-current ${SRCDIR}/llvm-current
    fi

    if [ -d ${BUILDDIR}/llvm-current ]; then
	rm -fr ${BUILDDIR}/llvm-current
    fi

    mkdir -p ${BUILDDIR}/llvm-current

    pushd  ${BUILDDIR}/llvm-current
    cmake -G  "${LLVM_BUILD_TYPE}"                     \
    	-DCMAKE_BUILD_TYPE=Release                     \
    	-DCMAKE_INSTALL_PREFIX=${CROSS}                \
	-DLLVM_ENABLE_LIBCXX=ON                        \
	-DCMAKE_C_COMPILER="${CROSS}/bin/clang"        \
	-DCMAKE_CXX_COMPILER="${CROSS}/bin/clang++"    \
	${llvm_src}/llvm

    if [ "x${NO_NINJA}" = "x" ]; then
	ninja ${SMP_OPT}
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
# 機能:エミュレータを生成する
## end note
do_build_emulator(){
    local glibcflags
    local glibldflags

    echo "@@@ Emulator @@@"

    extract_archive ${QEMU}

    rm -fr  ${BUILDDIR}/${QEMU}
    cp -a  ${SRCDIR}/${QEMU} ${BUILDDIR}/${QEMU}
    pushd  ${BUILDDIR}/${QEMU}

    CC="clang"                           \
    CXX="clang++"                        \
    AR="ar"                              \
    LD="ld"                              \
    RANLIB="ranlib"                      \
    ./configure                          \
     --prefix=${CROSS}                   \
     --enable-system                     \
     ${QEMU_CONFIG_USERLAND}             \
     --enable-tcg-interpreter            \
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

    if [ "x${FETCH_LLVM}" != 'x' -o ! -d ${DOWNLOADDIR}/llvm-current ]; then    
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
