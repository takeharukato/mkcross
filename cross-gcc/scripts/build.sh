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

    if [ "x${_LIB}" = "x" ]; then

	echo "@@@ _LIB is not set, we assume _LIB is lib64. "
	_LIB=lib64
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

    if [ "x${TARGET}" = "x" ]; then
	TARGET=${TARGET_CPU}-unknown-linux-gnu
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
    
    if [ "x${QEMU_SOFTMMU_TARGETS}" = "x" ]; then
	QEMU_SOFTMMU_TARGETS="${QEMU_CPU}-softmmu"
    fi
    
    if [ "x${OSNAME}" = "xLinux" ]; then
	QEMU_CONFIG_USERLAND="--enable-user --enable-linux-user"
	QEMU_TARGETS="${QEMU_SOFTMMU_TARGETS},${QEMU_CPU}-linux-user"
    else
	if [ "x${QEMU_CPU}" = "xx86_64" -o "x${QEMU_CPU}" = "xi386" ]; then
	    QEMU_CONFIG_USERLAND="--enable-user --enable-bsd-user"
	    QEMU_TARGETS="${QEMU_SOFTMMU_TARGETS},${QEMU_CPU}-bsd-user"
	else
	    QEMU_TARGETS="${QEMU_SOFTMMU_TARGETS}"	
	fi
    fi

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

    #パッチ格納先ディレクトリ
    PATCHDIR=${WORKDIR}/patches

    #アーカイブダウンロードディレクトリ
    DOWNLOADDIR=${WORKDIR}/downloads

    #ビルドツールディレクトリ
    BUILD_TOOLS_DIR=${WORKDIR}/tools
    
    #クロスコンパイラやクロス環境向けのヘッダ・ライブラリを格納するディレクトリ
    if [ "x${CROSS_PREFIX}" = "x" ]; then
	CROSS_PREFIX=${HOME}/cross/gcc/${TARGET_CPU}
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
    echo "Tool chain type: Linux"
    echo "Build: ${BUILD}"
    echo "Target: ${TARGET}"
    echo "Host: ${HOST}"
    echo "Build OS: ${OSNAME}"
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

    for dname in build src tools
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
# 機能:開発環境をそろえる
## end note
prepare_devenv(){

    sudo yum install -y  coreutils yum-priorities epel-release yum-utils
    # For UEFI
    sudo yum install -y  nasm iasl acpica-tools
    # QEmu
    sudo yum install -y giflib-devel libpng-devel libtiff-devel gtk3-devel \
	ncurses-devel gnutls-devel nettle-devel libgcrypt-devel SDL2-devel \
	gtk-vnc-devel libguestfs-devel curl-devel brlapi-devel bluez-libs-devel \
	libusb-devel libcap-devel libcap-ng-devel libiscsi-devel libnfs-devel \
	libcacard-devel lzo-devel snappy-devel bzip2-devel libseccomp-devel \
	libxml2-devel libssh2-devel xfsprogs-devel mesa-libGL-devel mesa-libGLES-devel \
        mesa-libGLU-devel mesa-libGLw-devel spice-server-devel libattr-devel \
	libaio-devel sparse-devel gtkglext-libs vte-devel libtasn1-devel \
	gperftools-devel virglrenderer device-mapper-multipath-devel \
	cyrus-sasl-devel libjpeg-turbo-devel glusterfs-api-devel \
	libpmem-devel libudev-devel capstone-devel numactl-devel \
	librdmacm-devel  libibverbs-devel libibumad-devel libvirt-devel \
	gcc-objc iasl
    # Ceph for QEmu
    sudo yum install -y ceph ceph-base ceph-common ceph-devel-compat ceph-fuse \
	ceph-libs-compat ceph-mds ceph-mon ceph-osd ceph-radosgw ceph-resource-agents \
	ceph-selinux ceph-test cephfs-java libcephfs1-devel libcephfs_jni1-devel \
	librados2-devel libradosstriper1-devel librbd1-devel librgw2-devel \
	python-ceph-compat python-cephfs python-rados python-rbd rbd-fuse \
	rbd-mirror rbd-nbd 
    # Xen for QEmu
    sudo yum -y centos-release-xen sudo passwd bzip2 patch nano which tar  \
	xz libvirt libvirt-daemon-xen
    sudo yum groupinstall -y "Development tools"

    # Multilib
    sudo yum install -y  glibc-devel.i686 zlib-devel.i686 elfutils-devel.i686 \
	mpfr-devel.i686 libstdc++-devel.i686 binutils-devel.i686
    sudo yum-builddep -y binutils gcc gdb qemu-kvm texinfo-tex texinfo
    sudo yum install -y  patchelf
}

## begin note
# 機能:ソースアーカイブを収集する
## end note
prepare_archives(){
    local file
    local tmpdir

    echo "@@@ Preparation:fetch-archives @@@"

    mkdir -p ${WORKDIR}/downloads
    pushd ${WORKDIR}/downloads
    for url in ${DOWNLOAD_URLS}
      do
	file=`basename ${url}`
	if [ ! -f ${WORKDIR}/downloads/${file} ]; then
	    echo "Fetch ${url}"
	    wget --no-check-certificate ${url}
	else
	    echo "${file} already exists."
	fi
    done
    popd

    #
    #git archive
    #
    if [ ! -f ${WORKDIR}/downloads/${KERNEL}.tar.gz -a ! -f ${WORKDIR}/downloads/${KERNEL}.tar.xz ]; then
	if [ "x${KERNEL_URL}" != "x" ]; then
	    tmpdir=`mktemp -d`
	    pushd ${tmpdir}
	    git clone ${KERNEL_URL}
	    pushd `basename ${KERNEL_URL}`
	    git fetch
	    git archive --format=tar --prefix=${KERNEL}/ HEAD |\
	    gzip > ${WORKDIR}/downloads/${KERNEL}.tar.gz
	    popd
	    popd
	    if [ -d ${tmpdir} ]; then
		rm -fr ${tmpdir}
	    fi
	else
	    echo "Neither ${KERNEL}.tar.gz or ${KERNEL}.tar.xz is not found."
	    exit 1;
	fi
    else
	echo "${KERNEL}.tar.gz or ${KERNEL}.tar.xz already exists."
    fi

}

## begin note
# 機能:クロスコンパイル用のディレクトリを生成する
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

    if [ -d ${CROSS_PREFIX}/${TODAY} ]; then
	rm -fr ${CROSS_PREFIX}/${TODAY}
    fi
    mkdir -p ${CROSS_PREFIX}/${TODAY}

    mkdir -p ${SYSROOT}
    popd
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
    patch -p1 < ../../patches/elfutils/elfutils-portability.patch
    patch -p1 < ../../patches/elfutils/elfutils-robustify.patch
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

    popd

    #
    #ホストのgccとの混乱を避けるため以下を削除
    #
    echo "rm cpp gcc gcc-ar gcc-nm gcc-ranlib gcov on ${CROSS}/bin"
    pushd ${CROSS}/bin
    rm -f cpp gcc gcc-ar gcc-nm gcc-ranlib gcov ${TARGET}-cc
    #
    # クロスコンパイラへのリンクを張る
    #
    ln -sf ${TARGET}-gcc ${TARGET}-cc
    popd
}

