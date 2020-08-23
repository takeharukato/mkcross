#!/usr/bin/env bash
# -*- coding:utf-8 mode:bash -*-
#

###############################################################################
#                               環境設定                                      #
###############################################################################


#エラーメッセージの文字化けを避けるためにCロケールで動作させる
LANG=C

if [ $# -ne 1 ]; then
    unset ENV_FILE
else
    ENV_FILE="$1"
fi

# ツールチェイン種別
TOOLCHAIN_TYPE=LLVM
# スクリプト配置先ディレクトリ
SCRIPT_DIR=$(cd $(dirname $0);pwd)

#
#共通定義読み込み
#
if [ ! -f "${SCRIPT_DIR}/../../common/scripts/common.sh" ]; then
    echo "Error: ${SCRIPT_DIR}/common.sh not found"
    exit 1
fi

if [ ! -f "${SCRIPT_DIR}/../../common/scripts/funcs-llvm.sh" ]; then
    echo "Error: ${SCRIPT_DIR}/../../common/scripts/funcs-llvm.sh not found"
    exit 1
fi

source "${SCRIPT_DIR}/../../common/scripts/common.sh"
source "${SCRIPT_DIR}/../../common/scripts/funcs-llvm.sh"

#
#環境ファイル読み込み
#
if [ "x${ENV_FILE}" != "x" -a -f "${ENV_FILE}" ]; then
    echo "Load ${ENV_FILE}"
    source "${ENV_FILE}"
fi

## begin note
# 機能:クロスコンパイル環境一式を生成する
## end note
main(){
    local cpu
    
    do_prepare

    prepare_buildtools

    if [ "x${FORCE_FETCH_LLVM}" != 'x' -o ! -d ${DOWNLOADDIR}/llvm-project ]; then    
      	fetch_llvm_src
    fi

    if [ "x${NO_UPDATE_LLVM}" = 'x' ]; then    
	update_llvm_src
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

    if [ "x${NO_SIM}" = 'x' ]; then
	do_build_emulator
    fi

    do_cross_compile_test
    
    do_finalize
}

main $@

