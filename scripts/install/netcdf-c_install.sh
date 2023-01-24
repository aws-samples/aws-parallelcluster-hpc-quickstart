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

NETCDF_C_VERSION="4.7.4"
DEPENDS_ON="hdf5-parallel/1.10.6 pnetcdf/1.12.2"

NETCDF_C_ARCHIVE="netcdf-c-${NETCDF_C_VERSION}.tar.gz"
NETCDF_C_URL="https://codeload.github.com/Unidata/netcdf-c/tar.gz/refs/tags/v${NETCDF_C_VERSION}"

show_help() {
    cat << EOF
Usage: ${0##*/} [-hv]

    -h                  display this help and exit
    -v NETCDF_C_VERSION    Intel oneAPI Version
EOF
}

show_default() {
    cat << EOF
No NETCDF_C Version specified
Using default: ${NETCDF_C_VERSION}
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
            NETCDF_C_VERSION=$OPTARG
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

    NETCDF_C_PATH="/opt/netcdf-c/${NETCDF_C_VERSION}/${compiler_name}/${compiler_version}"

    # Check if already installed
    if [ -d ${NETCDF_C_PATH} ];
    then
        echo "NetCDF-C already installed in ${NETCDF_C_PATH}"
        continue
    fi

    # Create build directory in /tmp
    WORKDIR=`mktemp -d -p /tmp -t netcdf_c_XXXXXXXXXXXX`
    cd ${WORKDIR}

    # Retrieve archive
    if [ ! -f ${NETCDF_C_ARCHIVE} ]; then
        echo "Download archive"
        curl -o ${NETCDF_C_ARCHIVE} ${NETCDF_C_URL}
    fi

    # Check if archive already exist untar
    if [ ! -d ${NETCDF_C_ARCHIVE::-7} ]; then
        echo "Extract archive"
        tar xzf ${NETCDF_C_ARCHIVE}
    fi

    cd ${NETCDF_C_ARCHIVE::-7}

    # Enable large file support
    export WRFIO_NCD_LARGE_FILE_SUPPORT=1

    ./configure \
        CC=mpicc \
        CXX=mpicxx \
        FC=mpif90 \
        --prefix=${NETCDF_C_PATH} \
        --enable-fortran \
        --enable-shared \
        --with-pic \
        --enable-parallel-tests \
        --enable-pnetcdf \
        --enable-large-file-tests \
        --enable-largefile \
        --enable-netcdf

    make -j
    make install

    mkdir -p ${MODULES_PATH}/netcdf-c

    #Create module file
    cat > ${MODULES_PATH}/netcdf-c/${NETCDF_C_VERSION}-${compiler_name}-${compiler_version} << EOF
#%Module

# NOTE: This is an automatically-generated file!
proc ModulesHelp { } {
   puts stderr "This module adds NetCDF-C v${NETCDF_C_VERSION} to various paths"
}

module-whatis "Sets up NetCDF-C v${NETCDF_C_VERSION} in your environment"

setenv NETCDF_C_HOME "${NETCDF_C_PATH}"

prepend-path PATH "${NETCDF_C_PATH}/bin"
prepend-path CPATH "${NETCDF_C_PATH}/include"
prepend-path LD_LIBRARY_PATH "${NETCDF_C_PATH}/lib"
prepend-path LIBRARY_PATH "${NETCDF_C_PATH}/lib"
prepend-path MANPATH "${NETCDF_C_PATH}/share/man"

EOF

    #Clean up
    cd
    rm -rf ${WORKDIR}
done