## begin note
# 機能:クロスbinutilsを生成する
## end note
do_cross_binutils(){

    echo "@@@ Cross:binutils-core @@@"

    extract_archive ${BINUTILS}

    rm -fr ${BUILDDIR}/${BINUTILS}
    mkdir -p ${BUILDDIR}/${BINUTILS}
    pushd  ${BUILDDIR}/${BINUTILS}

    #
    # configureの設定
    #
    #ビルド環境のコンパイラ/binutilsの版数に依存しないようにビルド向けに生成した
    #コンパイラとbinutilsを使用して構築を行うための設定を実施
    #
    # CC_FOR_BUILD="${BUILD}-gcc"
    #   構築時に使用するCコンパイラを指定
    # CXX_FOR_BUILD="${BUILD}-g++"
    #   構築時に使用するC++コンパイラを指定
    # AR_FOR_BUILD="${BUILD}-ar"
    #   構築時に使用するarを指定    
    # LD_FOR_BUILD="${BUILD}-ld"
    #   構築時に使用するranlibを指定    
    # RANLIB_FOR_BUILD="${BUILD}-ranlib"
    #
    # --prefix=${CROSS}        
    #          ${CROSS}配下にインストールする
    # --build=${BUILD} 
    #        ${BUILD}で指定されたマシン上でコンパイルする
    #        (${BUILD}-プレフィクス付きのツールを明に使用する)
    # --host=${HOST}
    #          HOSTで指定された環境で動作するbinutilsを作成する
    # --target=${TARGET}
    #          TARGET指定された環境向けのバイナリを扱うbinutilsを作成する
    # ${PROGRAM_PREFIX}
    #         ターゲットシステムとホストシステムが同一の場合, 
    #         システムにインストールされているコンパイラと区別するために, 
    #         プログラムのプレフィクスに${TARGET}-をつける。
    # --with-local-prefix=${CROSS}/${TARGET}
    #        ${CROSS}/${TARGET}にbinutils内部で使用するファイルを配置する
    # --disable-shared                     
    #         共有ライブラリでBFDを作らずbintuils内にBFDライブラリを静的リンクする
    # --disable-werror
    #         警告をエラーと見なさない
    # --disable-nls
    #         コンパイル時間を短縮するためNative Language Supportを無効化する
    #${WITH_SYSROOT}
    #         ターゲット環境用のヘッダやライブラリを参照して動作するbinutils
    #         を生成する
    #
    CC_FOR_BUILD="${BUILD}-gcc"                              \
    CXX_FOR_BUILD="${BUILD}-g++"                             \
    AR_FOR_BUILD="${BUILD}-ar"                               \
    LD_FOR_BUILD="${BUILD}-ld"                               \
    RANLIB_FOR_BUILD="${BUILD}-ranlib"                       \
    ${SRCDIR}/${BINUTILS}/configure            \
	--prefix=${CROSS}                      \
        --build=${BUILD}                       \
        --host=${BUILD}                        \
	--target=${TARGET}                     \
	"${PROGRAM_PREFIX}"                    \
	--with-local-prefix=${CROSS}/${TARGET} \
	--disable-shared                       \
	--disable-werror                       \
	--disable-nls                          \
	"${WITH_SYSROOT}"
    
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

    #
    #ビルド環境のツールと混在しないようにする
    #
    echo "Remove addr2line ar as c++filt elfedit gprof ld ld.bfd nm objcopy objdump ranlib readelf size strings strip on ${CROSS}/bin"
    pushd ${CROSS}/bin
    rm -f addr2line ar as c++filt elfedit gprof ld ld.bfd nm objcopy objdump ranlib readelf size strings strip
    popd
}

## begin note
# 機能:カーネルヘッダの生成からCスタートアップルーチン(crt*.o)の生成までに使用するCコンパイラを生成する
## end note
do_cross_gcc_core1(){

    echo "@@@ Cross:gcc-core-stage1 @@@"

    extract_archive ${GCC}

    rm -fr ${BUILDDIR}/${GCC}
    mkdir -p ${BUILDDIR}/${GCC}
    pushd  ${BUILDDIR}/${GCC}

    #
    # configureの設定
    #
    #ビルド環境のコンパイラ/binutilsの版数に依存しないようにビルド向けに生成した
    #コンパイラとbinutilsを使用して構築を行うための設定を実施
    #
    #CC_FOR_BUILD="${BUILD}-gcc"
    #   構築時に使用するCコンパイラを指定
    #CXX_FOR_BUILD="${BUILD}-g++"
    #   構築時に使用するC++コンパイラを指定
    #AR_FOR_BUILD="${BUILD}-ar"
    #   構築時に使用するarを指定    
    #LD_FOR_BUILD="${BUILD}-ld"
    #   構築時に使用するranlibを指定    
    #RANLIB_FOR_BUILD="${BUILD}-ranlib"
    #
    #--prefix=${CROSS}
    #          ${CROSS}配下にインストールする
    #--build=${BUILD}
    #          ビルド環境を指定する
    #--host=${BUILD}
    #          ビルド環境で動作するコンパイラを構築する
    #--target=${TARGET}
    #          ターゲット環境向けのコードを生成するコンパイラを構築する
    #--with-local-prefix=${CROSS}/${TARGET}
    #          gcc内部で使用するファイルを${CROSS}/${TARGET}に格納する
    #${WITH_SYSROOT}
    #          コンパイラの実行時にターゲットのルートファイルシステムを優先してヘッダや
    #          ライブラリを探査する
    #--enable-languages=c
    #          カーネルヘッダの生成からCスタートアップルーチン(crt*.o)の生成までに必要なCコンパイラのみを生成
    #--disable-bootstrap
    #          ビルド環境もgccを使用することから, 時間削減のためビルド環境とホスト環境が
    #          同一CPUの場合でも, 3stageコンパイルを無効にする
    #--disable-werror
    #         警告をエラーと見なさない
    #--disable-shared
    #          gccの共有ランタイムライブラリを生成しない
    #--disable-multilib
    #          バイアーキ(32/64bit両対応)版gccの生成を行わない。
    #--with-newlib
    #          libcを自動リンクしないコンパイラを生成する
    #--without-headers
    #          libcのヘッダを参照しない
    #--disable-lto
    #          binutils/gcc/glibcの構築に不要なltoプラグインを生成しない
    #--disable-decimal-float
    #          gccの10進浮動小数点ライブラリを生成しない
    #--disable-threads
    #          ターゲット用のlibpthreadがないためスレッドライブラリに対応しない
    #--disable-libmudflap
    #          mudflap( バッファオーバーフロー、メモリリーク、
    #          ポインタの誤使用等を実行時に検出するライブラリ)
    #          を構築しない.
    #--disable-libatomic
    #          アトミック処理用ライブラリを生成しない 
    #--disable-libitm
    #          トランザクショナルメモリ操作ライブラリを生成しない
    #--disable-libquadmath
    #          4倍精度数学ライブラリを生成しない
    #--disable-libvtv
    #          Virtual Table Verification(仮想関数テーブル攻撃対策)
    #          ライブラリを生成しない
    #--disable-libcilkrts
    #           Cilkランタイムライブラリを生成しない
    #--disable-libssp
    #           -fstack-protector-all オプションを無効化する
    #           (Stack Smashing Protector機能を無効にする)
    #--disable-libmpx
    #           MPX(Memory Protection Extensions)ライブラリをビルドしない
    #--disable-libgomp
    #           GNU OpenMPライブラリを生成しない
    #--disable-libsanitizer
    #           libsanitizerを無効にする(gcc-4.9のlibsanitizerは
    #           バグのためコンパイルできないため)
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
    #--disable-nls
    #         コンパイル時間を短縮するためNative Language Supportを無効化する
    #
    CC_FOR_BUILD="${BUILD}-gcc"                              \
    CXX_FOR_BUILD="${BUILD}-g++"                             \
    AR_FOR_BUILD="${BUILD}-ar"                               \
    LD_FOR_BUILD="${BUILD}-ld"                               \
    RANLIB_FOR_BUILD="${BUILD}-ranlib"                       \
    ${SRCDIR}/${GCC}/configure                               \
	--prefix=${CROSS}                                    \
        --build=${BUILD}                                     \
        --host=${BUILD}                                      \
	--target=${TARGET}                                   \
	--with-local-prefix=${CROSS}/${TARGET}               \
	"${WITH_SYSROOT}"                                    \
	--enable-languages=c                                 \
	--disable-bootstrap                                  \
	--disable-werror                                     \
	--disable-shared                                     \
	--disable-multilib                                   \
	--with-newlib                                        \
	--without-headers                                    \
	--disable-lto                                        \
	--disable-threads                                    \
	--disable-decimal-float                              \
	--disable-libatomic                                  \
	--disable-libitm                                     \
        --disable-libquadmath                                \
	--disable-libvtv                                     \
	--disable-libcilkrts                                 \
	--disable-libmudflap                                 \
	--disable-libssp                                     \
	--disable-libmpx                                     \
	--disable-libgomp                                    \
	--disable-libsanitizer                               \
	--with-gmp=${CROSS}                                  \
	--with-mpfr=${CROSS}                                 \
	--with-mpc=${CROSS}                                  \
	--with-isl=${CROSS}                                  \
	--with-libelf=${CROSS}                               \
	--disable-nls
    
    #
    #make allを実行できるだけのヘッダやC標準ライブラリがないため部分的に
    #コンパイラの構築を行う
    #
    #crosstool-ng-1.19.0のscripts/build/cc/gcc.shを参考にした
    #

    #
    #cpp/libiberty(GNU共通基盤ライブラリ)の構築
    #
    make configure-gcc configure-libcpp configure-build-libiberty
    make ${SMP_OPT} all-libcpp all-build-libiberty

    #
    #libdecnumber/libbacktrace(gccの動作に必須なライブラリ)の構築
    #
    make configure-libdecnumber
    make ${SMP_OPT} -C libdecnumber libdecnumber.a
    make configure-libbacktrace
    make ${SMP_OPT} -C libbacktrace

    #
    #gcc(Cコンパイラ)とアーキ共通基盤ライブラリ(libgcc)の構築
    #
    make -C gcc libgcc.mvars
    make ${SMP_OPT} all-gcc all-target-libgcc
    ${SUDO} make install-gcc install-target-libgcc
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
    echo "Remove cpp gcc gcc-ar gcc-nm gcc-ranlib gcov on ${CROSS}/bin"
    pushd ${CROSS}/bin
    rm -f cpp gcc gcc-ar gcc-nm gcc-ranlib gcov ${TARGET}-cc
    #
    # クロスコンパイラへのリンクを張る
    #
    ln -sf ${TARGET}-gcc ${TARGET}-cc
    popd
}

