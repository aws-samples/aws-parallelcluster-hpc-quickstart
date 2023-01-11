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

PNETCDF_VERSION="1.12.2"

PNETCDF_ARCHIVE="pnetcdf-${PNETCDF_VERSION}.tar.gz"
PNETCDF_URL="https://parallel-netcdf.github.io/Release/${PNETCDF_ARCHIVE}"

show_help() {
    cat << EOF
Usage: ${0##*/} [-hv]

    -h                  display this help and exit
    -v PNETCDF_VERSION    Intel oneAPI Version
EOF
}

show_default() {
    cat << EOF
No PNETCDF Version specified
Using default: ${PNETCDF_VERSION}
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
            PNETCDF_VERSION=$OPTARG
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
    m4 \
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
    PNETCDF_PATH="/opt/pnetcdf/${PNETCDF_VERSION}/${compiler_name}/${compiler_version}"
    if [ -d ${PNETCDF_PATH} ];
    then
        echo "PnetCDF already installed in ${PNETCDF_PATH}"
        continue
    fi

    # Create build directory in /tmp
    WORKDIR=`mktemp -d -p /tmp -t pnetcdf_XXXXXXXXXXXX`
    cd ${WORKDIR}

    # Check if already installed

    # Retrieve archive
    if [ ! -f ${PNETCDF_ARCHIVE} ]; then
        echo "Download archive"
        curl -O ${PNETCDF_URL}
    fi

    # Check if archive already exist untar
    if [ ! -d ${PNETCDF_ARCHIVE%%.*} ]; then
        echo "Extract archive"
        tar xzf ${PNETCDF_ARCHIVE}
    fi

    cd ${PNETCDF_ARCHIVE%.tar.gz}

    ./configure \
        CC=mpicc \
        CXX=mpicxx \
        FC=mpif90 \
        CFLAGS='-g -O2 -fPIC' \
        CXXFLAGS='-g -O2 -fPIC' \
        FFLAGS='-g -fPIC' \
        FCFLAGS='-g -fPIC' \
        FLDFLAGS='-fPIC' \
        F90LDFLAGS='-fPIC' \
        LDFLAGS='-fPIC' \
        --prefix=${PNETCDF_PATH} \
        --enable-fortran \
        --enable-large-file-test \
        --enable-shared

    make -j
    make install

    mkdir -p ${MODULES_PATH}/pnetcdf

    #Create module file
    cat > ${MODULES_PATH}/pnetcdf/${PNETCDF_VERSION}-${compiler_name}-${compiler_version} << EOF
#%Module

# NOTE: This is an automatically-generated file!
proc ModulesHelp { } {
   puts stderr "This module adds PnetCDF Parallel v${PNETCDF_VERSION} to various paths"
}

module-whatis "Sets up PnetCDF Parallel v${PNETCDF_VERSION} in your environment"

setenv PNETCDF_HOME "${PNETCDF_PATH}"

prepend-path PATH "${PNETCDF_PATH}/bin"
prepend-path CPATH "${PNETCDF_PATH}/include"
prepend-path LD_LIBRARY_PATH "${PNETCDF_PATH}/lib"
prepend-path LIBRARY_PATH "${PNETCDF_PATH}/lib"
prepend-path MANPATH "${PNETCDF_PATH}/share/man"

EOF

    #Clean up
    cd
    rm -rf ${WORKDIR}
done
