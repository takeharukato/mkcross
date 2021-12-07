#
# -*- coding:utf-8 mode:bash -*-
#

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
unset QEMU_CONFIG_USERLAND
unset HOSTCC
unset KERN_MAJOR
unset KERN_MINOR
unset KERN_REV
unset CC_FOR_QEMU_BUILD
unset CXX_FOR_QEMU_BUILD
unset LD_FOR_QEMU_BUILD
unset AR_FOR_QEMU_BUILD
unset RANLIB_FOR_QEMU_BUILD

#エラーメッセージの文字化けを避けるためにCロケールで動作させる
LANG=C
if [ "x${SCRIPT_DIR}" != "x" -a -f "${SCRIPT_DIR}/../../common/env/common-env.sh" ]; then
    echo "Load ${SCRIPT_DIR}/../../common/env/common-env.sh"
    source "${SCRIPT_DIR}/../../common/env/common-env.sh"
fi

## begin
#  環境変数の設定を行う
## end
setup_variables(){

    echo "@@@ Setup variables @@@"
    TODAY=`date "+%F"`

    RTLD=/lib64/ld-2.17.so

    OSNAME=`uname`

    if [ "x${SCRIPT_DIR}" = "x" ]; then
	echo "Error: SCRIPT_DIR is not set"
	exit 1
    fi

    if [ "x${_LIB}" = "x" ]; then

	echo "@@@ _LIB is not set, we assume _LIB is lib64. "
	_LIB=lib64
    fi

    if [ "x${TOOLCHAIN_TYPE}" != "xLinux" -a "x${TOOLCHAIN_TYPE}" != "xELF" -a "x${TOOLCHAIN_TYPE}" != "xLLVM" ]; then
	echo "Error: unknown tool chain type: ${TOOLCHAIN_TYPE}"
	exit 1
    fi

    if [ "${TOOLCHAIN_TYPE}" = "Linux" ]; then
	CROSS_SUBDIR="gcc"
    fi

    if [ "${TOOLCHAIN_TYPE}" = "ELF" ]; then
	CROSS_SUBDIR="gcc-elf"
    fi

    if [ "${TOOLCHAIN_TYPE}" = "LLVM" ]; then
	CROSS_SUBDIR="llvm"
    fi

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

    if [ "x${TOOLCHAIN_TYPE}" != "xLLVM" ]; then

	if [  "x${TOOLCHAIN_TYPE}" != "xELF" ]; then

	    if [ "x${TARGET}" = "x"  ]; then
		TARGET=${TARGET_CPU}-unknown-linux-gnu
	    fi
	else
	    if [ "x${TARGET_ELF}" != "x" ]; then
		    TARGET=${TARGET_ELF}
	    else
		    TARGET=${TARGET_CPU}-elf
	    fi
	fi
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

    if [ "x${HOST}" = "x" ]; then
	HOST=${TARGET}
    fi

    BUILD_CPU=`echo "${BUILD}"|cut -d'-' -f1`

    if [ "x${TARGET_CPU}" != "x${BUILD_CPU}" ]; then
	PROGRAM_PREFIX=""
    else
	PROGRAM_PREFIX="--program-prefix=${TARGET}-"
    fi

    if [ "x${QEMU_SOFTMMU_TARGETS}" = "x" -a "x${TOOLCHAIN_TYPE}" != "xLLVM" ]; then
	QEMU_SOFTMMU_TARGETS="${QEMU_CPU}-softmmu"
    fi

    if [ "x${TOOLCHAIN_TYPE}" != "xLLVM" ]; then

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

	    if [ "x${TOOLCHAIN_TYPE}" != "xLLVM" ]; then
		QEMU_TARGETS="${QEMU_SOFTMMU_TARGETS},${QEMU_CPU}-linux-user"
	    fi
	else
	    if [ "x${QEMU_CPU}" = "xx86_64" -o "x${QEMU_CPU}" = "xi386" ]; then
		QEMU_CONFIG_USERLAND="--enable-user --enable-bsd-user"
		QEMU_TARGETS="${QEMU_CPU}-bsd-user"
		if [ "x${TOOLCHAIN_TYPE}" != "xLLVM" ]; then
		    QEMU_TARGETS="${QEMU_SOFTMMU_TARGETS},${QEMU_CPU}-bsd-user"
		fi
	    fi
	fi
    else
	QEMU_TARGETS=""
    fi
    if [ "x${QEMU_TARGETS}" != "x" ]; then
	QEMU_CONFIG_TARGETS="--target-list=${QEMU_TARGETS}"
    else
	QEMU_CONFIG_TARGETS=""
    fi


    #パッチ格納先ディレクトリ
    PATCHDIR=${SCRIPT_DIR}/../patches

    #テストプログラム格納ディレクトリ
    TESTDIR=${SCRIPT_DIR}/../../tests

    #カレントディレクトリ配下で構築作業を進める
    WORKDIR=`pwd`

    #カレントディレクトリ直下のディレクトリのリスト
    SUBDIRS="downloads build src cross tools"

    #ソース展開先ディレクトリ
    SRCDIR=${WORKDIR}/src

    #構築ディレクトリ
    #binutils/gcc/glibcは, ソースを展開したディレクトリと別の
    #ディレクトリで構築を進めるルールになっているためsrcとは別のディレクトリを
    #用意する
    BUILDDIR=${WORKDIR}/build

    #アーカイブダウンロードディレクトリ
    DOWNLOADDIR=${WORKDIR}/downloads

    #ビルドツールディレクトリ
    BUILD_TOOLS_DIR=${WORKDIR}/tools

    #クロスコンパイラやクロス環境向けのヘッダ・ライブラリを格納するディレクトリ
    if [ "x${CROSS_PREFIX}" = "x" ]; then
	if [ "${TOOLCHAIN_TYPE}" = "LLVM" ]; then
	    CROSS_PREFIX=${HOME}/cross/${CROSS_SUBDIR}
	else
	    CROSS_PREFIX=${HOME}/cross/${CROSS_SUBDIR}/${TARGET_CPU}
	fi
    fi
    CROSS=${CROSS_PREFIX}/${TODAY}

    #
    #QEmu動作に必要なライブラリを格納するディレクトリ
    #
    QEMU_BUILD_RFS=${CROSS}/${BUILD}

    #構築済みのヘッダやライブラリを格納するディレクトリ
    #クロスコンパイラは, 本ディレクトリをルートディレクトリと見なして,
    #このディレクトリ配下の/usr/includeのヘッダ,/lib64, /usr/lib64配下のライブラリ
    #を参照するように, binutils, gccのconfigureの--with-sysrootオプションで
    #本ディレクトリを設定する.
    #ビルド用のコンパイラ(binutils/gcc)は,
    #--with-sysrootオプションで/を設定する。
    #この設定を忘れると, ホストのヘッダやライブラリを見に行けなくなり、
    #ビルド用のコンパイラとして動作しない。
    SYSROOT=${CROSS}/rfs
    WITH_SYSROOT=--with-sysroot=${SYSROOT}

    #RHEL6環境でも動作するようにglibcのカーネル動作範囲を2.6.18に指定
    GLIBC_ENABLE_KERNEL=2.6.18

    #
    #libstdc++を静的リンクしパスに依存せず動作できるようにする
    #
    LINK_STATIC_LIBSTDCXX="--with-host-libstdcxx=\'-lstdc++ -lm -lgcc_eh\'"

    #
    #パスの設定
    #
    OLD_PATH=${PATH}
    SAFE_PATH=/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/bin:/sbin
    PATH=${BUILD_TOOLS_DIR}/bin:${CROSS}/bin:${SAFE_PATH}:${PATH}
    LD_LIBRARY_PATH=${CROSS}/lib64:${CROSS}/lib:${BUILD_TOOLS_DIR}/lib64:${BUILD_TOOLS_DIR}/lib

    export PATH
    export LD_LIBRARY_PATH
}