## begin note
# 機能:libcのヘッダ生成に必要なカーネルヘッダを生成する
## end note
do_kernel_headers(){

    echo "@@@ Cross:kernel-headers @@@"

    extract_archive ${KERNEL}

    rm -fr ${BUILDDIR}/${KERNEL}
    cp -a ${SRCDIR}/${KERNEL}  ${BUILDDIR}/${KERNEL}
    pushd  ${BUILDDIR}/${KERNEL}

    #カーネルのコンフィグレーションを設定
    make ARCH="${KERN_ARCH}" HOSTCC="${BUILD}-gcc" V=1 defconfig

    #カーネルヘッダのチェック
    make ARCH="${KERN_ARCH}" HOSTCC="${BUILD}-gcc" V=1 headers_check

    #カーネルヘッダのインストール
    make ARCH=${KERN_ARCH} HOSTCC="${BUILD}-gcc" \
	INSTALL_HDR_PATH=${SYSROOT}/usr V=1 headers_install

    popd    
}

## begin note
# 機能:libcのヘッダを生成する
## end note
do_glibc_headers(){

    echo "@@@ Cross:glibc-headers @@@"

    extract_archive ${GLIBC}

    rm -fr ${BUILDDIR}/${GLIBC}
    mkdir ${BUILDDIR}/${GLIBC}
    pushd ${BUILDDIR}/${GLIBC}
    
    #
    # configureの設定
    #
    # CFLAGS="-O -finline-functions"
    #   コンパイルオプションに -finline-functions
    #   を指定する(インライン関数が使用できることを前提にglibcが
    #   書かれているため, -Oを指定した場合、 -finline-functionsがないと
    #   コンパイルできない). -O3を指定した場合のライブラリを使用すると
    #   プログラムが動作しないことがあったため, -Oでコンパイルする。
    # --prefix=${CROSS}        
    #          ${CROSS}配下にインストールする
    # --build=${BUILD}
    #        ${BUILD}で指定されたマシン上でコンパイルする
    # --host=${TARGET}
    #        ${TARGET}で指定されたマシン上で動作するlibcを生成する
    # --target=${TARGET}
    #        ${TARGET}で指定されたマシン上で動作するバイナリを出力する
    #        ツール群を作成する
    #  --prefix=/usr
    #           /usr/include,/usr/lib64,/usr/lib配下にヘッダ・ライブラリ
    #           をインストールする
    #  --without-cvs
    #          CVSからのソース獲得を行わない
    #  --disable-profile
    #          gprof対応版ライブラリを生成しない
    #  --without-gd
    #          GDグラフックライブラリが必要なツールを生成しない
    #  --disable-debug
    #          デバッグオプションを指定しない
    #  --with-headers=${SYSROOT}/usr/include
    #          ${SYSROOT}/usr/include配下のヘッダを参照する
    #  --enable-add-ons=nptl,libidn             
    #          NPTLをスレッドライブラリに, libidn国際ドメイン名ライブラリ
    #          を構築する(実際にはスタートアップルーチンのみ構築)
    #  --enable-kernel=${GLIBC_ENABLE_KERNEL}
    #          動作可能なカーネルの範囲（動作可能な範囲で最も古いカーネルの
    #          版数を指定する(上記のGLIBC_ENABLE_KERNELの設定値説明を参照)
    #  --disable-nscd
    #          ヘッダの生成のみを行うため, ncsdのコンパイルをしない
    #  --disable-obsolete-rpc
    #          ヘッダの生成のみを行うため, 廃止されたrpcライブラリを生成しない
    #  --without-selinux                      
    #          ターゲット用のlibselinuxがないため, selinux対応無しでコンパイルする
    #  --disable-mathvec
    #          mathvecを作成しない(libmが必要となるため)
    CFLAGS="-O -finline-functions"               \
	${SRCDIR}/${GLIBC}/configure             \
        --build=${BUILD}                         \
        --host=${TARGET}                         \
        --target=${TARGET}                       \
        --prefix=/usr                            \
        --without-cvs                            \
        --disable-profile                        \
        --without-gd                             \
        --disable-debug                          \
        --disable-sanity-checks                  \
	--disable-mathvec                        \
        --with-headers=${SYSROOT}/usr/include    \
        --enable-add-ons=nptl,libidn,ports       \
	--enable-kernel=${GLIBC_ENABLE_KERNEL}   \
	  --disable-werror                       \
	  --disable-nscd                         \
          --disable-obsolete-rpc                 \
          --without-selinux                      

    #
    #以下のconfigparmsは, make-3.82対応のために必要
    #make-3.82は, makeの引数で以下のオプションを引き渡せない障害があるので,
    #configparmに設定を記載.
    #
    #http://sourceware.org/bugzilla/show_bug.cgi?id=13810
    #Christer Solskogen 2012-03-06 14:18:58 UTC 
    #の記事参照
    #
    #install-bootstrap-headers=yes
    #   libcのヘッダだけをインストールする
    #
    #cross-compiling=yes
    #   クロスコンパイルを行う
    #
    #install_root=${SYSROOT}
    #   ${SYSROOT}配下にインストールする. --prefixに/usrを設定しているので
    #   ${SYSROOT}/usr/include配下にヘッダをインストールする意味となる.
    #
    cat >> configparms<<EOF
install-bootstrap-headers=yes
cross-compiling=yes
install_root=${SYSROOT}
EOF

    #
    #glibcの仕様により生成されないヘッダファイルをコピーする
    #(eglibcでは、バグと見なされ, 修正されているがコミュニティ間の
    #考え方の相違で, glibcでは修正されない)
    #
    mkdir -p ${SYSROOT}/usr/include/gnu
    touch ${SYSROOT}/usr/include/gnu/stubs.h
    touch ${SYSROOT}/usr/include/gnu/stubs-lp64.h

    if [ ! -f ${SYSROOT}/usr/include/features.h ]; then
	cp -v ${SRCDIR}/${GLIBC}/include/features.h \
	    ${SYSROOT}/usr/include
    fi

    #
    #libcのヘッダのみをインストール
    #
    BUILD_CC="${BUILD}-gcc"                \
    CFLAGS="-O  -finline-functions"        \
    CC=${TARGET}-gcc                       \
    AR=${TARGET}-ar                        \
    LD=${TARGET}-ld                        \
    RANLIB=${TARGET}-ranlib                \
    ${SUDO} make install-bootstrap-headers=yes install-headers	   

    #
    #glibcの仕様により生成されないヘッダファイルをコピーする
    #
    if [ ! -f ${SYSROOT}/usr/include/bits/stdio_lim.h ]; then
	cp -v bits/stdio_lim.h ${SYSROOT}/usr/include/bits
    fi
    #
    #32bit版のstabsを仮生成する
    #
    if [ ! -f ${SYSROOT}/usr/include/gnu/stubs-32.h ]; then
	touch ${SYSROOT}/usr/include/gnu/stubs-32.h 
    fi

    popd    
}

