#!/usr/bin/env bash

# スクリプト配置先ディレクトリ
SCRIPT_DIR=$(cd $(dirname $0);pwd)

#
#共通定義読み込み
#
if [ ! -f "${SCRIPT_DIR}/common.sh" ]; then
    echo "Error: ${SCRIPT_DIR}/common.sh not found"
    exit 1
fi

source "${SCRIPT_DIR}/common.sh"

# スクリプト配置先ディレクトリ
CROSS_GCC_DIR=${SCRIPT_DIR}/../../cross-gcc
CROSS_LLVM_DIR=${SCRIPT_DIR}/../../cross-llvm
ENV_DIR=${CROSS_GCC_DIR}/env
##
# 機能: ELFバイナリターゲットのgccクロスコンパイラを構築する
##
do_one_elf_build(){
    local name

    if [ $# -ne 1 ]; then
	echo "Error: do_one_elf_build [arch]"
	exit 1
    fi

    name=$1

    OSNAME=`uname`

    touch ${name}-ELF-build.log

    echo "Build ${name} for ELF binary ..."
    if [ "x${NO_ELF_TOOLS}" != "x" ]; then
	echo "Skipped..."
    else
	if [ -f "${CROSS_GCC_DIR}/env/${name}-env.sh" ]; then
	    echo "Load ${CROSS_GCC_DIR}/env/${name}-env.sh" 2>&1 |\
		tee -a ${name}-ELF-build.log
	    env SKIP_BUILD_TOOLS=yes \
		TOOLCHAIN_TYPE=ELF   \
		NO_DEVENV=yes        \
		bash ${CROSS_GCC_DIR}/scripts/build-elf.sh \
		${CROSS_GCC_DIR}/env/${name}-env.sh 2>&1|\
		tee -a ${name}-ELF-build.log
	else
	    env SKIP_BUILD_TOOLS=yes \
		TOOLCHAIN_TYPE=ELF   \
		NO_DEVENV=yes        \
		bash ${CROSS_GCC_DIR}/scripts/build-elf.sh|tee -a ${name}-ELF-build.log
	fi
    fi
}

##
# 機能: Linuxターゲットのgccクロスコンパイラを構築する
##
do_one_linux_build(){
    local name

    if [ $# -ne 1 ]; then
	echo "Error: do_one_linux_build [arch]"
	exit 1
    fi

    name=$1
    case "${name}" in
	riscv32)
	    echo "${name} does not supports linux environment ..."
	    ;;
	* )
	    OSNAME=`uname`
	    if [ "x${OSNAME}" = "xLinux" ]; then

		touch ${name}-Linux-build.log
		echo "Build ${name} for linux ..."
		if [ "x${NO_LINUX_TOOLS}" != "x" ]; then
		    echo "Skipped..."
		else
		    if [ -f "${CROSS_GCC_DIR}/env/${name}-env.sh" ]; then
			env SKIP_BUILD_TOOLS=yes \
			    TOOLCHAIN_TYPE=Linux \
			    NO_DEVENV=yes        \
			    bash ${CROSS_GCC_DIR}/scripts/build.sh \
			    ${CROSS_GCC_DIR}/env/${name}-env.sh 2>&1 |\
			    tee -a ${name}-Linux-build.log
		    else
			env SKIP_BUILD_TOOLS=yes \
			    TOOLCHAIN_TYPE=Linux \
			    NO_DEVENV=yes        \
			    bash ${CROSS_GCC_DIR}/scripts/build.sh |\
			    tee -a ${name}-Linux-build.log
		    fi
		fi
	    fi
	    ;;
    esac
}

##
# 機能: LLVMコンパイラを構築する
##
do_one_llvm_build(){

    OSNAME=`uname`
    touch LLVM-build.log
    echo "Build the LLVM language environment ..."
    if [ "x${NO_LLVM_TOOLS}" != "x" ]; then
	echo "Skipped LLVM ..."
    else
	    env SKIP_BUILD_TOOLS=yes  \
		TOOLCHAIN_TYPE=LLVM   \
		NO_DEVENV=yes         \
		bash ${CROSS_LLVM_DIR}/scripts/llvm-build.sh 2>&1|tee -a LLVM-build.log
    fi
}

##
# 機能: gccクロスコンパイラを構築する
##
do_all_gcc_build(){
    local name
    local targets
    local no_elf_targets
    local no_linux_targets
    local check

    no_elf_targets=(`echo ${NO_ELF_TARGETS}`)
    no_linux_targets=(`echo ${NO_LINUX_TARGETS}`)

    if [ "x${TARGET_CPUS}" != "x" ]; then
	targets=(`echo ${TARGET_CPUS}`)
    else
	pushd ${ENV_DIR}
	targets=($(ls -1 *-env.sh|sed -e 's|-env.sh||g'))
	popd
    fi

    echo "Target CPUS:${targets[@]}"

    #
    # ELF tool chain
    #
    for name in ${targets[@]}
    do
	if [[ $(printf '%s\n' "${no_elf_targets[@]}" | grep -qx "${name}"; echo -n ${?} ) -eq 0 ]]; then
	    echo "Skip building ELF tool chain for ${name}."
	else
	    do_one_elf_build ${name}
	fi
    done

    #
    # Linux tool chain
    #
    for name in ${targets[@]}
    do
	if [[ $(printf '%s\n' "${no_linux_targets[@]}" | grep -qx "${name}"; echo -n ${?} ) -eq 0 ]]; then
	    echo "Skip building Linux tool chain for ${name}."
	else
	    do_one_linux_build ${name}
	fi
    done
}

main(){
    local name

    if [ "x${NO_DEVENV}" = 'x' ]; then
    	prepare_devenv
    fi

    if [ $# -eq 0 ]; then
	echo "Do all build"
	do_all_gcc_build
    else
	while [ $# -gt 0 ];
	do
	    name=$1
	    if [ ! -f ${ENV_DIR}/${name}-env.sh ]; then
		echo "${ENV_DIR}/${name}-env.sh not found, skipped"
	    else
		do_one_elf_build ${name}
		do_one_linux_build ${name}
	    fi
	    shift
	done
    fi

    do_one_llvm_build

    if [ "x${SKIP_BUILD_TOOLS}" != "x" ]; then
	echo "do-all.sh: keep tools directory."
    else
	if [ -d "${BUILD_TOOLS_DIR}" ]; then
	    echo "Cleanup tools"
	    rm -fr "${BUILD_TOOLS_DIR}"
	fi
    fi

}

main $@