## begin
# 環境情報を表示する
## end
show_info(){

    echo "@@@ Build information @@@"
    echo "Tool chain type: ${TOOLCHAIN_TYPE}"
    echo "Build: ${BUILD}"
    echo "Target: ${TARGET}"
    echo "Host: ${HOST}"
    echo "Build OS: ${OSNAME}"

    if [ "x${TOOLCHAIN_TYPE}" != "xLLVM" -o "x${NO_NINJA}" != "x" ]; then
	echo "Build with: make"
    else
	if [ "x${NO_NINJA}" = "x" ]; then
	    echo "Build with: ninja"
	fi
    fi

    if [ "x${SMP_OPT}" != "x" ]; then
	echo "SMP_OPT: ${SMP_OPT}"
    else
	echo "SMP_OPT: None"
    fi

    if [ "x${QEMU_CONFIG_USERLAND}" != "x" ]; then
	echo "QEMU Userland: ${QEMU_CONFIG_USERLAND}"
    fi
    echo "QEMU: ${QEMU_TARGETS}"
}

## begin note
# 一時ディレクトリを削除
## end note
cleanup_temporary_directories(){
    local dname

    for dname in build src
    do
	if [ -d "${WORKDIR}" -a -d "${WORKDIR}/${dname}" ]; then
	    echo "Cleanup ${dname}"
	    rm -fr "${WORKDIR}/${dname}"
	fi
    done
}

## begin note
# 機能:クロスコンパイラ構築環境用ディレクトリを作成する
## end note
cleanup_directories() {
    local pname
    local linkname

    echo "@@@ Preparation:CLEANUP-directories @@@"
    cleanup_temporary_directories

    pname=`dirname ${CROSS}`
    linkname=`readlink ${CROSS}`
    if [ -L "${CROSS}" ]; then

	echo "${CROSS} is link"
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
    if [ -f ${WORKDIR}/downloads/${basename}.tar.gz ]; then
	tar zxf ${WORKDIR}/downloads/${basename}.tar.gz
    else
	if [ -f ${WORKDIR}/downloads/${basename}.tar.bz2 ]; then
	    tar jxf ${WORKDIR}/downloads/${basename}.tar.bz2
	else
	    if [ -f ${WORKDIR}/downloads/${basename}.tar.xz ]; then
		tar Jxf ${WORKDIR}/downloads/${basename}.tar.xz
	    fi
	fi
    fi
    popd
}