## begin note
# 機能:glibcのスタートアップルーチン群を生成する
## end note
do_glibc_startup(){

    echo "@@@ Cross:glibc-startup @@@"

    extract_archive ${GLIBC}

    rm -fr ${BUILDDIR}/${GLIBC}    
    mkdir ${BUILDDIR}/${GLIBC}
    pushd ${BUILDDIR}/${GLIBC}
    
    #
    # configureの設定
    #
    # CFLAGS="-O -finline-functions"
    #   コンパイルオプションに -finline-functions
    #   を指定する(インライン関数が使用できることを前提にglibcが
    #   書かれているため, -Oを指定した場合、 -finline-functionsがないと
    #   コンパイルできない). -O3を指定した場合のライブラリを使用すると
    #   プログラムが動作しないことがあったため, -Oでコンパイルする。
    # --prefix=${CROSS}        
    #          ${CROSS}配下にインストールする
    # --build=${BUILD}
    #        ${BUILD}で指定されたマシン上でコンパイルする
    # --host=${TARGET}
    #        ${TARGET}で指定されたマシン上で動作するlibcを生成する
    # --target=${TARGET}
    #        ${TARGET}で指定されたマシン上で動作するバイナリを出力する
    #        ツール群を作成する
    #  --prefix=/usr
    #           /usr/include,/usr/lib64,/usr/lib配下にヘッダ・ライブラリ
    #           をインストールする
    #  --without-cvs
    #          CVSからのソース獲得を行わない
    #  --disable-profile
    #          gprof対応版ライブラリを生成しない
    #  --without-gd
    #          GDグラフックライブラリが必要なツールを生成しない
    #  --disable-debug
    #          デバッグオプションを指定しない
    #  --with-headers=${SYSROOT}/usr/include
    #          ${SYSROOT}/usr/include配下のヘッダを参照する
    #  --enable-add-ons=nptl,libidn             
    #          NPTLをスレッドライブラリに, libidn国際ドメイン名ライブラリ
    #          を構築する(実際にはスタートアップルーチンのみ構築)
    #  --enable-kernel=${GLIBC_ENABLE_KERNEL}
    #          動作可能なカーネルの範囲（動作可能な範囲で最も古いカーネルの
    #          版数を指定する(上記のGLIBC_ENABLE_KERNELの設定値説明を参照)
    #  --disable-nscd
    #          ヘッダの生成のみを行うため, nscdのコンパイルをしない
    #  --disable-systemtap
    #          ターゲット用のsystemtapがないため, systemtap対応無しでコンパイルする
    #  --disable-obsolete-rpc
    #          スタートアップルーチン生成のみを行うため, 廃止されたrpcライブラリを生成しない
    #  --without-selinux                      
    #          ターゲット用のlibselinuxがないため, selinux対応無しでコンパイルする
    #  --disable-mathvec
    #          mathvecを作成しない(libmが必要となるため)
    #
    CFLAGS="-O -finline-functions"               \
	${SRCDIR}/${GLIBC}/configure             \
        --build=${BUILD}                         \
        --host=${TARGET}                         \
        --target=${TARGET}                       \
        --prefix=/usr                            \
        --without-cvs                            \
        --disable-profile                        \
        --without-gd                             \
        --disable-debug                          \
        --disable-sanity-checks                  \
	--disable-mathvec                        \
        --with-headers=${SYSROOT}/usr/include    \
        --enable-add-ons=nptl,libidn,ports       \
	--enable-kernel=${GLIBC_ENABLE_KERNEL}   \
	  --disable-werror                       \
	  --disable-nscd                         \
	  --disable-systemtap                    \
          --without-selinux                      

    #
    #以下のconfigparmsは, make-3.82対応のために必要
    #make-3.82は, makeの引数で以下のオプションを引き渡せない障害があるので,
    #configparmに設定を記載.
    #
    #http://sourceware.org/bugzilla/show_bug.cgi?id=13810
    #Christer Solskogen 2012-03-06 14:18:58 UTC 
    #の記事参照
    #
    #cross-compiling=yes
    #   クロスコンパイルを行う
    #
    #install_root=${SYSROOT}
    #   ${SYSROOT}配下にインストールする. --prefixに/usrを設定しているので
    #   ${SYSROOT}/usr/include配下にヘッダをインストールする意味となる.
    #
    cat >> configparms<<EOF
cross-compiling=yes
install_root=${SYSROOT}
EOF

    
    #
    # BUILD_CC="${BUILD}-gcc"
    #   ホストのgccをglibc内の構築支援ツールのコンパイル時に使用する
    #
    # CFLAGS="${TARGET_CFLAGS} -finline-functions"
    #   ターゲット用のコンパイルオプションに -finline-functions
    #   を指定する(インライン関数が使用できることを前提にglibcが
    #   書かれているため, -Oを指定した場合、 -finline-functionsがないと
    #   コンパイルできない)
    #
    # CC=${TARGET}-gcc
    #   ターゲット用のgccを使って、ライブラリやスタートアップルーチンを
    #   コンパイルする
    #
    # AR=${TARGET}-ar
    #   ターゲット用のarを使って、アーカイブを作成する
    #
    # LD=${TARGET}-ld
    #   ターゲット用のldを使って、リンクする
    #
    # RANLIB=${TARGET}-ranlib
    #   ターゲット用のranlibを使って、カタログを生成する
    #
    # make csu/subdir_lib
    #   Cのスタートアップルーチンをコンパイルする
    #
    BUILD_CC="${BUILD}-gcc"                  \
    CFLAGS="-O  -finline-functions"        \
    CC=${TARGET}-gcc                       \
    AR=${TARGET}-ar                        \
    LD=${TARGET}-ld                        \
    RANLIB=${TARGET}-ranlib                \
    make ${SMP_OPT} csu/subdir_lib

    #
    #Cのスタートアップルーチンを${SYSROOT}の/usr/lib64にコピーする
    #（ディレクトリを作成してから, インストールする)
    #
    mkdir -pv ${SYSROOT}/usr/${_LIB}
    cp -pv csu/crt[1in].o ${SYSROOT}/usr/${_LIB}

    #libc.soを作るためには, libc.soのリンクオプション(-lc)を付けて, 
    #コンパイルを通す必要がある（実際にlibc.soの関数は呼ばないので
    #空のlibc.soでよい)
    #そこで、libgcc_s.soを作るために, ダミーのlibc.soを作る
    #http://crosstool-ng.org/download/crosstool-ng/crosstool-ng-1.16.0.tar.bz2
    #crosstool-ng-1.16.0/scripts/build/libc/glibc-eglibc.sh-common
    #の記述を参照して作成。
    #
    ${TARGET}-gcc  -nostdlib        \
        -nostartfiles    \
        -shared          \
        -x c /dev/null   \
        -o "${SYSROOT}/usr/${_LIB}/libc.so"

    popd

    #
    #stage2のコンパイラはsysrootのlibにcrtを見に行くので以下の処理を追加。
    #
    if [ ! -d ${SYSROOT}/lib ]; then
	mkdir -p ${SYSROOT}/lib
    fi

    pushd ${SYSROOT}/lib
    rm -f libc.so crt1.o crti.o crtn.o
    ln -sv ../usr/${_LIB}/libc.so
    ln -sv ../usr/${_LIB}/crt1.o
    ln -sv ../usr/${_LIB}/crti.o
    ln -sv ../usr/${_LIB}/crtn.o
    popd

    #
    #バイアーキ版のコンパイラ生成にも対応できるように, 
    #libgcc_so生成時にインストール先の/lib64配下にもスタートアップを
    #見に行けるように以下の処理を実施
    #
    if [ "x${_LIB}" != "xlib" ]; then
	mkdir -pv ${SYSROOT}/${_LIB}
	pushd ${SYSROOT}/${_LIB}
	rm -f libc.so crt1.o crti.o crtn.o
	ln -sv ../usr/${_LIB}/libc.so
	ln -sv ../usr/${_LIB}/crt1.o
	ln -sv ../usr/${_LIB}/crti.o
	ln -sv ../usr/${_LIB}/crtn.o
	popd
    fi
}

