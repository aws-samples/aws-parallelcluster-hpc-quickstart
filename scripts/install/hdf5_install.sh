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
HDF5_VERSION="1.10.6"

HDF5_URL="https://bitbucket.hdfgroup.org/scm/hdffv/hdf5.git"

ZLIB_VERSION="1.2.11"
ZLIB_PATH="/opt/zlib/${ZLIB_VERSION}"

ENVIRONMENT="intel/2021.3.0;intel/2021.3.0 gcc/10.2.0;openmpi/4.1.0"

yum install -y \
    environment-modules \
    gcc \
    gcc-c++ \
    gcc-gfortran \
    git \
    hostname \
    make \
    man \
    man-pages

#Load module
source /etc/profile.d/modules.sh

#Load compilers
for comp_mpi in $ENVIRONMENT
do

    COMPILER=$(echo $comp_mpi | cut -d';' -f1)
    MPI=$(echo $comp_mpi | cut -d';' -f2)

    compiler_name=$(echo $COMPILER | cut -d'/' -f1)
    compiler_version=$(echo $COMPILER | cut -d'/' -f2)

    mpi_name=$(echo $MPI | cut -d'/' -f1)
    mpi_version=$(echo $MPI | cut -d'/' -f2)

    module purge
    module load compiler/${COMPILER}

    if [[ "${mpi_name}" == "intel" ]]; then

        module load mpi/${MPI}
    else
        module load mpi/${MPI}-${compiler_name}-${compiler_version}
    fi

    if [[ "${compiler_name}" == "intel" ]]; then
        export I_MPI_CC=icc
        export I_MPI_CXX=icpc
        export I_MPI_FC=ifort
        export I_MPI_F90=ifort
    fi

    HDF5_PATH="/opt/hdf5-parallel/${HDF5_VERSION}/${compiler_name}/${compiler_version}"

    # Check if already installed
    if [ -d ${HDF5_PATH} ];
    then
        echo "HDF5 already installed in ${HDF5_PATH}"
        continue
    fi

    # Create build directory in /tmp
    WORKDIR=`mktemp -d -p /tmp -t hdf5_XXXXXXXXXXXX`
    cd ${WORKDIR}

    # Retreive hdf5 from git repo
    git clone -b hdf5-"${HDF5_VERSION//./_}" ${HDF5_URL}
    cd hdf5

    ./configure \
        CC=mpicc \
        CXX=mpicxx \
        FC=mpif90 \
        --prefix=${HDF5_PATH} \
        --with-zlib=${ZLIB_PATH} \
        --enable-parallel \
        --enable-shared \
        --enable-static \
        --enable-hl

    make -j
    make install

    mkdir -p ${MODULES_PATH}/hdf5-parallel

    #Create module file
    cat > ${MODULES_PATH}/hdf5-parallel/${HDF5_VERSION}-${compiler_name}-${compiler_version} << EOF
#%Module

# NOTE: This is an automatically-generated file!
proc ModulesHelp { } {
   puts stderr "This module adds HDF5 Parallel v${HDF5_VERSION} to various paths"
}

module-whatis "Sets up HDF5 Parallel v${HDF5_VERSION} in your environment"

setenv HDF5_PARALLEL_HOME "${HDF5_PATH}"

prepend-path PATH "${HDF5_PATH}/bin"
prepend-path CPATH "${HDF5_PATH}/include"
prepend-path LD_LIBRARY_PATH "${HDF5_PATH}/lib"
prepend-path LIBRARY_PATH "${HDF5_PATH}/lib"
prepend-path MANPATH "${HDF5_PATH}/share/man"

EOF

    #Clean up
    cd
    rm -rf ${WORKDIR}

done