## begin note
# 機能: gitからedk2のソースを取得する
## end note
fetch_edk2_src() {

    echo "@@@ Fetch EDK2 sources @@@"

    if [ -d ${DOWNLOADDIR}/work-${EDK2} ]; then
	rm -fr ${DOWNLOADDIR}/work-${EDK2}
    fi
    mkdir -p ${DOWNLOADDIR}/work-${EDK2}

    pushd  ${DOWNLOADDIR}/work-${EDK2}

    git clone git@github.com:tianocore/edk2.git

    pushd edk2
    git submodule update --init --recursive
    popd
    mv edk2 ${EDK2}
    tar zcf ${DOWNLOADDIR}/${EDK2}.tar.gz ${EDK2}
    rm -fr  ${EDK2}
    popd

    if [ -d ${DOWNLOADDIR}/work-${EDK2} ]; then
     	rm -fr ${DOWNLOADDIR}/work-${EDK2}
    fi
}

## begin note
#  機能: LLVMのソースを取得する
## end note
fetch_llvm_src(){

    echo "@@@ Fetch llvm sources @@@"

    if [ -d ${DOWNLOADDIR}/llvm-project ]; then
	rm -fr ${DOWNLOADDIR}/llvm-project
    fi
    pushd  ${DOWNLOADDIR}
    git clone https://github.com/llvm/llvm-project.git
    popd
}

## begin note
#  機能: ninjaのソースを取得する
## end note
fetch_ninja_src(){

    echo "@@@ Fetch ninja sources @@@"

    mkdir -p ${DOWNLOADDIR}

    if [ "x${FETCH_NINJA}" != 'x' -o ! -d ${DOWNLOADDIR}/ninja ]; then
	pushd ${DOWNLOADDIR}
	git clone ${NINJA_GIT_REPO}
	pushd ninja
	git checkout release
	popd
	popd
    fi
}

## begin note
# 機能: Ubuntu上で開発環境をそろえる
## end note
prepare_ubuntu_devenv(){
    local APT_GET_CMD=apt-get

    # Emacs/Zsh/Ksh/Utils
    sudo ${APT_GET_CMD} install -y ksh zsh screen emacs aspell aspell-en patchutils curl

    # chsh
    sudo ${APT_GET_CMD} install -y util-linux

    # Basic commands
    sudo ${APT_GET_CMD} install -y sudo passwd bzip2 nano tar xz-utils wget

    # Basic devel
    sudo ${APT_GET_CMD}  install -y build-essential
    # Prerequisites header/commands for GCC/GDB
    sudo ${APT_GET_CMD} install -y gdb bash gawk \
	 gzip bzip2 make tar perl libmpc-dev
    sudo ${APT_GET_CMD} install -y gcc-multilib
    # Linux kernel headers require rsync
    sudo ${APT_GET_CMD} install -y m4 automake autoconf gettext libtool \
	 libltdl-dev gperf autogen guile-3.0 texinfo texlive  \
         python3-sphinx git openssh-server diffutils patch rsync

    # Prerequisites library for GCC
    sudo ${APT_GET_CMD} install -y elfutils \
	          libgmp-dev libmpfr-dev binutils zstd

    # Prerequisites CMake
    sudo ${APT_GET_CMD} install -y openssl

    # Prerequisites for LLVM
    sudo ${APT_GET_CMD} install -y libedit-dev libxml2 cmake

    # Prerequisites for SWIG
    sudo ${APT_GET_CMD} install -y libboost-all-dev

    # Perl modules for cloc
    sudo ${APT_GET_CMD} install -y libalgorithm-diff-perl libregexp-common-perl perl

    # Python
    sudo ${APT_GET_CMD} install -y python3 python3-dev swig

    # Version manager
    sudo ${APT_GET_CMD} install -y git subversion

    # Document commands (flex/bison is installed to build doxygen)
    sudo ${APT_GET_CMD} install -y flex bison
    sudo ${APT_GET_CMD} install -y re2c graphviz doxygen
    sudo ${APT_GET_CMD} install -y docbook-utils docbook-xsl

    # Valrind
    sudo ${APT_GET_CMD} install -y valgrind

    # patchelf
    sudo ${APT_GET_CMD} install -y patchelf

    # For UEFI
    sudo ${APT_GET_CMD} install -y nasm acpica-tools

    # QEmu
    sudo ${APT_GET_CMD} install -y giflib-tools libpng-dev libtiff-dev libgtk-3-dev \
	 libncursesw6 libncurses5-dev libncursesw5-dev libgnutls30 nettle-dev \
	 libgcrypt20-dev libsdl2-dev libguestfs-tools python3-brlapi \
	 bluez-tools bluez-hcidump bluez libusb-dev libcap-dev libcap-ng-dev \
	 libiscsi-dev  libnfs-dev libguestfs-dev libcacard-dev liblzo2-dev \
	 liblzma-dev libseccomp-dev libssh-dev libssh2-1-dev libglu1-mesa-dev \
	 mesa-common-dev freeglut3-dev ngspice-dev libattr1-dev libaio-dev \
	 libtasn1-dev google-perftools libvirglrenderer-dev multipath-tools \
	 libsasl2-dev libpmem-dev libudev-dev libcapstone-dev librdmacm-dev \
	 libibverbs-dev libibumad-dev libvirt-dev libffi-dev libbpfcc-dev libdaxctl-dev

    # Ceph for QEmu
    sudo ${APT_GET_CMD} install -y libcephfs-dev librbd-dev librados-dev

    # Fuse
    sudo ${APT_GET_CMD} install -y fuse3 libfuse3-dev

    # for graphviz
    sudo ${APT_GET_CMD} install -y libglu1-mesa-dev mesa-common-dev freeglut3-dev guile-3.0 lua5.3  liblasi-dev poppler-utils librsvg2-bin librsvg2-dev libgd-dev libwebp-dev \
	          libxaw7-dev tcl ruby r-base ocaml php qt5-default

    # for iso image operation
    sudo ${APT_GET_CMD} install -y xorriso

    # for ghostscript
    sudo ${APT_GET_CMD} install -y liblcms2-dev libjpeg-dev libfreetype6-dev \
	 libpng-dev libpaper-dev

    #
    #True Type Font
    #
    sudo ${APT_GET_CMD} install -y fonts-noto-cjk

    # Go for LLVM bindings for Go lang
    sudo ${APT_GET_CMD} install -y golang
    # LLVM/clang for bootstrap
    sudo ${APT_GET_CMD} install -y llvm-12 clang-12

    # Ruby
    sudo ${APT_GET_CMD} install -y ruby

    # Java
    sudo ${APT_GET_CMD} install -y default-jdk default-jre

    # Scala
    sudo ${APT_GET_CMD} install -y scala

    # mercurial
    sudo ${APT_GET_CMD} install -y mercurial

    # Rust
    sudo ${APT_GET_CMD} install -y rustc cargo

    # Python2 devel
    sudo ${APT_GET_CMD} install -y python2

    # KVM for QEmu
    sudo ${APT_GET_CMD}  install -y virt-manager

}