## begin note
# 機能:共有ライブラリ版libc.soの生成に必要なlibgcc_eh.a付きのコンパイラを生成する
## end note
do_cross_gcc_core2(){

    echo "@@@ Cross:gcc-core-stage2 @@@"
    
    extract_archive ${GCC}

    pushd ${CROSS}/bin
    echo "Remove old gcc"
    rm -f ${TARGET}-gcc*
    popd

    rm -fr ${BUILDDIR}/${GCC}
    mkdir -p ${BUILDDIR}/${GCC}
    pushd  ${BUILDDIR}/${GCC}

    #
    # configureの設定
    #
    #ビルド環境のコンパイラ/binutilsの版数に依存しないようにビルド向けに生成した
    #コンパイラとbinutilsを使用して構築を行うための設定を実施
    #
    #CC_FOR_BUILD="${BUILD}-gcc"
    #   構築時に使用するCコンパイラを指定
    #CXX_FOR_BUILD="${BUILD}-g++"
    #   構築時に使用するC++コンパイラを指定
    #AR_FOR_BUILD="${BUILD}-ar"
    #   構築時に使用するarを指定    
    #LD_FOR_BUILD="${BUILD}-ld"
    #   構築時に使用するranlibを指定    
    #RANLIB_FOR_BUILD="${BUILD}-ranlib"
    #
    #--prefix=${CROSS}
    #          ${CROSS}配下にインストールする
    #--build=${BUILD}
    #          ビルド環境を指定する
    #--host=${BUILD}
    #          ビルド環境で動作するコンパイラを構築する
    #--target=${TARGET}
    #          ターゲット環境向けのコードを生成するコンパイラを構築する
    #--with-local-prefix=${CROSS}/${TARGET}
    #          gcc内部で使用するファイルを${CROSS}/${TARGET}に格納する
    #${WITH_SYSROOT}
    #          コンパイラの実行時にターゲット用のルートファイルシステムを優先してヘッダや
    #          ライブラリを探査する
    #--enable-languages=c
    #          カーネルヘッダの生成からCスタートアップルーチン(crt*.o)の生成までに必要なCコンパイラのみを生成
    #--enable-shared
    #          gccの共有ランタイムライブラリを生成する
    #--disable-bootstrap
    #          ビルド環境もgccを使用することから, 時間削減のためビルド環境とホスト環境が
    #          同一CPUの場合でも, 3stageコンパイルを無効にする
    #--disable-werror
    #         警告をエラーと見なさない
    #--disable-multilib
    #          バイアーキ(32/64bit両対応)版gccの生成を行わない。
    #--disable-threads
    #          ターゲット用のlibpthreadがないためスレッドライブラリに対応しない
    #--disable-libmudflap
    #          mudflap( バッファオーバーフロー、メモリリーク、
    #          ポインタの誤使用等を実行時に検出するライブラリ)
    #          を構築しない.
    #--disable-libatomic
    #          アトミック処理用ライブラリを生成しない 
    #--disable-libitm
    #          トランザクショナルメモリ操作ライブラリを生成しない
    #--disable-libquadmath
    #          4倍精度数学ライブラリを生成しない
    #--disable-libvtv
    #          Virtual Table Verification(仮想関数テーブル攻撃対策)
    #          ライブラリを生成しない
    #--disable-libcilkrts
    #           Cilkランタイムライブラリを生成しない
    #--disable-libssp
    #           -fstack-protector-all オプションを無効化する
    #           (Stack Smashing Protector機能を無効にする)
    #--disable-libmpx
    #           MPX(Memory Protection Extensions)ライブラリをビルドしない
    #--disable-libgomp
    #           GNU OpenMPライブラリを生成しない
    #--disable-libsanitizer
    #           libsanitizerを無効にする(gcc-4.9のlibsanitizerは
    #           バグのためコンパイルできないため)
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
    #--disable-nls
    #         コンパイル時間を短縮するためNative Language Supportを無効化する
    #
    CC_FOR_BUILD="${BUILD}-gcc"                              \
    CXX_FOR_BUILD="${BUILD}-g++"                             \
    AR_FOR_BUILD="${BUILD}-ar"                               \
    LD_FOR_BUILD="${BUILD}-ld"                               \
    RANLIB_FOR_BUILD="${BUILD}-ranlib"                       \
    ${SRCDIR}/${GCC}/configure                               \
	--prefix=${CROSS}                                    \
        --build=${BUILD}                                     \
        --host=${BUILD}                                      \
	--target=${TARGET}                                   \
	--with-local-prefix=${CROSS}/${TARGET}               \
	"${WITH_SYSROOT}"                                    \
	--enable-languages=c                                 \
	--enable-shared                                      \
	--disable-bootstrap                                  \
	--disable-werror                                     \
	--disable-multilib                                   \
	--disable-threads                                    \
	--disable-lto                                        \
	--disable-decimal-float                              \
	--disable-libatomic                                  \
	--disable-libitm                                     \
        --disable-libquadmath                                \
	--disable-libvtv                                     \
	--disable-libcilkrts                                 \
	--disable-libmudflap                                 \
	--disable-libssp                                     \
	--disable-libmpx                                     \
	--disable-libgomp                                    \
	--disable-libsanitizer                               \
	--with-gmp=${CROSS}                                  \
	--with-mpfr=${CROSS}                                 \
	--with-mpc=${CROSS}                                  \
	--with-isl=${CROSS}                                  \
	--with-libelf=${CROSS}                               \
	--disable-nls

    #
    #cpp/libiberty(GNU共通基盤ライブラリ)の構築
    #
    make configure-gcc configure-libcpp configure-build-libiberty
    make ${SMP_OPT} all-libcpp all-build-libiberty

    #
    #libdecnumber/libbacktrace(gccの動作に必須なライブラリ)の構築
    #
    make configure-libdecnumber
    make ${SMP_OPT} -C libdecnumber libdecnumber.a
    make configure-libbacktrace
    make ${SMP_OPT} -C libbacktrace

    #
    #libgccのコンパイルオプション定義を生成し,
    #libcはまだないことから, -lcを除去する
    #
    make ${SMP_OPT} -C gcc libgcc.mvars
    sed -r -i -e 's@-lc@@g' gcc/libgcc.mvars

    #
    #gcc(Cコンパイラ)とアーキ共通基盤ライブラリ(libgcc)の構築
    #
    make ${SMP_OPT} all-gcc all-target-libgcc
    ${SUDO} make install-gcc install-target-libgcc
    
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
    pushd ${CROSS}/bin
    echo "rm cpp gcc gcc-ar gcc-nm gcc-ranlib gcov on ${CROSS}/bin"
    rm -f cpp gcc gcc-ar gcc-nm gcc-ranlib gcov ${TARGET}-cc
    #
    # クロスコンパイラへのリンクを張る
    #
    ln -sf ${TARGET}-gcc ${TARGET}-cc
    popd
}

## begin note
# 機能:glibcのライブラリ部分のみをコンパイル・インストールする
## end note
do_glibc_core(){

    echo "@@@ Cross:cross-glibc-core @@@"

    extract_archive ${GLIBC}

    #
    #glibcの場合,
    #ライブラリ部分のみをコンパイル・インストールするためのmakeターゲット
    #(install-lib-all)を追加するソースパッチを適用する
    #
    pushd  ${SRCDIR}/${GLIBC}
    patch -p1 < ${WORKDIR}/patches/cross/glibc/install-lib-all.patch
    popd
    
    rm -fr ${BUILDDIR}/${GLIBC}
    mkdir ${BUILDDIR}/${GLIBC}
    pushd ${BUILDDIR}/${GLIBC}

    
    # CFLAGS="-O -finline-functions"
    #   コンパイルオプションに -finline-functions
    #   を指定する(インライン関数が使用できることを前提にglibcが
    #   書かれているため, -Oを指定した場合、 -finline-functionsがないと
    #   コンパイルできない). -O3を指定した場合のライブラリを使用すると
    #   プログラムが動作しないことがあったため, -Oでコンパイルする。
    # --prefix=${CROSS}        
    #          ${CROSS}配下にインストールする
    # --build=${BUILD}
    #        ${BUILD}で指定されたマシン上でコンパイルする
    #        (${BUILD}-プレフィクス付きのツールを明に使用する)
    # --host=${TARGET}
    #        ${TARGET}で指定されたマシン上で動作するlibcを生成する
    # --target=${TARGET}
    #        ${TARGET}で指定されたマシン上で動作するバイナリを出力する
    #        ツール群を作成する
    #  --prefix=/usr
    #           /usr/include,/usr/lib64,/usr/lib配下にヘッダ・ライブラリ
    #           をインストールする
    #  --without-cvs
    #          CVSからのソース獲得を行わない
    #  --disable-profile
    #          gprof対応版ライブラリを生成しない
    #  --without-gd
    #          GDグラフックライブラリが必要なツールを生成しない
    #  --disable-debug
    #          デバッグオプションを指定しない
    #  --with-headers=${SYSROOT}/usr/include
    #          ${SYSROOT}/usr/include配下のヘッダを参照する
    #  --enable-add-ons=nptl,libidn             
    #          NPTLをスレッドライブラリに, libidn国際ドメイン名ライブラリ
    #          を構築する(実際にはスタートアップルーチンのみ構築)
    #  --enable-kernel=${GLIBC_ENABLE_KERNEL}
    #          動作可能なカーネルの範囲（動作可能な範囲で最も古いカーネルの
    #          版数を指定する(上記のGLIBC_ENABLE_KERNELの設定値説明を参照)
    #  --disable-nscd
    #          ヘッダの生成のみを行うため, nscdのコンパイルをしない
    #  --disable-werror
    #         警告をエラーと見なさない
    #  --disable-systemtap
    #          ターゲット用のsystemtapがないため, systemtap対応無しで
    #          コンパイルする
    #  --disable-obsolete-rpc
    #          ライブラリ生成のみを行うため, 廃止されたrpcライブラリを
    #          生成しない
    #  --without-selinux                      
    #          ターゲット用のlibselinuxがないため, selinux対応無しで
    #          コンパイルする
    #  --disable-mathvec
    #          mathvecを作成しない(libmが必要となるため)
    #
    CFLAGS="-O -finline-functions"               \
	${SRCDIR}/${GLIBC}/configure             \
        --build=${BUILD}                         \
        --host=${TARGET}                         \
        --target=${TARGET}                       \
        --prefix=/usr                            \
        --without-cvs                            \
        --disable-profile                        \
        --without-gd                             \
        --disable-debug                          \
        --disable-sanity-checks                  \
	--disable-mathvec                        \
        --with-headers=${SYSROOT}/usr/include    \
        --enable-kernel=${GLIBC_ENABLE_KERNEL}   \
        --enable-add-ons=nptl,libidn,ports       \
	  --disable-werror                       \
          --disable-systemtap                    \
          --disable-obsolete-rpc                 \
          --without-selinux

    #
    #以下のconfigparmsは, make-3.82対応のために必要
    #make-3.82は, makeの引数で以下のオプションを引き渡せない障害があるので,
    #configparmに設定を記載.
    #
    #http://sourceware.org/bugzilla/show_bug.cgi?id=13810
    #Christer Solskogen 2012-03-06 14:18:58 UTC 
    #の記事参照
    #
    #cross-compiling=yes
    #   クロスコンパイルを行う
    #
    #install_root=${SYSROOT}
    #   ${SYSROOT}配下にインストールする. --prefixに/usrを設定しているので
    #   ${SYSROOT}/usr/include配下にヘッダをインストールする意味となる.
    #
    cat >> configparms<<EOF
cross-compiling=yes
install_root=${SYSROOT}
EOF
    #
    #libgcc_eh.a付きのコンパイラ生成時に一時的に作成したlibc.soを削除する
    #
    echo "Remove pseudo libc.so"
    rm -f ${SYSROOT}/${_LIB}/libc.so
    rm -f ${SYSROOT}/lib/libc.so

    if [ ! -f ${SRCDIR}/${GLIBC}/EGLIBC.cross-building ]; then
	MAKE_TARGET=lib
    else
	MAKE_TARGET=""
    fi

    #
    #sysroot配下にライブラリがインストールされていないため,
    #libcの附属コマンドは構築できない.
    #このことから, ライブラリのみを構築する.
    #malloc/libmemusage.soのビルドで止まるため, -iをつけて強制インストールする
    BUILD_CC="${BUILD}-gcc"                \
    CFLAGS="-O  -finline-functions"        \
    CC=${TARGET}-gcc                       \
    AR=${TARGET}-ar                        \
    LD=${TARGET}-ld                        \
    RANLIB=${TARGET}-ranlib                \
    make -i ${SMP_OPT} ${MAKE_TARGET}

    INSTALL_TARGET=install-lib-all


    echo "@@@@ Install with :${INSTALL_TARGET} @@@@"

    #
    #構築したライブラリのインストール
    #
    BUILD_CC="${BUILD}-gcc"         \
    CFLAGS="-O  -finline-functions" \
    CC=${TARGET}-gcc                \
    AR=${TARGET}-ar                 \
    LD=${TARGET}-ld                 \
    RANLIB=${TARGET}-ranlib         \
    ${SUDO} make -i install_root=${SYSROOT} ${INSTALL_TARGET}

    #
    #リンクを張り直す
    #
    pushd ${SYSROOT}/lib
    rm -f libc.so crt1.o crti.o crtn.o
    ln -sv ../usr/${_LIB}/libc.so
    ln -sv ../usr/${_LIB}/crt1.o
    ln -sv ../usr/${_LIB}/crti.o
    ln -sv ../usr/${_LIB}/crtn.o
    popd

    if [ "x${_LIB}" != "xlib" ]; then
	mkdir -p ${SYSROOT}/${_LIB}
	pushd ${SYSROOT}/${_LIB}
	rm -f libc.so crt1.o crti.o crtn.o
	ln -sv ../usr/${_LIB}/libc.so
	ln -sv ../usr/${_LIB}/crt1.o
	ln -sv ../usr/${_LIB}/crti.o
	ln -sv ../usr/${_LIB}/crtn.o
	popd
    fi

    popd    
}

