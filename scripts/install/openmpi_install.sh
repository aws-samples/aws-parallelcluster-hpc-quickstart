#!/bin/bash

# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of this
# software and associated documentation files (the "Software"), to deal in the Software
# without restriction, including without limitation the rights to use, copy, modify,
# merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
# PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
# HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
# SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
set -e

MODULES_PATH="/usr/share/Modules/modulefiles"

OPEN_MPI_VERSIONS="4.1.0"
EFA_PATH="/opt/amazon/efa"

COMPILERS="gcc/10.2.0"

yum install -y \
    hwloc \
    hwloc-devel \
    libevent \
    libevent-devel

# Source modules
source /etc/profile.d/modules.sh

for compiler in $COMPILERS
do
    module purge
    module load compiler/${compiler}
    compiler_name=$(echo $compiler | cut -d'/' -f1)
    compiler_version=$(echo $compiler | cut -d'/' -f2)

    for OPEN_MPI_VERSION in $OPEN_MPI_VERSIONS
    do

        OPEN_MPI_INSTALL_PATH="/opt/openmpi/${OPEN_MPI_VERSION}/${compiler_name}/${compiler_version}"
        # Check if already installed
        if [ -d ${OPEN_MPI_INSTALL_PATH} ];
        then
            echo "Open MPI ${OPEN_MPI_INSTALL_PATH} already installed in ${OPEN_MPI_INSTALL_PATH}"
            exit 0
        fi

        # Directory used for installation
        WORK_DIR=$(mktemp -d /tmp/open_mpi.XXXXXXXXX)
        cd ${WORK_DIR}

        curl -O https://download.open-mpi.org/release/open-mpi/v${OPEN_MPI_VERSION::-2}/openmpi-${OPEN_MPI_VERSION}.tar.bz2

        tar -xjf openmpi-${OPEN_MPI_VERSION}.tar.bz2

        cd openmpi-${OPEN_MPI_VERSION}

        ./configure \
            --prefix=${OPEN_MPI_INSTALL_PATH} \
            --with-libfabric=${EFA_PATH} \
            --without-verbs \
            --with-pmix=/opt/pmix \
            --with-libevent=/usr \
            --with-hwloc=/usr
        make -j
        make install

        cd
        rm -rf ${WORK_DIR}

        mkdir -p ${MODULES_PATH}/mpi/openmpi
        cat << EOF > ${MODULES_PATH}/mpi/openmpi/${OPEN_MPI_VERSION}-${compiler_name}-${compiler_version}
#%Module

# NOTE: This is an automatically-generated file!
# Any changes made here will be lost

proc ModulesHelp { } {
   puts stderr "This module adds Open MPI v${OPEN_MPI_VERSION} to various paths"
}

module-whatis "Sets up Open MPI v${OPEN_MPI_VERSION} in your environment"

prepend-path PATH "${OPEN_MPI_INSTALL_PATH}/bin"
prepend-path CPATH "${OPEN_MPI_INSTALL_PATH}/include"
prepend-path LD_LIBRARY_PATH "${OPEN_MPI_INSTALL_PATH}/lib"
prepend-path MANPATH "${OPEN_MPI_INSTALL_PATH}/share/man"

EOF

    done
done
