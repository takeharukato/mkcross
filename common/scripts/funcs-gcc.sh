#
# -*- coding:utf-8 mode:bash -*-
#

###############################################################################
#                           gcc関連関数                                       #
###############################################################################

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
    env CC_FOR_BUILD="${BUILD}-gcc"                          \
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
    #--disable-nls
    #         コンパイル時間を短縮するためNative Language Supportを無効化する
    #
    env CC_FOR_BUILD="${BUILD}-gcc"                          \
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
    if [ "x${KERN_CONFIG}" != "x" ]; then
	make ARCH="${KERN_ARCH}" HOSTCC="${BUILD}-gcc" ${KERN_CONFIG}
    else
	make ARCH="${KERN_ARCH}" HOSTCC="${BUILD}-gcc" V=1 defconfig
    fi

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
    #--disable-nls
    #         コンパイル時間を短縮するためNative Language Supportを無効化する
    #
    env CC_FOR_BUILD="${BUILD}-gcc"                          \
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
    patch -p1 < ${PATCHDIR}/cross/glibc/install-lib-all.patch
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
    mkdir -pv ${SYSROOT}/usr/${_LIB}
    rm -f     ${SYSROOT}/usr/${_LIB}/crt[1in].o
    rm -f     ${SYSROOT}/usr/${_LIB}/libc.so
    #
    # スタートアップファイルをコピーする
    #
    cp csu/crt1.o csu/crti.o csu/crtn.o \
	${SYSROOT}/usr/${_LIB}
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

    echo "@@@ Cross:gcc-core-stage3 @@@"

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
    # ${WITH_SYSROOT}
    #          コンパイラの実行時にターゲット用のルートファイルシステムを優先してヘッダや
    #          ライブラリを探査する
    # ${LINK_STATIC_LIBSTDCXX}
    #          libstdc++を静的リンクしパスに依存せず動作できるようにする
    # --disable-nls
    #         コンパイル時間を短縮するためNative Language Supportを無効化する
    #
    env CC_FOR_BUILD="${BUILD}-gcc"                          \
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
# 機能:Linux用クロスコンパイラを生成する
## end note
do_cross_gcc_linux_final(){

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
    # ${WITH_SYSROOT}
    #          コンパイラの実行時にターゲット用のルートファイルシステムを優先してヘッダや
    #          ライブラリを探査する
    # ${LINK_STATIC_LIBSTDCXX}
    #          libstdc++を静的リンクしパスに依存せず動作できるようにする
    # --disable-nls
    #         コンパイル時間を短縮するためNative Language Supportを無効化する
    #
    env CC_FOR_BUILD="${BUILD}-gcc"                          \
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
	--prefix=${CROSS}                      \
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
# 機能:ELFバイナリ用クロスコンパイラを生成する
## end note
do_cross_gcc_elf_final(){

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
    env CC_FOR_BUILD="${BUILD}-gcc"                          \
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

    pushd  ${SRCDIR}/${GDB}
    patch -p1 < ${PATCHDIR}/gdb/gdb-8.3-qemu-x86-64.patch
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
# 機能: Linux用クロスコンパイラを生成する
## end note
do_cross_gcc_linux(){

    do_build_gmp
    do_build_mpfr
    do_build_mpc
    do_build_isl

    do_cross_binutils
    do_cross_gcc_core1
    do_kernel_headers
    do_glibc_headers
    do_glibc_startup
    do_cross_gcc_core2
#    do_glibc_core
    do_cross_gcc_core3
    do_cross_glibc
    do_cross_gcc_linux_final
    do_cross_gdb
}

## begin note
# 機能: ELFバイナリ用クロスコンパイラを生成する
## end note
do_cross_gcc_elf(){

    do_build_gmp
    do_build_mpfr
    do_build_mpc
    do_build_isl

    do_cross_binutils
    do_cross_gcc_core1
    do_cross_newlib
    do_cross_gcc_elf_final
    do_cross_gdb
}