## begin note
# 機能:glibcを作るためのクロスコンパイラを生成する
## end note
do_cross_gcc_core3(){

    echo "@@@ Cross:gcc-core3 @@@"

    extract_archive ${GCC}

    pushd ${CROSS}/bin
    echo "Remove old gcc"
    rm -f ${TARGET}-gcc*
    popd

    rm -fr  ${BUILDDIR}/${GCC}
    mkdir -p ${BUILDDIR}/${GCC}
    pushd  ${BUILDDIR}/${GCC}

    #
    # configureの設定
    #
    # --prefix=${CROSS}        
    #          ${CROSS}配下にインストールする
    # --with-local-prefix=${CROSS}/${TARGET}
    #        ${CROSS}/${TARGET}にgcc内部で使用するファイルを配置する
    # --enable-shared
    #          共有ライブラリ版のgccランタイムライブラリを生成する
    # --disable-bootstrap
    #          オウンコンパイル時でも3stageコンパイルを行わない
    # --disable-werror
    #         警告をエラーと見なさない
    # --enable-languages=c
    #          gcc/glibcの構築に必要な, C/C++を生成する.
    # --disable-multilib
    #          32bit/64bit共通のコンパイラを生成しない。
    #          bit共通のコンパイラを使用すると-m 64オプションが渡らない
    #          ことによるコンパイル不良が発生しやすい。
    #          このため, 64bitと32bitでコンパイラを分けて生成できるように
    #          本オプションを設定する.
    # --enable-threads=posix
    #          posix threadと連動して動作するようTLS
    #          (スレッドローカルストレージ)を扱う
    # --enable-symvers=gnu
    #          GNUのツールチェインで標準的に使用されるシンボルバージョニング
    #          を行う。
    # --enable-__cxa_atexit
    #          C++の例外処理とatexitライブラリコールとを連動させる
    # --enable-c99
    #          C99仕様を受け付ける
    # --enable-long-long
    #          long long型を有効にする
    #--disable-libmudflap
    #          mudflap( バッファオーバーフロー、メモリリーク、
    #          ポインタの誤使用等を実行時に検出するライブラリ)
    #          を構築しない.
    #--disable-libatomic
    #          アトミック処理用ライブラリを生成しない 
    #--disable-libitm
    #          トランザクショナルメモリ操作ライブラリを生成しない
    #--disable-libquadmath
    #          4倍精度数学ライブラリを生成しない
    #--disable-libvtv
    #          Virtual Table Verification(仮想関数テーブル攻撃対策)
    #          ライブラリを生成しない
    #--disable-libcilkrts
    #           Cilkランタイムライブラリを生成しない
    #--disable-libssp
    #           -fstack-protector-all オプションを無効化する
    #           (Stack Smashing Protector機能を無効にする)
    #--disable-libmpx
    #           MPX(Memory Protection Extensions)ライブラリをビルドしない
    #--disable-libgomp
    #           GNU OpenMPライブラリを生成しない
    #--disable-libsanitizer
    #           libsanitizerを無効にする(gcc-4.9のlibsanitizerは
    #           バグのためコンパイルできないため)
    # --with-gmp=${CROSS} 
    #          gmpをインストールしたディレクトリを指定
    # --with-mpfr=${CROSS} 
    #          mpfrをインストールしたディレクトリを指定
    # --with-isl=${CROSS} 
    #          islをインストールしたディレクトリを指定
    # --disable-libsanitizer
    #           libsanitizerを無効にする
    #    (gcc-4.9のlibsanitizerはバグのためコンパイルできないため)
    # --with-libelf=${CROSS}
    #          libelfをインストールしたディレクトリを指定
    # ${WITH_SYSROOT}
    #          コンパイラの実行時にターゲット用のルートファイルシステムを優先してヘッダや
    #          ライブラリを探査する
    # ${LINK_STATIC_LIBSTDCXX} 
    #          libstdc++を静的リンクしパスに依存せず動作できるようにする
    # --disable-nls
    #         コンパイル時間を短縮するためNative Language Supportを無効化する
    #
    CC_FOR_BUILD="${BUILD}-gcc"                              \
    CXX_FOR_BUILD="${BUILD}-g++"                             \
    AR_FOR_BUILD="${BUILD}-ar"                               \
    LD_FOR_BUILD="${BUILD}-ld"                               \
    RANLIB_FOR_BUILD="${BUILD}-ranlib"                       \
    ${SRCDIR}/${GCC}/configure                               \
	--prefix=${CROSS}                                    \
        --build=${BUILD}                                     \
        --host=${BUILD}                                      \
	--target=${TARGET}                                   \
	--with-local-prefix=${CROSS}/${TARGET}               \
	--disable-bootstrap                                  \
	--disable-werror                                     \
	--enable-shared                                      \
	--enable-languages=c                                 \
	--disable-multilib                                   \
	--enable-threads=posix                               \
	--enable-symvers=gnu                                 \
	--enable-__cxa_atexit                                \
	--enable-c99                                         \
	--enable-long-long                                   \
	--disable-lto                                        \
	--disable-decimal-float                              \
	--disable-libatomic                                  \
	--disable-libitm                                     \
        --disable-libquadmath                                \
	--disable-libvtv                                     \
	--disable-libcilkrts                                 \
	--disable-libmudflap                                 \
	--disable-libssp                                     \
	--disable-libmpx                                     \
	--disable-libgomp                                    \
	--disable-libsanitizer                               \
	--with-gmp=${CROSS}                                  \
	--with-mpfr=${CROSS}                                 \
	--with-mpc=${CROSS}                                  \
	--with-isl=${CROSS}                                  \
	--with-libelf=${CROSS}                               \
	"${WITH_SYSROOT}"                                    \
	"${LINK_STATIC_LIBSTDCXX}"                           \
	--with-long-double-128                               \
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
    #リンクを張り直す
    #
    pushd ${SYSROOT}/lib
    rm -f libc.so crt1.o crti.o crtn.o
    ln -sv ../usr/${_LIB}/libc.so
    ln -sv ../usr/${_LIB}/crt1.o
    ln -sv ../usr/${_LIB}/crti.o
    ln -sv ../usr/${_LIB}/crtn.o
    popd

    if [ "x${_LIB}" != "xlib" ]; then
	mkdir -p ${SYSROOT}/${_LIB}
	pushd ${SYSROOT}/${_LIB}
	rm -f libc.so crt1.o crti.o crtn.o
	ln -sv ../usr/${_LIB}/libc.so
	ln -sv ../usr/${_LIB}/crt1.o
	ln -sv ../usr/${_LIB}/crti.o
	ln -sv ../usr/${_LIB}/crtn.o
	popd
    fi

}


