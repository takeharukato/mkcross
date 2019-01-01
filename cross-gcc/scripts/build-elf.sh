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

    if [ "x${TARGET_ELF}" != "x" ]; then
	TARGET=${TARGET_ELF}
    else
	TARGET=${TARGET_CPU}-elf
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
	CROSS_PREFIX=${HOME}/cross/gcc-elf/${TARGET_CPU}
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

    #
    #libstdc++を静的リンクしパスに依存せず動作できるようにする
    #
    #LINK_STATIC_LIBSTDCXX="--with-host-libstdcxx=-static-libgcc -Wl,-Bstatic,-lstdc++,-Bdynamic -lm"
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
    echo "Tool chain type: ELF"
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
# 機能:開発環境をそろえる
## end note
prepare_devenv(){

    if [ "x${OSNAME}" = "xLinux" ]; then
	sudo yum install -y  coreutils yum-priorities epel-release yum-utils
	sudo yum groupinstall -y "Development tools"
	# For UEFI
	sudo yum install -y  nasm iasl acpica-tools
	# QEmu
	sudo yum install -y giflib-devel libpng-devel libtiff-devel gtk3-devel \
	    ncurses-devel gnutls-devel nettle-devel libgcrypt-devel SDL2-devel \
	    gtk-vnc-devel libguestfs-devel curl-devel brlapi-devel bluez-libs-devel \
	    libusb-devel libcap-ng-devel libiscsi-devel libnfs-devel libcacard-devel \
	    lzo-devel snappy-devel bzip2-devel libseccomp-devel libxml2-devel \
	    libssh2-devel xfsprogs-devel ceph-devel mesa-libGL-devel mesa-libGLES-devel \
            mesa-libGLU-devel mesa-libGLw-devel spice-server-devel libattr-devel \
	    libaio-devel sparse-devel gtkglext-libs vte-devel libtasn1-devel \
	    gperftools-devel virglrenderer device-mapper-multipath-devel \
	    cyrus-sasl-devel libjpeg-turbo-devel xen-devel glusterfs-api-devel \
	    libpmem-devel libudev-devel capstone-devel numactl-devel \
	    librdmacm-devel libibverbs-devel libibumad-devel gcc-objc \
	    iasl
	# Multilib
	sudo yum install -y  glibc-devel.i686 zlib-devel.i686 elfutils-devel.i686 \
	    mpfr-devel.i686 libstdc++-devel.i686
	sudo yum-builddep -y binutils gcc gdb qemu-kvm texinfo-tex texinfo
    fi
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
    #ビルド環境のtarより優先的に使用されるように
    #tar, gtarへのシンボリックリンクを張る
    #
    if [ -e ${BUILD_TOOLS_DIR}/bin/${BUILD}-tar ]; then
	pushd ${BUILD_TOOLS_DIR}/bin
	rm -f tar gtar
	ln -sv ${BUILD}-tar tar
	ln -sv ${BUILD}-tar gtar
	popd
    fi
}