## begin note
# 機能:開発環境をそろえる
## end note
prepare_devenv(){
    local DNF_CMD=/bin/dnf
    local YUM_CMD=/bin/yum
    local YUM_BUILDDEP_CMD=yum-builddep
    local osname
    local is_ubuntu

    echo "@@@ Prepare development environment @@@"

    osname=`uname`
    if [ "x${osname}" = "xLinux" ]; then

	grep -i Ubuntu /etc/issue > /dev/null
	is_ubuntu=$?

	if [ ${is_ubuntu} -eq 0 ]; then
	    echo "Set up developer's environment for Ubuntu"
	    prepare_ubuntu_devenv
	else
	    if [ -e /bin/dnf ]; then

		sudo ${DNF_CMD} config-manager --set-enabled baseos
		# clang needs AppStream
		sudo ${DNF_CMD} config-manager --set-enabled appstream
		sudo ${DNF_CMD} config-manager --set-enabled powertools

		sudo ${DNF_CMD} config-manager --set-enabled extras
		sudo ${DNF_CMD} config-manager --set-enabled plus
		sudo ${DNF_CMD} config-manager --set-enabled plus-source

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

	    # linux kernel headers require rsync.
	    sudo ${DNF_CMD} install -y rsync

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

	    if [  -e /bin/dnf ]; then

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
	    if [ "x${dir}" != "xdownloads" -a "x${dir}" != "xcross" -a "x${dir}" != "xtools" ]; then
		rm -fr ${dir}
	    fi
	fi

	if [ "x${dir}" != "xcross" -a "x${dir}" != "xtools" ]; then
	    mkdir -p ${dir}
	fi

	if [ "${dir}" = "tools" ]; then

	    if [ "x${SKIP_BUILD_TOOLS}" != "x" -a -d "${BUILD_TOOLS_DIR}" ]; then
		echo "Skip building tools for build"
	    else
		# prepare_buildtoolsでtoolsディレクトリの存在確認をするので
		# 削除後にtoolsディレクトリを作らない
		rm -fr "${BUILD_TOOLS_DIR}"
	    fi
	fi
    done

    mkdir -p ${CROSS_PREFIX}/${TODAY}

    popd
}

