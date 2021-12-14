#!/bin/bash

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
