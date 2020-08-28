#!/usr/bin/env bash
# -*- mode: bash; coding:utf-8 -*-
#
# 環境変数セットアップ用スクリプト
#
#
CROSS_TOOLCHAIN_PREFIX=cross
SCRIPT_ENV_DIR=${HOME}/env
MODULE_ENVIRONMENT_DIR=${HOME}/Modules

##
# 環境設定スクリプトを生成する
# gen_llvm_environment_script 
##
gen_llvm_environment_script(){
    local file
    local tool_chain
    local cross_dir
    local mod_file
    
    cross_dir=${CROSS_TOOLCHAIN_PREFIX}/llvm/current

    if [ -d ${HOME}/${cross_dir}/bin ]; then

	if [ -d ${SCRIPT_ENV_DIR} ]; then
	
	    file="${SCRIPT_ENV_DIR}/llvm-current-env.sh"
	
	    echo "LLVM current environment: cross_dir=${HOME}/${cross_dir}"
	    
	    echo "${file} ..."
	    if [ -f "${file}" ]; then
		rm -f "${file}"
	    fi
	    
	    cat <<EOF > ${file}
#
# -*- mode: bash; coding:utf-8 -*-
# Setup environment variables
# LLVM toolchain 
#
# Note: This is generated by gen-llvm-env.sh
#

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

PATH=\${TOOLCHAIN_PREFIX}/bin:\${PATH}
LD_LIBRARY_PATH=\${TOOLCHAIN_PREFIX}/lib64:\${TOOLCHAIN_PREFIX}/lib:\${LD_LIBRARY_PATH}
CMAKE_PREFIX_PATH="\${TOOLCHAIN_PREFIX}/lib/cmake;\${TOOLCHAIN_PREFIX}/lib/cmake/llvm;\${TOOLCHAIN_PREFIX}/lib/cmake/clang;\${TOOLCHAIN_PREFIX}/lib/cmake/polly;\${TOOLCHAIN_PREFIX}/lib/cmake/ParallelSTL;\${TOOLCHAIN_PREFIX}/lib/cmake/lld;\${TOOLCHAIN_PREFIX}/lib/cmake/mlir;\${TOOLCHAIN_PREFIX}/lib/cmake/flang;\${CMAKE_PREFIX_PATH}"
export OLD_PATH
export OLD_LD_LIBRARY_PATH
export PATH
export LD_LIBRARY_PATH

EOF
	fi
	
	if [ -d "${MODULE_ENVIRONMENT_DIR}" ]; then

	    mod_file="CURRENT-LLVM"
	    echo "Module CURRENT-LLVM ..."
	    
	    cat <<EOF > "${MODULE_ENVIRONMENT_DIR}/${mod_file}"
#%Module1.0
##
## Environment module file for up-to-date edition of LLVM toolchain 
##
## Note: This is generated by gen-llvm-env.sh
##

proc ModulesHelp { } {
        puts stderr "Up-to-date edition of LLVM toolchain Setting \n"
}
#
module-whatis   "Up-to-date edition of LLVM toolchain Setting"

# for Tcl script only
set llvm_dir "\$env(HOME)/${cross_dir}"
set llvm_path "${llvm_dir}/bin"
set llvm_ld_library_path "\$env(HOME)/${cross_dir}/lib64:\$env(HOME)/${cross_dir}/lib"
set llvm_cmake_path "\${llvm_dir}/lib/cmake;\${llvm_dir}/lib/cmake/llvm;\${llvm_dir}/lib/cmake/clang;\${llvm_dir}/lib/cmake/polly;\${llvm_dir}/lib/cmake/ParallelSTL;\${llvm_dir}/lib/cmake/lld;\${llvm_dir}/lib/cmake/mlir;\${llvm_dir}/lib/cmake/flang"
# append pathes
prepend-path    PATH    \${llvm_path}
prepend-path    LD_LIBRARY_PATH \${llvm_ld_library_path}
prepend-path    CMAKE_PREFIX_PATH \${llvm_cmake_path}
EOF
	    
	fi
    fi
}

main(){

    gen_llvm_environment_script
}

main $@
