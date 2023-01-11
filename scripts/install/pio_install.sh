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

PACKAGE_NAME="pio"

PACKAGE_VERSION="2.5.4"
DEPENDS_ON="hdf5-parallel/1.10.6 pnetcdf/1.12.2 netcdf-c/4.7.4 netcdf-fortran/4.5.3"

PACKAGE_ARCHIVE="${PACKAGE_NAME}${PACKAGE_VERSION//./_}/${PACKAGE_NAME}-${PACKAGE_VERSION}.tar.gz"
PACKAGE_TAR=$(echo $PACKAGE_ARCHIVE | cut -d'/' -f2)
PACKAGE_URL="https://github.com/NCAR/ParallelIO/releases/download/${PACKAGE_ARCHIVE}"

show_help() {
    cat << EOF
Usage: ${0##*/} [-hv]

    -h                display this help and exit
    -v PIO_VERSION    PIO Version
EOF
}

show_default() {
    cat << EOF
No PIO Version specified
Using default: ${PIO_VERSION}
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
            PIO_VERSION=$OPTARG
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
    curl-devel \
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

    PACKAGE_PATH="/opt/${PACKAGE_NAME}/${PACKAGE_VERSION}/${compiler_name}/${compiler_version}"

    # Check if already installed
    if [ -d ${PACKAGE_PATH} ];
    then
        echo "${PACKAGE_NAME} already installed in ${PACKAGE_PATH}"
        continue
    fi

    # Create build directory in /tmp
    WORKDIR=`mktemp -d -p /tmp -t ${PACKAGE_NAME}_XXXXXXXXXXXX`
    cd ${WORKDIR}


    # Retrieve archive
    if [ ! -f ${PACKAGE_TAR} ]; then
        echo "Download archive"
        wget ${PACKAGE_URL}
    fi

    # Check if archive already exist untar
    if [ ! -d ${PACKAGE_TAR} ]; then
        echo "Extract archive"
        tar xzf ${PACKAGE_TAR}
    fi

    cd ${PACKAGE_NAME}-${PACKAGE_VERSION}

    ./configure \
        CC=mpicc \
        CXX=mpicxx \
        FC=mpif90 \
        --prefix=${PACKAGE_PATH} \
        --enable-fortran \
        --enable-netcdf-integration

    make -j
    make install

    mkdir -p ${MODULES_PATH}/${PACKAGE_NAME}

    #Create module file
    cat > ${MODULES_PATH}/${PACKAGE_NAME}/${PACKAGE_VERSION}-${compiler_name}-${compiler_version} << EOF
#%Module

# NOTE: This is an automatically-generated file!
proc ModulesHelp { } {
   puts stderr "This module adds ${PACKAGE_NAME^^} v${PACKAGE_VERSION} to various paths"
}

module-whatis "Sets up ${PACKAGE_NAME^^} v${PACKAGE_VERSION} in your environment"

setenv PIO_HOME "${PACKAGE_PATH}"

prepend-path PATH "${PACKAGE_PATH}/bin"
prepend-path CPATH "${PACKAGE_PATH}/include"
prepend-path LD_LIBRARY_PATH "${PACKAGE_PATH}/lib"
prepend-path LIBRARY_PATH "${PACKAGE_PATH}/lib"
prepend-path MANPATH "${PACKAGE_PATH}/share/man"

EOF

    #Clean up
    cd
    rm -rf ${WORKDIR}
done
