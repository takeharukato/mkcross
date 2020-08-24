#
# -*- coding:utf-8 mode:bash -*-
#

###############################################################################
#                              LLVMツールチェイン                             #
###############################################################################


# LLVM_ENABLE_PROJECTSのフルリストは,
# clang;clang-tools-extra;compiler-rt;debuginfo-tests;libc;libclc;libcxx;libcxxabi;
# libunwind;lld;lldb;openmp;parallel-libs;polly;pstl
# ( https://llvm.org/docs/CMake.html 参照)
#
# 上記に, Multi-Level Intermediate Representation (MLIR) を追加。
#
# 以下はコンパイルエラーになるため除外
# - libc
# - flang
# flangは, clang++でコンパイルした場合に, fortranランタイムコンパイル時に削除された
# コピーコンストラクタを呼び出している旨エラーが出る
# -- エラーの内容
#/usr/local/llvm-12_0_0/bin/../include/c++/v1/variant:599:16:
#  error: call to implicitly-deleted copy constructor of
#   'Fortran::runtime::io::IoErrorHandler'
#        return __invoke_constexpr(
# -- エラーの内容
#
if [ "x${USE_FLANG}" != 'x' ]; then
    LLVM_PROJECTS="clang;clang-tools-extra;compiler-rt;debuginfo-tests;libclc;libcxx;libcxxabi;libunwind;lld;lldb;mlir;openmp;parallel-libs;polly;pstl;flang"
else
    LLVM_PROJECTS="clang;clang-tools-extra;compiler-rt;debuginfo-tests;libclc;libcxx;libcxxabi;libunwind;lld;lldb;mlir;openmp;parallel-libs;polly;pstl"
fi

## begin note
#  機能: LLVMのソースを取得する
## end note
fetch_llvm_src(){

    echo "@@@ Fetch sources @@@"

    if [ -d "${DOWNLOADDIR}/llvm-project" ]; then
	rm -fr "${DOWNLOADDIR}/llvm-project"
    fi
    pushd  ${DOWNLOADDIR}
    git clone ${LLVM_GIT_REPO}
    popd
}
##
# 機能: LLVMのソースを更新する
##
update_llvm_src(){

    if [ -d "${DOWNLOADDIR}/llvm-project" ]; then

	pushd "${DOWNLOADDIR}/llvm-project"
	git checkout -f master
	git pull 
	if [ "x${LLVM_REL_TAG}" != "x" ]; then
	    echo "Update LLVM source to ${LLVM_REL_TAG}"
	    git checkout -f "${LLVM_REL_TAG}"
	fi
	popd
    fi
}
## begin note
# 機能:llvmをコンパイルするためのllvmを構築する
## end note
do_build_llvm_for_llvm(){
    local llvm_src
    local type
    local python_path

    echo "@@@ Build LLVM @@@"

    python_path=`which python3`
    if [ "x${python_path}" = "x" ]; then
	python_path=`which python`
    fi

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

    # 構築に使用するツールを選択
    if [ "x${NO_NINJA}" = "x" ]; then
	type="Ninja"
    else
	type="Unix Makefiles"
    fi
    
    mkdir -p ${BUILDDIR}/llvm-build

    pushd  ${BUILDDIR}/llvm-build
    cmake -G  "${type}"                                                  \
    	-DCMAKE_BUILD_TYPE=Release                                       \
    	-DCMAKE_INSTALL_PREFIX=${CROSS}                                  \
	-DLLVM_ENABLE_LIBCXX=ON                                          \
	-DPYTHON_EXECUTABLE="${python_path}"                             \
	-DCMAKE_C_COMPILER="${BUILD_TOOLS_DIR}/bin/${BUILD}-gcc"         \
	-DCMAKE_CXX_COMPILER="${BUILD_TOOLS_DIR}/bin/${BUILD}-g++"       \
	-DCMAKE_LINKER="${BUILD_TOOLS_DIR}/bin/${BUILD}-ld"              \
	-DCMAKE_AR="${BUILD_TOOLS_DIR}/bin/${BUILD}-ar"                  \
	-DCMAKE_RANLIB="${BUILD_TOOLS_DIR}/bin/${BUILD}-ranlib"          \
	-DCMAKE_NM="${BUILD_TOOLS_DIR}/bin/${BUILD}-nm"                  \
	-DCMAKE_OBJCOPY="${BUILD_TOOLS_DIR}/bin/${BUILD}-objcopy"        \
	-DCMAKE_OBJDUMP="${BUILD_TOOLS_DIR}/bin/${BUILD}-objdump"        \
	-DCMAKE_STRIP="${BUILD_TOOLS_DIR}/bin/${BUILD}-strip"            \
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
    local type
    local python_path
    
    echo "@@@ Build LLVM with clang++ @@@"

    python_path=`which python3`
    if [ "x${python_path}" = "x" ]; then
	python_path=`which python`
    fi

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

    if [ -d ${BUILDDIR}/llvm-build-clang ]; then
	rm -fr ${BUILDDIR}/llvm-build-clang
    fi

    # 構築に使用するツールを選択
    if [ "x${NO_NINJA}" = "x" ]; then
	type="Ninja"
    else
	type="Unix Makefiles"
    fi

    mkdir -p ${BUILDDIR}/llvm-build-clang

    pushd ${BUILDDIR}/llvm-build-clang

    cmake -G  "${type}"                                \
    	-DCMAKE_BUILD_TYPE=Release                     \
    	-DCMAKE_INSTALL_PREFIX="${CROSS}"              \
	-DLLVM_ENABLE_LIBCXX=ON                        \
	-DLLVM_USE_LINKER="${CROSS}/bin/ld.lld"        \
	-DPYTHON_EXECUTABLE="${python_path}"           \
	-DCMAKE_C_COMPILER="${CROSS}/bin/clang"        \
	-DCMAKE_CXX_COMPILER="${CROSS}/bin/clang++"    \
	-DCMAKE_LINKER="${CROSS}/bin/ld.lld"           \
	-DCMAKE_AR="${CROSS}/bin/llvm-ar"              \
	-DCMAKE_RANLIB="${CROSS}/bin/llvm-ranlib"      \
	-DCMAKE_NM="${CROSS}/bin/llvm-nm"              \
	-DCMAKE_OBJCOPY="${CROSS}/bin/llvm-objcopy"    \
	-DCMAKE_OBJDUMP="${CROSS}/bin/llvm-objdump"    \
	-DCMAKE_STRIP="${CROSS}/bin/llvm-strip"        \
	-DLLVM_ENABLE_PROJECTS="${LLVM_PROJECTS}"      \
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
# 機能: LLVMコンパイラを生成する
## end note
do_build_llvm(){

    do_build_llvm_for_llvm
    do_build_llvm_with_clangxx
}
