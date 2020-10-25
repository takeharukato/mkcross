#!/usr/bin/env bash
# -*- mode: bash; coding:utf-8 -*-
#
# 環境変数セットアップ用スクリプト
#
#
TARGETS=(riscv64 aarch64 x64 i686 armhw riscv32 mips mipsel mips64 mips64el)
CROSS_TOOLCHAIN_PREFIX=cross
SCRIPT_ENV_DIR=${HOME}/env
MODULE_ENVIRONMENT_DIR=${HOME}/Modules

##
# 環境設定スクリプトを生成する
# gen_environment_script ターゲット名 ツールチェイン種別(elf/linux)
##
gen_environment_script(){
    local target
    local cpu
    local type
    local qemu_cpu
    local file
    local vendor
    local tool_chain
    local cross_dir
    local mod_file

    target="$1"

    #
    # CPU名補正
    #
    case "${target}" in
	i[3456]86)
	    cpu=i686
	    qemu_cpu="i386"
	    vendor="pc"
	    ;;
	armhw)
	    cpu=arm
	    qemu_cpu="arm"
	    ;;
	*)
	    cpu=${target}
	    qemu_cpu=${target}
	    ;;
    esac

    case "$2" in
	[eE][lL][fF])
	    type=elf
	    cross_dir=${CROSS_TOOLCHAIN_PREFIX}/gcc-elf/${cpu}/current
	    ;;
	[lL][iI][nN][uU][xX])
	    type=linux
	    cross_dir=${CROSS_TOOLCHAIN_PREFIX}/gcc/${cpu}/current
	    ;;
	*)
	    echo "Unknown type: $2"
	    exit 1
	;;
    esac

    vendor="unknown"
    #
    # ツールチェイン/クロスコンパイラ配置ディレクトリ
    #
    case "${type}" in
	elf)
	    case "${target}" in
		armhw)
		    cpu="arm"
		    tool_chain=${cpu}-eabihf
		    ;;
		*)
		    tool_chain="${cpu}-${vendor}-elf"
		    ;;
	    esac
	    cross_dir=${CROSS_TOOLCHAIN_PREFIX}/gcc-elf/${cpu}/current
	    ;;
	linux)
	    case "${target}" in
		armhw)
		    cpu="arm"
		    tool_chain=${cpu}-linux-eabihf
		    ;;
		*)
		    tool_chain="${cpu}-${vendor}-linux"
		    ;;
	    esac
	    cross_dir=${CROSS_TOOLCHAIN_PREFIX}/gcc/${cpu}/current
	    ;;
	*)
	    ;;
    esac

    if [ -d ${HOME}/${cross_dir}/bin ]; then

	echo "${target}: cpu=${cpu} Type=${type} cross_dir=${HOME}/${cross_dir}"

	if [ -d ${SCRIPT_ENV_DIR} ]; then

	    file="${SCRIPT_ENV_DIR}/${cpu}-${type}-env.sh"
	    echo "${cpu}-${type}-env.sh ..."
	    if [ -f "${file}" ]; then
		rm -f "${file}"
	    fi

	    cat <<EOF > ${file}
#
# -*- mode: bash; coding:utf-8 -*-
# Setup environment variables
# ${cpu} gcc toolchain for ${type} binary
#
# Note: This is generated by gen-cross-env.sh
#
unset CPU
unset CROSS_COMPILE
unset QEMU
unset QEMU_CPU
unset GDB_COMMAND

TOOLCHAIN_PREFIX=\${HOME}/${cross_dir}

if [ -f \${HOME}/env/default-path.sh ]; then
   source \${HOME}/env/default-path.sh
else
   if [ "x\${OLD_PATH}" != "x" ]; then
      PATH="\${OLD_PATH}"
   fi
fi

if [ "x\${OLD_LD_LIBRARY_PATH}" != "x" ]; then
   LD_LIBRARY_PATH="\${OLD_LD_LIBRARY_PATH}"
fi

OLD_PATH=\${PATH}
OLD_LD_LIBRARY_PATH=\${LD_LIBRARY_PATH}

CPU=${cpu}
QEMU_CPU=${qemu_cpu}

CROSS_COMPILE=${tool_chain}-
GDB_COMMAND=\${CROSS_COMPILE}gdb
QEMU=qemu-system-${qemu_cpu}

PATH=\${TOOLCHAIN_PREFIX}/bin:\${PATH}
LD_LIBRARY_PATH=\${TOOLCHAIN_PREFIX}/lib64:\${TOOLCHAIN_PREFIX}/lib:\${LD_LIBRARY_PATH}

export CPU
export QEMU_CPU
export CROSS_COMPILE
export GDB_COMMAND
export QEMU

export OLD_PATH
export OLD_LD_LIBRARY_PATH
export PATH
export LD_LIBRARY_PATH

EOF
	fi

	if [ -d "${MODULE_ENVIRONMENT_DIR}" ]; then

	    mod_file=`echo "${cpu}-${type}"| tr '[:lower:]' '[:upper:]'`
	    mod_file="${mod_file}-GCC"
	    echo "Module ${cpu}-${type}-GCC ..."

	    cat <<EOF > "${MODULE_ENVIRONMENT_DIR}/${mod_file}"
#%Module1.0
##
## ${cpu} gcc toolchain for ${type} binary
##
## Note: This is generated by gen-cross-env.sh
##

proc ModulesHelp { } {
        puts stderr "${cpu} gcc toolchain for ${type} binary Setting \n"
}
#
module-whatis   "${cpu} gcc toolchain for ${type} binary Setting"

# for Tcl script only
set ${cpu}_${type}_gcc_path "\$env(HOME)/${cross_dir}/bin"
set ${cpu}_${type}_gcc_ld_library_path "\$env(HOME)/${cross_dir}/lib64:\$env(HOME)/${cross_dir}/lib"

# environmnet variables
setenv CPU    ${cpu}
setenv QEMU_CPU	${qemu_cpu}
setenv CROSS_COMPILE	${tool_chain}-
setenv GDB_COMMAND   ${tool_chain}-gdb
setenv QEMU	   qemu-system-${qemu_cpu}

# append pathes
prepend-path    PATH    \${${cpu}_${type}_gcc_path}
prepend-path    LD_LIBRARY_PATH \${${cpu}_${type}_gcc_ld_library_path}

EOF
	fi
    fi
}

main(){
    local cpu
    local qemu_cpu

    for target in ${TARGETS[@]}
    do

	#ELF
	gen_environment_script "${target}" elf

	#Linux
	gen_environment_script "${target}" linux

    done
}

main $@