## begin note
# 機能:GNU make-3.82以降を作成する。
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
    
    gmake ${SMP_OPT} 
    ${SUDO} gmake install
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
    
    gmake ${SMP_OPT} 
    ${SUDO} gmake install
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

    gmake ${SMP_OPT} 
    ${SUDO} gmake install
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

    gmake ${SMP_OPT} 
    ${SUDO} gmake install
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
    # --prefix=${CROSS}        
    #          ${CROSS}配下にインストールする
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
    ${SRCDIR}/${BINUTILS}/configure            \
	--prefix=${CROSS}                      \
	--target=${TARGET}                     \
	"${PROGRAM_PREFIX}"                    \
	--with-local-prefix=${CROSS}/${TARGET} \
	--disable-shared                       \
	--disable-werror                       \
	--disable-nls                          \
	"${WITH_SYSROOT}"
    
    gmake ${SMP_OPT} 
    ${SUDO} gmake install
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
# 機能:newlib構築用のクロスコンパイラを生成する
## end note
do_cross_gcc_core(){

    echo "@@@ Cross:gcc @@@"

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
    #--prefix=${CROSS}
    #          ${CROSS}配下にインストールする
    #--target=${TARGET}
    #          ターゲット環境向けのコードを生成するコンパイラを構築する
    #--with-local-prefix=${CROSS}/${TARGET}
    #          gcc内部で使用するファイルを${CROSS}/${TARGET}に格納する
    #--enable-languages=c
    #          カーネルヘッダの生成からCスタートアップルーチン(crt*.o)
    #          の生成までに必要なCコンパイラのみを生成 
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
    #          binutils/gcc/newlibの構築に不要なltoプラグインを生成しない
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
    #           libsanitizerを無効にする(gcc-4.9のlibsanitizerはバグの
    #           ためコンパイルできないため) 
    #--with-gmp=${CROSS}
    #          gmpをインストールしたディレクトリを指定
    #--with-mpfr=${CROSS} 
    #          mpfrをインストールしたディレクトリを指定
    #--with-mpc=${CROSS}
    #          mpcをインストールしたディレクトリを指定
    #--with-isl=${CROSS} 
    #          islをインストールしたディレクトリを指定
    #--disable-nls
    #         コンパイル時間を短縮するためNative Language Supportを無効化する
    #
    ${SRCDIR}/${GCC}/configure                               \
	--prefix=${CROSS}                                    \
	--target=${TARGET}                                   \
	--with-local-prefix=${CROSS}/${TARGET}               \
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
	--disable-nls
    
    gmake ${SMP_OPT}
    gmake install
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
# 機能:newlibを構築
## end note
do_cross_newlib(){

    echo "@@@ Cross: newlib @@@"

    extract_archive ${NEWLIB}

    rm -fr ${BUILDDIR}/${NEWLIB}
    mkdir -p ${BUILDDIR}/${NEWLIB}
    pushd  ${BUILDDIR}/${NEWLIB}

    #
    # configureの設定
    #
    #ビルド環境のコンパイラ/binutilsの版数に依存しないようにビルド向けに生成した
    #コンパイラとbinutilsを使用して構築を行うための設定を実施
    #
    #--prefix=${CROSS}
    #          ${CROSS}配下にインストールする
    #--target=${TARGET}
    #         ${TARGET}向けのライブラリを作成する
    #
    ${SRCDIR}/${NEWLIB}/configure              \
	--prefix=/usr                          \
	--target=${TARGET}
    
    gmake ${SMP_OPT}
    gmake DESTDIR=${SYSROOT} install

    #
    #includeとlibの位置を補正する
    #
    pushd ${SYSROOT}
    rm -fr ${SYSROOT}/usr/include ${SYSROOT}/usr/lib ${SYSROOT}/usr/lib64
    mv usr/${TARGET}/* usr
    rmdir usr/${TARGET}
    popd

    popd
}

## begin note
# 機能:クロスコンパイラを生成する
## end note
do_cross_gcc(){

    echo "@@@ Cross:gcc @@@"

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
    #--prefix=${CROSS}
    #          ${CROSS}配下にインストールする
    #--target=${TARGET}
    #          ターゲット環境向けのコードを生成するコンパイラを構築する
    #--with-local-prefix=${CROSS}/${TARGET}
    #          gcc内部で使用するファイルを${CROSS}/${TARGET}に格納する
    #${WITH_SYSROOT}
    #          コンパイラの実行時にターゲットのルートファイルシステムを優先してヘッダや
    #          ライブラリを探査する
    #--enable-languages=c
    #          カーネルヘッダの生成からCスタートアップルーチン(crt*.o)
    #          の生成までに必要なCコンパイラのみを生成 
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
    #--enable-tls
    #          Thread Local Storage機能を使用する
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
    #--disable-libssp
    #           -fstack-protector-all オプションを無効化する
    #           (Stack Smashing Protector機能を無効にする)
    #--disable-libmpx
    #           MPX(Memory Protection Extensions)ライブラリをビルドしない
    #--disable-libgomp
    #           GNU OpenMPライブラリを生成しない
    #--disable-libsanitizer
    #           libsanitizerを無効にする(gcc-4.9のlibsanitizerはバグの
    #           ためコンパイルできないため) 
    #--with-gmp=${CROSS}
    #          gmpをインストールしたディレクトリを指定
    #--with-mpfr=${CROSS} 
    #          mpfrをインストールしたディレクトリを指定
    #--with-mpc=${CROSS}
    #          mpcをインストールしたディレクトリを指定
    #--with-isl=${CROSS} 
    #          islをインストールしたディレクトリを指定
    #--disable-nls
    #         コンパイル時間を短縮するためNative Language Supportを無効化する
    #
    ${SRCDIR}/${GCC}/configure                               \
	--prefix=${CROSS}                                    \
	--target=${TARGET}                                   \
	--with-local-prefix=${CROSS}/${TARGET}               \
	"${WITH_SYSROOT}"                                    \
	--enable-languages="c,c++,lto"                       \
	--disable-bootstrap                                  \
	--disable-werror                                     \
	--disable-shared                                     \
	--disable-multilib                                   \
	--with-newlib                                        \
	--disable-threads                                    \
	--disable-libatomic                                  \
	--disable-libitm                                     \
	--disable-libvtv                                     \
	--disable-libcilkrts                                 \
	--disable-libmpx                                     \
	--disable-libgomp                                    \
	--disable-libsanitizer                               \
	--with-gmp=${CROSS}                                  \
	--with-mpfr=${CROSS}                                 \
	--with-mpc=${CROSS}                                  \
	--with-isl=${CROSS}                                  \
	--enable-decimal-float                               \
        --enable-libquadmath                                 \
	--enable-libmudflap                                  \
	--enable-libssp                                      \
	--enable-tls                                         \
	--disable-nls
    
    gmake ${SMP_OPT}
    gmake install
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
# 機能:クロスデバッガを生成する
## end note
do_cross_gdb(){

    echo "@@@ Cross:gdb @@@"

    extract_archive ${GDB}

    rm -fr  ${BUILDDIR}/${GDB}
    mkdir -p ${BUILDDIR}/${GDB}
    pushd  ${BUILDDIR}/${GDB}

    pushd  ${SRCDIR}/${GDB}
    patch -p1 < ${WORKDIR}/patches/gdb/gdb-8.2-qemu-x86-64.patch
    popd

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
    # --program-prefix="${TARGET}-"
    #         システムにインストールされているデバッガと区別するために, 
    #         プログラムのプレフィクスに${TARGET}-をつける。
    #
    ${SRCDIR}/${GDB}/configure                               \
	--prefix=${CROSS}                                    \
	--target=${TARGET}                                   \
	--with-local-prefix=${CROSS}/${TARGET}               \
	--program-prefix="${TARGET}-"                        \
	--disable-werror                                     \
	--disable-nls

    gmake ${SMP_OPT} 
    ${SUDO} gmake  install
    popd
}

## begin note
# 機能: UEFI(EDKII)を構築する
## end note
do_cross_uefi(){

    echo "@@@ EDK2 UEFI @@@"

    extract_archive ${EDK2}

    rm -fr ${CROSS}/uefi
    mkdir -p ${CROSS}/uefi

    rm -fr ${BUILDDIR}/edk2-${EDK2}
    mkdir -p ${BUILDDIR}

    cp -a  ${SRCDIR}/edk2-${EDK2} ${BUILDDIR}/edk2-${EDK2}
    pushd ${BUILDDIR}/edk2-${EDK2}
    gmake -C BaseTools
    source ${BUILDDIR}/edk2-${EDK2}/edksetup.sh
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
# 機能: 実行環境エミュレータを生成する
## end note
do_build_emulator(){

    echo "@@@ Emulator @@@"

    extract_archive ${QEMU}

    rm -fr  ${BUILDDIR}/${QEMU}
    cp -a  ${SRCDIR}/${QEMU} ${BUILDDIR}/${QEMU}
    pushd  ${BUILDDIR}/${QEMU}

    ./configure                          \
     --prefix=${CROSS}                   \
     --interp-prefix=${SYSROOT}          \
     --target-list="${QEMU_TARGETS}"     \
     --enable-system                     \
     --enable-tcg-interpreter            \
     --disable-werror
   
    gmake ${SMP_OPT} V=1
    ${SUDO} gmake V=1 install

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
# 機能:クロスコンパイル環境のテスト
## end note
do_cross_compile_test(){

    echo "@@@ cross compiler test @@@"
    echo "Compiler: ${CROSS}/bin/${TARGET}-gcc"
    echo "QEmu: ${CROSS}/bin/qemu-${QEMU_CPU}"
    rm -f hello himenoS

    ${CROSS}/bin/${TARGET}-gcc ${ELF_SAMPLE_COMPILE_OPT} -o hello ${WORKDIR}/scripts/hello.c
    ${CROSS}/bin/${TARGET}-gcc -O3 -D_POSIX_SOURCE ${ELF_SAMPLE_COMPILE_OPT} \
	-DSMALL -o himenoS ${WORKDIR}/scripts/himenoBMTxps.c
    file hello
    file himenoS

    if [ "x${RUN_TESTS}" != 'x' ]; then
	echo "@@ Run hello world @@"
	${CROSS}/bin/qemu-${QEMU_CPU} hello
	if [ "x${RUN_HIMENO}" != 'x' ]; then
	    echo "@@ Run himeno bench (Small Size) @@"
	    ${CROSS}/bin/qemu-${QEMU_CPU} himenoS
	fi
    fi

    rm -f hello himenoS
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
    
    do_build_gmp
    do_build_mpfr
    do_build_mpc
    do_build_isl
    
    do_cross_binutils
    do_cross_gcc_core
    do_cross_newlib
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

    case "${TARGET_CPU}" in
    	aarch64)
    	    do_cross_compile_test
    	    ;;
    	* ) 
    	    echo "Skip Testing a cross compiler"
    	    ;;
    esac
    cleanup_temporary_directories
}

main $@
