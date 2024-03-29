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

HDF5_URL="https://github.com/HDFGroup/hdf5.git"

ZLIB_VERSION="1.2.11"
ZLIB_PATH="/opt/zlib/${ZLIB_VERSION}"


show_help() {
    cat << EOF
Usage: ${0##*/} [-hv]

    -h                  display this help and exit
    -v HDF5_VERSION    Intel oneAPI Version
EOF
}

show_default() {
    cat << EOF
No HDF5 Version specified
Using default: ${HDF5_VERSION}
EOF
}

# Parse options
OPTIND=1 # Reset if getopts used previously
if (($# == 0)); then
    show_default
fi

while getopts ":v:h:c:" opt; do
    case ${opt} in
        v )
            HDF5_VERSION=$OPTARG
            ;;
        c )
            ENVIRONMENT=$OPTARG
            ;;
        h )
            show_help
            exit 0
            ;;
        * )
            show_help
            exit 0
            ;;
    esac
done


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

# Find parent path
PARENT_PATH=$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )

# Modules function
source ${PARENT_PATH}/modules_functions.sh

#Load compilers
for comp_mpi in $ENVIRONMENT
do

    load_environment $comp_mpi "$DEPENDS_ON"

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
