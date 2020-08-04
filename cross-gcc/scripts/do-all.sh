#!/usr/bin/env bash

TARGETS=(riscv64 aarch64 x64 i686 armhw riscv32)

if [ "x${TARGET_CPUS}" == "x" ]; then
    TARGETS=(`echo ${TARGET_CPUS}`)
fi

do_one_elf_build(){
    local name

    if [ $# -ne 1 ]; then
	echo "Error: do_one_elf_build [arch]"
	exit 1
    fi

    name=$1
    if [ -f env/${name}-env.sh ]; then
	echo "Build ${name} for ELF ..."
	if [ "x${NO_ELF_TOOLS}" != "x" ]; then
	    echo "Skipped..."
	else
	    bash ./scripts/build-elf.sh ./env/${name}-env.sh 2>&1 | tee ${name}-ELF-build.log
	fi
    fi
}

do_one_linux_build(){
    local name

    if [ $# -ne 1 ]; then
	echo "Error: do_one_build [arch]"
	exit 1
    fi

    name=$1
    if [ -f env/${name}-env.sh ]; then
	case "${name}" in
	    riscv32) 
		echo "${name} does not supports linux environment ..."
		;;
	    * ) 
		OSNAME=`uname`
		if [ "x${OSNAME}" = "xLinux" ]; then
		    echo "Build ${name} for linux ..."
		    if [ "x${NO_LINUX_TOOLS}" != "x" ]; then
			echo "Skipped..."
		    else
			bash ./scripts/build.sh ./env/${name}-env.sh 2>&1 | tee ${name}-Linux-build.log
		    fi
		fi
		;;
	esac
    fi
}

do_all_build(){
    local name

    #
    # ELF tool chain
    #
    for name in ${TARGETS[@]}
    do
	do_one_elf_build ${name}
    done

    #
    # Linux tool chain
    #
    for name in ${TARGETS[@]}
    do
	do_one_linux_build ${name}
    done
}

main(){
    local name

    if [ $# -eq 0 ]; then
	echo "Do all build"
	do_all_build
    else
	while [ $# -gt 0 ];
	do
	    name=$1
	    if [ ! -f ./env/${name}-env.sh ]; then
		echo "env/${name}-env.sh not found, skipped"
	    else
		do_one_build ${name}
	    fi
	    shift
	done
    fi
}

main $@