## begin note
# 機能:クロスコンパイラを生成する
## end note
do_cross_gcc(){

    echo "@@@ Cross:gcc @@@"

    extract_archive ${GCC}

    pushd ${CROSS}/bin
    echo "Remove old gcc"
    rm -f ${TARGET}-gcc*
    popd

    rm -fr  ${BUILDDIR}/${GCC}
    mkdir -p ${BUILDDIR}/${GCC}
    pushd  ${BUILDDIR}/${GCC}

    #
    # configureの設定
    #
    # --prefix=${CROSS}        
    #          ${CROSS}配下にインストールする
    # --with-local-prefix=${CROSS}/${TARGET}
    #        ${CROSS}/${TARGET}にgcc内部で使用するファイルを配置する
    # --enable-shared
    #          共有ライブラリ版のgccランタイムライブラリを生成する
    # --disable-bootstrap
    #          オウンコンパイル時でも3stageコンパイルを行わない
    # --disable-werror
    #         警告をエラーと見なさない
    # --enable-languages=c
    #          gcc/glibcの構築に必要な, C/C++を生成する.
    # --disable-multilib
    #          32bit/64bit共通のコンパイラを生成しない。
    #          bit共通のコンパイラを使用すると-m 64オプションが渡らない
    #          ことによるコンパイル不良が発生しやすい。
    #          このため, 64bitと32bitでコンパイラを分けて生成できるように
    #          本オプションを設定する.
    # --enable-threads=posix
    #          posix threadと連動して動作するようTLS
    #          (スレッドローカルストレージ)を扱う
    # --enable-symvers=gnu
    #          GNUのツールチェインで標準的に使用されるシンボルバージョニング
    #          を行う。
    # --enable-__cxa_atexit
    #          C++の例外処理とatexitライブラリコールとを連動させる
    # --enable-c99
    #          C99仕様を受け付ける
    # --enable-long-long
    #          long long型を有効にする
    # --enable-libmudflap
    #          mudflap( バッファオーバーフロー、メモリリーク、
    #          ポインタの誤使用等を実行時に検出するライブラリ)
    #          を構築する.
    # --enable-libssp
    #           -fstack-protector-all オプションを使えるようにする
    #           (Stack Smashing Protector機能を有効にする)
    # --enable-libgomp
    #           GNU OpenMP ライブラリを生成する
    # --with-gmp=${CROSS} 
    #          gmpをインストールしたディレクトリを指定
    # --with-mpfr=${CROSS} 
    #          mpfrをインストールしたディレクトリを指定
    # --with-isl=${CROSS} 
    #          islをインストールしたディレクトリを指定
    # --disable-libsanitizer
    #           libsanitizerを無効にする
    #    (gcc-4.9のlibsanitizerはバグのためコンパイルできないため)
    # --with-libelf=${CROSS}
    #          libelfをインストールしたディレクトリを指定
    # ${WITH_SYSROOT}
    #          コンパイラの実行時にターゲット用のルートファイルシステムを優先してヘッダや
    #          ライブラリを探査する
    # ${LINK_STATIC_LIBSTDCXX} 
    #          libstdc++を静的リンクしパスに依存せず動作できるようにする
    # --disable-nls
    #         コンパイル時間を短縮するためNative Language Supportを無効化する
    #
    CC_FOR_BUILD="${BUILD}-gcc"                              \
    CXX_FOR_BUILD="${BUILD}-g++"                             \
    AR_FOR_BUILD="${BUILD}-ar"                               \
    LD_FOR_BUILD="${BUILD}-ld"                               \
    RANLIB_FOR_BUILD="${BUILD}-ranlib"                       \
    ${SRCDIR}/${GCC}/configure                               \
	--prefix=${CROSS}                                    \
        --build=${BUILD}                                     \
        --host=${BUILD}                                      \
	--target=${TARGET}                                   \
	--with-local-prefix=${CROSS}/${TARGET}               \
	--disable-bootstrap                                  \
	--disable-werror                                     \
	--enable-shared                                      \
	--enable-languages=c,c++                             \
	--disable-multilib                                   \
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
	"${WITH_SYSROOT}"                                    \
	"${LINK_STATIC_LIBSTDCXX}"                           \
	--with-long-double-128                               \
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
    #リンクを張り直す
    #
    pushd ${SYSROOT}/lib
    rm -f libc.so crt1.o crti.o crtn.o
    ln -sv ../usr/${_LIB}/libc.so
    ln -sv ../usr/${_LIB}/crt1.o
    ln -sv ../usr/${_LIB}/crti.o
    ln -sv ../usr/${_LIB}/crtn.o
    popd

    if [ "x${_LIB}" != "xlib" ]; then
	mkdir -p ${SYSROOT}/${_LIB}
	pushd ${SYSROOT}/${_LIB}
	rm -f libc.so crt1.o crti.o crtn.o
	ln -sv ../usr/${_LIB}/libc.so
	ln -sv ../usr/${_LIB}/crt1.o
	ln -sv ../usr/${_LIB}/crti.o
	ln -sv ../usr/${_LIB}/crtn.o
	popd
    fi

}

