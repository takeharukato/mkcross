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
TOOLCHAIN_TYPE=ELF
# スクリプト配置先ディレクトリ
SCRIPT_DIR=$(cd $(dirname $0);pwd)

#
#共通定義読み込み
#
if [ ! -f "${SCRIPT_DIR}/../../common/scripts/common.sh" ]; then
    echo "Error: ${SCRIPT_DIR}/common.sh not found"
    exit 1
fi

if [ ! -f "${SCRIPT_DIR}/../../common/scripts/funcs-gcc.sh" ]; then
    echo "Error: ${SCRIPT_DIR}/../../common/scripts/funcs-gcc.sh not found"
    exit 1
fi

source "${SCRIPT_DIR}/../../common/scripts/common.sh"
source "${SCRIPT_DIR}/../../common/scripts/funcs-gcc.sh"

#
#環境ファイル読み込み
#
if [ "x${ENV_FILE}" != "x" -a -f "${ENV_FILE}" ]; then
    echo "Load ${ENV_FILE}"
    source "${ENV_FILE}"
fi

## begin note
# 機能:コマンドのシンボリックリンク名を設定
## end note
do_symlink_binaries(){
    local line
    local name

    echo "@@@ make links for commands @@@"
    if [ "x${SYMLINK_BINARY}" != "x" ]; then

	if [ -d "${CROSS_PREFIX}/${TODAY}/bin" ]; then

	    pushd "${CROSS_PREFIX}/${TODAY}/bin"

	    ls -1 ${TARGET_ELF}-* |while read line
	    do
		name=`echo ${line}|sed -e 's|${TARGET_ELF}-|${SYMLINK_BINARY}-|'`
		rm -f ${name}
		ln -sv ${line} ${name}
	    done

	    popd
	fi

    fi
}

## begin note
# 機能:クロスコンパイル環境一式を生成する
## end note
main(){

    do_prepare

    prepare_buildtools

    do_cross_gcc_elf

    case "${TARGET_CPU}" in
	aarch64|x86_64|i[3456]86)
	    do_cross_uefi
	    ;;
	* )
	    echo "Skip building UEFI for ${TARGET_CPU}"
	    ;;
    esac

    if [ "x${NO_SIM}" = 'x' ]; then
	case "${TARGET_CPU}" in
	    h8300|sh2|v850)
		echo "Skip building QEmu for ${TARGET_CPU}"
		;;
	    *)
		do_build_emulator
		;;
	esac
    fi

    do_symlink_binaries

    do_cross_compile_test

    do_finalize
}

main $@
