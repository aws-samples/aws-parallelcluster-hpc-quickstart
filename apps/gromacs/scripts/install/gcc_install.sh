#!/bin/bash

set -e

MODULES_PATH="/usr/share/Modules/modulefiles"

GCC_VERSION=10.2.0
GCC_PATH="/opt/gcc/${GCC_VERSION}"

# Directory used for installation
WORK_DIR=$(mktemp -d /tmp/gnu.XXXXXXXXX)

# Check if already installed
if [ -d ${GCC_PATH} ];
then
    echo "GCC ${GCC_VERSION} already installed in ${GCC_PATH}"
    exit 0
fi

yum install -y \
    gmp-devel \
    libmpc-devel \
    mpfr-devel

wget https://ftp.gnu.org/gnu/gcc/gcc-${GCC_VERSION}/gcc-${GCC_VERSION}.tar.gz -P ${WORK_DIR}
tar xzvf ${WORK_DIR}/gcc-${GCC_VERSION}.tar.gz -C ${WORK_DIR}
mkdir ${WORK_DIR}/obj.gcc-${GCC_VERSION}
cd ${WORK_DIR}/gcc-${GCC_VERSION}
./contrib/download_prerequisites
cd ${WORK_DIR}/obj.gcc-${GCC_VERSION}
${WORK_DIR}/gcc-${GCC_VERSION}/configure --prefix=${GCC_PATH} --enable-languages=c,c++,fortran --disable-multilib

make -j $(nproc)
make install

#Clean up
cd
rm -rf ${WORK_DIR}

mkdir -p ${MODULES_PATH}/compiler/gcc

cat > ${MODULES_PATH}/compiler/gcc/${GCC_VERSION} << EOF
#%Module

# NOTE: This is an automatically-generated file!
proc ModulesHelp { } {
   puts stderr "This module adds GCC v${GCC_VERSION} to various paths"
}

module-whatis "Sets up GCC v${GCC_VERSION} in your environment"

setenv GCC_HOME "${GCC_PATH}"

prepend-path PATH "${GCC_PATH}/bin"
prepend-path CPATH "${GCC_PATH}/include"
prepend-path LD_LIBRARY_PATH "${GCC_PATH}/lib"
prepend-path LD_LIBRARY_PATH "${GCC_PATH}/lib64"
prepend-path LIBRARY_PATH "${GCC_PATH}/lib"
prepend-path LIBRARY_PATH "${GCC_PATH}/lib64"
prepend-path MANPATH "${GCC_PATH}/share/man"

EOF