## begin note
# 機能:クロスコンパイラから使用するglibc一式を生成する
## end note
do_cross_glibc(){

    echo "@@@ Cross:glibc @@@"

    extract_archive ${GLIBC}
    
    rm -fr ${BUILDDIR}/${GLIBC}
    mkdir ${BUILDDIR}/${GLIBC}
    pushd ${BUILDDIR}/${GLIBC}
 
    # CFLAGS="-O -finline-functions"
    #   コンパイルオプションに -finline-functions
    #   を指定する(インライン関数が使用できることを前提にglibcが
    #   書かれているため, -Oを指定した場合、 -finline-functionsがないと
    #   コンパイルできない). -O3を指定した場合のライブラリを使用すると
    #   プログラムが動作しないことがあったため, -Oでコンパイルする。
    # --prefix=${CROSS}        
    #          ${CROSS}配下にインストールする
    # --build=${BUILD}
    #        ${BUILD}で指定されたマシン上でコンパイルする
    #        (${BUILD}-プレフィクス付きのツールを明に使用する)
    # --host=${TARGET}
    #        ${TARGET}で指定されたマシン上で動作するlibcを生成する
    # --target=${TARGET}
    #        ${TARGET}で指定されたマシン上で動作するバイナリを出力する
    #        ツール群を作成する
    #  --prefix=/usr
    #           /usr/include,/usr/lib64,/usr/lib配下にヘッダ・ライブラリ
    #           をインストールする
    #  --without-cvs
    #          CVSからのソース獲得を行わない
    #  --disable-profile
    #          gprof対応版ライブラリを生成しない
    #  --without-gd
    #          GDグラフックライブラリが必要なツールを生成しない
    #  --disable-debug
    #          デバッグオプションを指定しない
    #  --with-headers=${SYSROOT}/usr/include
    #          ${SYSROOT}/usr/include配下のヘッダを参照する
    #  --enable-add-ons=nptl,libidn             
    #          NPTLをスレッドライブラリに, libidn国際ドメイン名ライブラリ
    #          を構築する(実際にはスタートアップルーチンのみ構築)
    #  --enable-kernel=${GLIBC_ENABLE_KERNEL}
    #          動作可能なカーネルの範囲（動作可能な範囲で最も古いカーネルの
    #          版数を指定する(上記のGLIBC_ENABLE_KERNELの設定値説明を参照)
    #  --disable-werror
    #          警告をエラーと見なさない
    #  --disable-systemtap
    #          ターゲット用のsystemtapがないため, systemtap対応無しでコンパイルする
    #  --without-selinux                      
    #          ターゲット用のlibselinuxがないため, selinux対応無しでコンパイルする
    #
    BUILD_CC="${BUILD}-gcc"                      \
    BUILD_AR="${BUILD}-ar"                       \
    BUILD_LD="${BUILD}-ld"                       \
    BUILD_RANLIB="${BUILD}-ranlib"               \
    CC=${TARGET}-gcc                             \
    AR=${TARGET}-ar                              \
    LD=${TARGET}-ld                              \
    RANLIB=${TARGET}-ranlib                      \
    CFLAGS="-O -finline-functions"               \
	${SRCDIR}/${GLIBC}/configure             \
        --build=${BUILD}                         \
        --host=${TARGET}                         \
        --target=${TARGET}                       \
        --prefix=/usr                            \
        --without-cvs                            \
        --disable-profile                        \
        --without-gd                             \
        --disable-debug                          \
        --disable-sanity-checks                  \
        --with-headers=${SYSROOT}/usr/include    \
        --enable-kernel=${GLIBC_ENABLE_KERNEL}   \
        --enable-add-ons=nptl,libidn,ports       \
	  --disable-werror                       \
          --disable-systemtap                    \
          --without-selinux

    #
    #以下のconfigparmsは, make-3.82対応のために必要
    #make-3.82は, makeの引数で以下のオプションを引き渡せない障害があるので,
    #configparmに設定を記載.
    #
    #http://sourceware.org/bugzilla/show_bug.cgi?id=13810
    #Christer Solskogen 2012-03-06 14:18:58 UTC 
    #の記事参照
    #
    #cross-compiling=yes
    #   クロスコンパイルを行う
    #
    #install_root=${SYSROOT}
    #   ${SYSROOT}配下にインストールする. --prefixに/usrを設定しているので
    #   ${SYSROOT}/usr/include配下にヘッダをインストールする意味となる.
    #
    cat >> configparms<<EOF
cross-compiling=yes
install_root=${SYSROOT}
EOF

      BUILD_CC="${BUILD}-gcc"                \
      BUILD_AR="${BUILD}-ar"          \
      BUILD_LD="${BUILD}-ld"          \
      BUILD_RANLIB="${BUILD}-ranlib"  \
      CFLAGS="-O  -finline-functions"        \
      CC=${TARGET}-gcc                       \
      AR=${TARGET}-ar                        \
      LD=${TARGET}-ld                        \
      RANLIB=${TARGET}-ranlib                \
      make ${SMP_OPT} all

      pushd ${SYSROOT}/lib
      rm -f libc.so crt1.o crti.o crtn.o
      popd

      pushd ${SYSROOT}/${_LIB}
      rm -f libc.so crt1.o crti.o crtn.o
      popd

      BUILD_CC="${BUILD}-gcc"         \
      BUILD_AR="${BUILD}-ar"          \
      BUILD_LD="${BUILD}-ld"          \
      BUILD_RANLIB="${BUILD}-ranlib"  \
      CFLAGS="-O  -finline-functions" \
      CC=${TARGET}-gcc                \
      AR=${TARGET}-ar                 \
      LD=${TARGET}-ld                 \
      RANLIB=${TARGET}-ranlib         \
      ${SUDO} make install_root=${SYSROOT} install

      popd    

    #
    #multilib非対応のコンパイラはsysrootのlibにcrtを見に行くので以下の処理を追加。
    #
    if [ ! -d ${SYSROOT}/lib ]; then
	mkdir -p ${SYSROOT}/lib
    fi

    pushd ${SYSROOT}/lib
    rm -f crt1.o crti.o crtn.o
    ln -sv ../usr/${_LIB}/crt1.o
    ln -sv ../usr/${_LIB}/crti.o
    ln -sv ../usr/${_LIB}/crtn.o
    popd

}

## begin note
# 機能:クロスデバッガを生成する
## end note
do_cross_gdb(){

    echo "@@@ Cross:gdb @@@"

    extract_archive ${GDB}

    pushd  ${SRCDIR}/${GDB}
    patch -p1 < ${WORKDIR}/patches/gdb/gdb-8.2-qemu-x86-64.patch
    popd

    rm -fr  ${BUILDDIR}/${GDB}
    mkdir -p ${BUILDDIR}/${GDB}
    pushd  ${BUILDDIR}/${GDB}

    #
    # configureの設定
    #
    # --prefix=${CROSS}        
    #          ${CROSS}配下にインストールする
    # --with-local-prefix=${CROSS}/${TARGET}
    #        ${CROSS}/${TARGET}にgcc内部で使用するファイルを配置する
    # --disable-werror
    #         警告をエラーと見なさない
    # --disable-nls
    #         コンパイル時間を短縮するためNative Language Supportを無効化する
    #
    CC_FOR_BUILD="${BUILD}-gcc"                              \
    CXX_FOR_BUILD="${BUILD}-g++"                             \
    AR_FOR_BUILD="${BUILD}-ar"                               \
    LD_FOR_BUILD="${BUILD}-ld"                               \
    RANLIB_FOR_BUILD="${BUILD}-ranlib"                       \
    ${SRCDIR}/${GDB}/configure                               \
	--prefix=${CROSS}                                    \
        --build=${BUILD}                                     \
        --host=${BUILD}                                      \
	--target=${TARGET}                                   \
	--with-local-prefix=${CROSS}/${TARGET}               \
	--disable-werror                                     \
	--disable-nls

    make ${SMP_OPT} 
    ${SUDO} make  install

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

    CC="cc"                        \
    CXX="c++"                      \
    AR="ar"                        \
    LD="ld"                        \
    RANLIB="ranlib"                \
    ./configure                          \
     --prefix=${CROSS}                   \
     --interp-prefix=${SYSROOT}          \
     --target-list="${QEMU_TARGETS}"     \
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
	    cp Build/OvmfIA32/DEBUG_GCC5/FV/*.fd ${CROSS}/uefi
	    ;;
	* ) 
	    echo "@@@ EDK2 UEFI @@@"
	    echo "Skip building UEFI for ${TARGET_CPU}"
	    ;;
    esac

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
# 機能:クロスコンパイル環境のテスト
## end note
do_cross_compile_test(){

    echo "@@@ cross compiler test @@@"
    echo "Compiler: ${CROSS}/bin/${TARGET}-gcc"
    echo "QEmu: ${CROSS}/bin/qemu-${QEMU_CPU}"
    rm -f hello
    ${CROSS}/bin/${TARGET}-gcc -o hello ${WORKDIR}/scripts/hello.c
    ${CROSS}/bin/${TARGET}-gcc -O3 ${SAMPLE_COMPILE_OPT} -DMIDDLE -o himenoM \
	${WORKDIR}/scripts/himenoBMTxps.c
    file hello
    file himenoM
    echo "@@ Run hello world @@"
    ${CROSS}/bin/qemu-${QEMU_CPU} hello
    if [ "x${RUN_HIMENO}" != 'x' ]; then
	echo "@@ Run himeno bench (Middle Size) @@"
	${CROSS}/bin/qemu-${QEMU_CPU} himenoM
    fi
    rm -f hello himenoM
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
# 機能:クロスコンパイル環境一式を生成する
## end note
main(){

    setup_variables

    show_info

if [ "x${NO_DEVENV}" = 'x' ]; then
    prepare_devenv
fi
    prepare_archives

    cleanup_directories

    create_directories
    
    do_build_gmake_for_build
    do_build_gtar_for_build
    do_build_binutils_for_build
    do_build_gmp
    do_build_mpfr
    do_build_mpc
    do_build_isl
    do_build_elfutils
    do_build_gcc_for_build

    do_cross_binutils
    do_cross_gcc_core1
    do_kernel_headers
    do_glibc_headers
    do_glibc_startup
    do_cross_gcc_core2
    do_glibc_core
    do_cross_gcc_core3
    do_cross_glibc
    do_cross_gcc
    do_cross_gdb

    case "${TARGET_CPU}" in
	aarch64|x86_64)
	    do_cross_uefi
	    ;;
	i[3456]86)
	    echo "Skip building UEFI for ${TARGET_CPU} because some distribution does not support no-PIE."
	    ;;
	* ) 
	    echo "Skip building UEFI for ${TARGET_CPU}"
	    ;;
    esac

    do_build_emulator

    do_strip_binaries

    create_symlink

    do_cross_compile_test

    cleanup_temporary_directories
}

main $@
