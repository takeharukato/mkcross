#!/usr/bin/env bash

do_one_build(){
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
		    bash ./scripts/build.sh ./env/${name}-env.sh 2>&1 | tee ${name}-Linux-build.log
		fi
		;;
	esac
	echo "Build ${name} for ELF ..."
	bash ./scripts/build-elf.sh ./env/${name}-env.sh 2>&1 | tee ${name}-ELF-build.log
    fi
}



do_all_build(){
    local name

    for name in aarch64 x64 i686 armhw riscv64 riscv32
    do
	do_one_build ${name}
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
	    echo ${name}
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