## begin note
# 機能:クロスコンパイル環境へのシンボリックリンクを作成する
## end note
create_symlink(){

    echo "@@@ Update the symlink for cross tools  @@@"

    rm -f ${CROSS_PREFIX}/current
    pushd ${CROSS_PREFIX}
    ln -sv ${TODAY} current
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
# 機能:xzを展開するために必要なGNU tar-1.22以降を作成する。
#      RHEL7環境に合わせて, tar-1.26を導入。
## end note
do_build_gtar_for_build(){

    echo "@@@ BuildTool:gtar @@@"

    extract_archive ${GTAR}

    rm -fr ${BUILDDIR}/${GTAR}
    mkdir -p ${BUILDDIR}/${GTAR}
    pushd  ${BUILDDIR}/${GTAR}

    #
    # configureの設定
    #
    # --prefix=${BUILD_TOOLS_DIR}
    #          ${BUILD_TOOLS_DIR}配下にインストールする
    # --disable-silent-rules
    #          コンパイル時のコマンドラインを表示する
    # --program-prefix="${BUILD}-"
    #          ターゲット用のコンパイラやシステムにインストールされている
    #          コンパイラと区別するために, プログラムのプレフィクスに
    #          ${BUILD}-をつける。
    #
    ${SRCDIR}/${GTAR}/configure               \
	--prefix=${BUILD_TOOLS_DIR}           \
	--disable-silent-rules                \
	--program-prefix="${BUILD}-"

    make ${SMP_OPT}
    ${SUDO} make install
    popd

    #
    #ビルド環境のmakeより優先的に使用されるように
    #make, gmakeへのシンボリックリンクを張る
    #
    if [ -e ${BUILD_TOOLS_DIR}/bin/${BUILD}-make ]; then
	pushd ${BUILD_TOOLS_DIR}/bin
	rm -f tar gtar
	ln -sv ${BUILD}-tar tar
	ln -sv ${BUILD}-tar gtar
	popd
    fi
}

## begin note
# 機能:glibc-2.17をコンパイルするために必要なGNU make-3.82以降を作成する。
#      gmake-3.81以前（RHEL6環境）では, 以下のようなエラーになる
#      ため, RHEL6環境でのクロスコンパイラを使用するために導入。
#
#      make[3]: *** No rule to make target `elf/soinit.c', needed by glibc-2.17-36-rhel7/elf/soinit.os
#
## end note
do_build_gmake_for_build(){


    echo "@@@ BuildTool:gmake @@@"

    extract_archive ${GMAKE}

    rm -fr ${BUILDDIR}/${GMAKE}
    mkdir -p ${BUILDDIR}/${GMAKE}
    pushd  ${BUILDDIR}/${GMAKE}

    #
    # configureの設定
    #
    # --prefix=${BUILD_TOOLS_DIR}
    #          ${BUILD_TOOLS_DIR}配下にインストールする
    # --program-prefix="${BUILD}-"
    #          ターゲット用のコンパイラやシステムにインストールされている
    #          コンパイラと区別するために, プログラムのプレフィクスに
    #          ${BUILD}-をつける。
    #
    ${SRCDIR}/${GMAKE}/configure               \
	--prefix=${BUILD_TOOLS_DIR}            \
	--program-prefix="${BUILD}-"

    make ${SMP_OPT}
    ${SUDO} make install
    popd

    #
    #ビルド環境のmakeより優先的に使用されるように
    #make, gmakeへのシンボリックリンクを張る
    #
    if [ -e ${BUILD_TOOLS_DIR}/bin/${BUILD}-make ]; then
	pushd ${BUILD_TOOLS_DIR}/bin
	rm -f make gmake
	ln -sv ${BUILD}-make make
	ln -sv ${BUILD}-make gmake
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
# 機能:ビルド用gccのコンパイルに必要なGMP(多桁計算ライブラリ)を生成する
## end note
do_build_gmp_for_build(){

    echo "@@@ BuildTool:gmp @@@"

    extract_archive ${GMP}

    mkdir -p ${BUILDDIR}/${GMP}
    pushd  ${BUILDDIR}/${GMP}

    #
    # configureの設定
    #
    # --prefix=${BUILD_TOOLS_DIR}
    #          ${BUILD_TOOLS_DIR}配下にインストールする
    # --enable-cxx
    #          gccがC++で書かれているため, c++向けのライブラリを構築する
    # --disable-shared
    # --enable-static
    #         共有ライブラリを作らずgccに対して静的リンクでgmpをリンクさせる
    #         (LD_LIBRARY_PATH環境変数を設定せずに使用するために必要)
    ${SRCDIR}/${GMP}/configure            \
	--prefix=${BUILD_TOOLS_DIR}                 \
	--enable-cxx                      \
	--disable-shared                  \
	--enable-static

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
}

## begin note
# 機能:ビルド用gccのコンパイルに必要なMPFR(多桁浮動小数点演算ライブラリ)を生成する
## end note
do_build_mpfr_for_build(){

    echo "@@@ BuildTool:mpfr @@@"

    extract_archive ${MPFR}

    mkdir -p ${BUILDDIR}/${MPFR}
    pushd  ${BUILDDIR}/${MPFR}

    #
    # configureの設定
    #
    # --prefix=${BUILD_TOOLS_DIR}
    #          ${BUILD_TOOLS_DIR}配下にインストールする
    # --with-gmp=${BUILD_TOOLS_DIR}
    #          gmpのインストール先を指定する
    # --disable-shared
    # --enable-static
    #         共有ライブラリを作らずgccに対して静的リンクでmpfrをリンクさせる
    #         (LD_LIBRARY_PATH環境変数を設定せずに使用するために必要)
    #
    ${SRCDIR}/${MPFR}/configure           \
	--prefix=${BUILD_TOOLS_DIR}                 \
	--with-gmp=${BUILD_TOOLS_DIR}               \
	--disable-shared                  \
	--enable-static

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
}

## begin note
# 機能:ビルド用gccのコンパイルに必要なMPC(多桁複素演算ライブラリ)を生成する
## end note
do_build_mpc_for_build(){

    echo "@@@ BuildTool:mpc @@@"

    extract_archive ${MPC}

    mkdir -p ${BUILDDIR}/${MPC}
    pushd  ${BUILDDIR}/${MPC}

    #
    # configureの設定
    #
    # --prefix=${BUILD_TOOLS_DIR}
    #          ${BUILD_TOOLS_DIR}配下にインストールする
    #
    # --with-gmp=${BUILD_TOOLS_DIR}
    #          gmpのインストール先を指定する
    #
    # --with-mpfr=${BUILD_TOOLS_DIR}
    #          mpfrのインストール先を指定する
    #
    # --disable-shared
    # --enable-static
    #         共有ライブラリを作らずgccに対して静的リンクでmpcをリンクさせる
    #         (LD_LIBRARY_PATH環境変数を設定せずに使用するために必要)
    #
    ${SRCDIR}/${MPC}/configure   \
	--prefix=${BUILD_TOOLS_DIR}        \
	--with-gmp=${BUILD_TOOLS_DIR}      \
	--with-mpfr=${BUILD_TOOLS_DIR}     \
	--disable-shared         \
	--enable-static

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
}

## begin note
# 機能:gccのコンパイルに必要なISL(整数集合ライブラリ)を生成する
## end note
do_build_isl_for_build(){

    echo "@@@ BuildTool:isl @@@"

    extract_archive ${ISL}

    mkdir -p ${BUILDDIR}/${ISL}
    pushd  ${BUILDDIR}/${ISL}

    #
    # configureの設定
    #
    # --prefix=${BUILD_TOOLS_DIR}
    #          ${BUILD_TOOLS_DIR}配下にインストールする
    # --disable-silent-rules
    #          コンパイル時にコマンドラインを表示する
    # --with-gmp=system
    #          インストール済みのGMPを使用する
    # --with-gmp-prefix=${BUILD_TOOLS_DIR}
    #          ${BUILD_TOOLS_DIR}配下のGMPを使用する
    # --disable-shared
    # --enable-static
    #         共有ライブラリを作らずgccに対して静的リンクでislをリンクさせる
    #         (LD_LIBRARY_PATH環境変数を設定せずに使用するために必要)
    #
    ${SRCDIR}/${ISL}/configure           \
	--prefix=${BUILD_TOOLS_DIR}                \
	--disable-silent-rules           \
	--with-gmp=system                \
	--with-gmp-prefix=${BUILD_TOOLS_DIR}       \
	--disable-shared                 \
	--enable-static

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
}

## begin note
# 機能: ビルド環境向けのgccを生成する(binutils/gcc/glibcの構築に必要なC/C++までを生成)
## end note
do_build_gcc_for_build(){
    local libgcc_file
    local libgcc_dir
    local libgcc_name

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
    #--prefix=${BUILD_TOOLS_DIR}
    #          ${BUILD_TOOLS_DIR}配下にインストールする
    #--target=${BUILD}
    #          ビルド環境向けのコードを生成する
    #--with-local-prefix=${BUILD_TOOLS_DIR}/${BUILD}
    #          gcc内部で使用するファイルを${BUILD_TOOLS_DIR}/${BUILD}に格納する
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
    #--disable-decimal-float
    #          gccの10進浮動小数点ライブラリを生成しない
    #--disable-libmudflap
    #          mudflap( バッファオーバーフロー、メモリリーク、
    #          ポインタの誤使用等を実行時に検出するライブラリ)
    #          を無効にする
    #--disable-libssp
    #           -fstack-protector-all オプションを無効にする
    #           (共有ライブラリをインストールしないため)
    #           (Stack Smashing Protector機能を無効にする)
    #--disable-libgomp
    #           GNU OpenMPライブラリを生成する
    #--disable-libsanitizer
    #           libsanitizerを無効にする(共有ライブラリをインストールしないため)
    #--with-gmp=${BUILD_TOOLS_DIR}
    #          gmpをインストールしたディレクトリを指定
    #--with-mpfr=${BUILD_TOOLS_DIR}
    #          mpfrをインストールしたディレクトリを指定
    #--with-mpc=${BUILD_TOOLS_DIR}
    #          mpcをインストールしたディレクトリを指定
    #--with-isl=${BUILD_TOOLS_DIR}
    #          islをインストールしたディレクトリを指定
    #--program-prefix="${BUILD}-"
    #          ターゲット用のコンパイラやシステムにインストールされている
    #          コンパイラと区別するために, プログラムのプレフィクスに
    #          ${BUILD}-をつける。
    #${LINK_STATIC_LIBSTDCXX}
    #          libstdc++を静的リンクしパスに依存せず動作できるようにする
    #
    env CC_FOR_BUILD="gcc"                                           \
	CC_FOR_BUILD="g++"                                           \
        LD_FOR_TARGET="${BUILD_TOOLS_DIR}/bin/${BUILD}-ld"           \
	AR_FOR_TARGET="${BUILD_TOOLS_DIR}/bin/${BUILD}-ar"           \
	RANLIB_FOR_TARGET="${BUILD_TOOLS_DIR}/bin/${BUILD}-ranlib"   \
	NM_FOR_TARGET="${BUILD_TOOLS_DIR}/bin/${BUILD}-nm"           \
	OBJCOPY_FOR_TARGET="${BUILD_TOOLS_DIR}/bin/${BUILD}-objcopy" \
	OBJDUMP_FOR_TARGET="${BUILD_TOOLS_DIR}/bin/${BUILD}-objdump" \
	STRIP_FOR_TARGET="${BUILD_TOOLS_DIR}/bin/${BUILD}-strip"     \
	${SRCDIR}/${GCC}/configure                           \
	--prefix=${BUILD_TOOLS_DIR}                          \
	--build=${BUILD}                                     \
	--target=${BUILD}                                    \
	--with-local-prefix=${BUILD_TOOLS_DIR}/${BUILD}      \
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
	--disable-decimal-float                              \
	--disable-libmudflap                                 \
	--disable-libssp                                     \
	--disable-libgomp                                    \
	--disable-libsanitizer                               \
	--with-gmp=${BUILD_TOOLS_DIR}                        \
	--with-mpfr=${BUILD_TOOLS_DIR}                       \
	--with-mpc=${BUILD_TOOLS_DIR}                        \
	--with-isl=${BUILD_TOOLS_DIR}                        \
	--program-prefix="${BUILD}-"                         \
	"${LINK_STATIC_LIBSTDCXX}"                           \
	--with-long-double-128 				     \
	--disable-nls

    make ${SMP_OPT}
    ${SUDO} make install
    popd

    echo "Remove .la files"
    pushd ${BUILD_TOOLS_DIR}
    find . -name '*.la'|while read file
    do
	echo "Remove ${file}"
	${SUDO} rm -f ${file}
    done
    popd

    #
    #ホストのgccとの混乱を避けるため以下を削除
    #
    echo "rm cpp gcc gcc-ar gcc-nm gcc-ranlib gcov on ${BUILD_TOOLS_DIR}/bin"
    pushd ${BUILD_TOOLS_DIR}/bin
    rm -f cpp gcc gcc-ar gcc-nm gcc-ranlib gcov ${BUILD}-cc
    #
    # コンパイラへのリンクを張る
    #
    ln -sf ${BUILD}-gcc ${BUILD}-cc
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
# 機能:ツールチェイン構築環境を用意する
## end note
prepare_buildtools(){

    if [ "x${SKIP_BUILD_TOOLS}" != 'x' -a -d "${BUILD_TOOLS_DIR}" ]; then
	echo "Skip building toolchains to build"
    else

	mkdir -p "${BUILD_TOOLS_DIR}"

	if [ "x${NO_GMAKE}" != 'x' ]; then
	    echo "Skip building GNU make to build"
	else
	    do_build_gmake_for_build
	fi

	if [ "x${NO_GTAR}" != 'x' ]; then
	    echo "Skip building GNU tar to build"
	else
	    do_build_gtar_for_build
	fi

	do_build_binutils_for_build
	do_build_gmp_for_build
	do_build_mpfr_for_build
	do_build_mpc_for_build
	do_build_isl_for_build
	do_build_gcc_for_build

	if [ "x${NO_SWIG}" != 'x' ]; then
	    echo "Skip building swig to build"
	else
	    do_build_swig_for_build
	fi
    fi
}

## begin note
# 機能:ツールチェイン構築前処理
## end note
do_prepare(){

    if [ "x${NO_DEVENV}" = 'x' ]; then
    	prepare_devenv
    fi

    setup_variables

    show_info

    prepare_archives

    if [ "x${NO_CLEAN_DIR}" = 'x' ]; then
	cleanup_directories
    fi

    create_directories
}

## begin note
# 機能:クロスコンパイル環境のテスト
## end note
do_cross_compile_test(){

    echo "@@@ cross compiler test @@@"
    echo "QEmu: ${CROSS}/bin/qemu-${QEMU_CPU}"
    rm -f hello

    if [ "x${TOOLCHAIN_TYPE}" != "xLLVM" ]; then

	echo "Compiler: ${CROSS}/bin/${TARGET}-gcc"
	CC_FOR_TEST="${CROSS}/bin/${TARGET}-gcc"
	CXX_FOR_TEST="${CROSS}/bin/${TARGET}-g++"
	LD_FOR_TEST="${CROSS}/bin/${TARGET}-ld"
	AR_FOR_TEST="${CROSS}/bin/${TARGET}-ar"
	RANLIB_FOR_TEST="${CROSS}/bin/${TARGET}-ranlib"
    else
	echo "Compiler: ${CROSS}/bin/clang"
	CC_FOR_TEST="${CROSS}/bin/clang"
	CXX_FOR_TEST="${CROSS}/bin/clang++"
	LD_FOR_TEST="${CROSS}/bin/ld.lld"
	AR_FOR_TEST="${CROSS}/bin/llvm-ar"
	RANLIB_FOR_TEST="${CROSS}/bin/llvm-ranlib"
    fi

    ${CC_FOR_TEST} -o hello ${TESTDIR}/hello.c
    file hello

    if [ "x${TOOLCHAIN_TYPE}" = "xLinux" ]; then

	${CC_FOR_TEST} -O3 ${SAMPLE_COMPILE_OPT} -DMIDDLE -o himenoM \
		       ${TESTDIR}/himenoBMTxps.c
	file himenoM

       echo "@@ Run hello world @@"
       ${CROSS}/bin/qemu-${QEMU_CPU} hello

       if [ "x${RUN_HIMENO}" = 'xyes' ]; then
	   echo "@@ Run himeno bench (Middle Size) @@"
	   ${CROSS}/bin/qemu-${QEMU_CPU} himenoM
       fi
    fi

    rm -f hello himenoM
}

## begin note
# 機能:ツールチェイン構築後処理
## end note
do_finalize(){

    if [ "x${NO_STRIP}" = 'x' ]; then
     	do_strip_binaries
    fi

    if [ "x${NO_SYMLINK}" = 'x' ]; then
	create_symlink
    fi

    if [ "x${NO_CLEAN_DIR}" = 'x' ]; then
    	cleanup_temporary_directories
    fi
    if [ "x${SKIP_BUILD_TOOLS}" != "x" ]; then
	echo "keep tools directory."
    else
	if [ -d "${BUILD_TOOLS_DIR}" ]; then
	    echo "Cleanup tools"
	    rm -fr "${BUILD_TOOLS_DIR}"
	fi
    fi
}

## begin note
# 機能: UEFI(EDKII)を構築する
## end note
do_cross_uefi(){

    echo "@@@ EDK2 UEFI @@@"

    if [ ! -e ${DOWNLOADDIR}/${EDK2}.tar.gz ]; then
	fetch_edk2_src
    fi

    extract_archive ${EDK2}

    rm -fr ${CROSS}/uefi
    mkdir -p ${CROSS}/uefi

    rm -fr ${BUILDDIR}/${EDK2}
    mkdir -p ${BUILDDIR}

    cp -a  ${SRCDIR}/${EDK2} ${BUILDDIR}/${EDK2}
    pushd ${BUILDDIR}/${EDK2}
    gmake -C BaseTools
    source ${BUILDDIR}/${EDK2}/edksetup.sh
    case "${TARGET_CPU}" in
	aarch64)
	    export GCC5_AARCH64_PREFIX=${TARGET}-
	    build -a AARCH64 -t GCC5 -p ArmVirtPkg/ArmVirtQemu.dsc
	    cp  Build/ArmVirtQemu-AARCH64/DEBUG_GCC5/FV/*.fd ${CROSS}/uefi
	    ;;
	x86_64)
	    #
	    #See https://github.com/tianocore/tianocore.github.io/wiki/How-to-build-OVMF
	    #
	    export GCC5_X64_PREFIX=${TARGET}-
	    build -a X64 -t GCC5 -p OvmfPkg/OvmfPkgX64.dsc
	    cp Build/OvmfX64/DEBUG_GCC5/FV/*.fd ${CROSS}/uefi
	    ;;
	i[3456]86)
	    #
	    #See https://github.com/tianocore/tianocore.github.io/wiki/How-to-build-OVMF
	    #
	    export GCC5_IA32_PREFIX=${TARGET}-
	    build -a IA32 -t GCC5 -p OvmfPkg/OvmfPkgIa32.dsc
	    cp Build/OvmfIa32/DEBUG_GCC5/FV/*.fd ${CROSS}/uefi
	    ;;
	* )
	    echo "@@@ EDK2 UEFI @@@"
	    echo "Skip building UEFI for ${TARGET_CPU}"
	    ;;
    esac

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

    if [ "x${TOOLCHAIN_TYPE}" != "xLLVM" ]; then
	CC_FOR_QEMU_BUILD="${BUILD_TOOLS_DIR}/bin/${BUILD}-gcc"
	CXX_FOR_QEMU_BUILD="${BUILD_TOOLS_DIR}/bin/${BUILD}-g++"
	LD_FOR_QEMU_BUILD="${BUILD_TOOLS_DIR}/bin/${BUILD}-ld"
	AR_FOR_QEMU_BUILD="${BUILD_TOOLS_DIR}/bin/${BUILD}-ar"
	RANLIB_FOR_QEMU_BUILD="${BUILD_TOOLS_DIR}/bin/${BUILD}-ranlib"
	NM_FOR_QEMU_BUILD="${BUILD_TOOLS_DIR}/bin/${BUILD}-nm"
	OBJCOPY_FOR_QEMU_BUILD="${BUILD_TOOLS_DIR}/bin/${BUILD}-objcopy"
	OBJDUMP_FOR_QEMU_BUILD="${BUILD_TOOLS_DIR}/bin/${BUILD}-objdump"
	STRIP_FOR_QEMU_BUILD="${BUILD_TOOLS_DIR}/bin/${BUILD}-strip"
    else
	CC_FOR_QEMU_BUILD="${CROSS}/bin/clang"
	CXX_FOR_QEMU_BUILD="${CROSS}/bin/clang++"
	LD_FOR_QEMU_BUILD="${CROSS}/bin/ld.lld"
	AR_FOR_QEMU_BUILD="${CROSS}/bin/llvm-ar"
	RANLIB_FOR_QEMU_BUILD="${CROSS}/bin/llvm-ranlib"
	NM_FOR_QEMU_BUILD="${CROSS}/bin/llvm-nm"
	OBJCOPY_FOR_QEMU_BUILD="${CROSS}/bin/llvm-objcopy"
	OBJDUMP_FOR_QEMU_BUILD="${CROSS}/bin/llvm-objdump"
	STRIP_FOR_QEMU_BUILD="${CROSS}/bin/llvm-strip"
    fi


    CC="${CC_FOR_QEMU_BUILD}"            \
    CXX="${CXX_FOR_QEMU_BUILD}"          \
    LD="${LD_FOR_QEMU_BUILD}"            \
    AR="${AR_FOR_QEMU_BUILD}"            \
    RANLIB="${RANLIB_FOR_QEMU_BUILD}"    \
    NM="${NM_FOR_QEMU_BUILD}"            \
    OBJCOPY="${OBJCOPY_FOR_QEMU_BUILD}"  \
    OBJDUMP="${OBJDUMP_FOR_QEMU_BUILD}"  \
    STRIP="${STRIP_FOR_QEMU_BUILD}"      \
    ../configure                         \
     --prefix=${CROSS}                   \
     --interp-prefix=${SYSROOT}          \
     ${QEMU_CONFIG_TARGETS}              \
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

## begin note
# 機能:llvmをコンパイルするために必要なcmakeを作成する。
## end note
do_build_cmake(){
    local para

    echo "@@@ cmake @@@"

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

    echo "@@@ ninja @@@"

    mkdir -p ${DOWNLOADDIR}

    if [ "x${FETCH_NINJA}" != 'x' -o ! -d ${DOWNLOADDIR}/ninja ]; then
	pushd ${DOWNLOADDIR}
	git clone ${NINJA_GIT_REPO}
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
