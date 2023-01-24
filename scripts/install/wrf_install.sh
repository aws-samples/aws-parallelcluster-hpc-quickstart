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

WRF_DEFAULT_VERSION="4.2.2"
WRF_URL="https://github.com/wrf-model/WRF.git"

MODULES_PATH="/usr/share/Modules/modulefiles"

DEPENDS_ON="hdf5-parallel/1.10.6 pnetcdf/1.12.2 netcdf-c/4.7.4 netcdf-fortran/4.5.3"
ENVIRONMENT="intel/2022.2.0;intel/2022.2.0 gcc/10.3.0;openmpi/4.1.4"

# Help Options
show_help() {
    cat << EOF
Usage: ${0##*/} [-h] [-v WRF_VERSION]
Do stuff with FILE and write the result to standard output. With no FILE
or when FILE is -, read standard input.

    -h                display this help and exit
    -v WRF_VERSION    WRF version number
EOF
}

show_default() {
    WRF_VERSION=${WRF_DEFAULT_VERSION}
    cat << EOF
No WRF Version specified
Using default: ${WRF_VERSION}
EOF
}

# Parse options
OPTIND=1 # Reset if getopts used previously
if (($# == 0)); then
    show_default
fi


while getopts ":v:h:" opt; do
    case ${opt} in
        v )
            WRF_VERSION=$OPTARG
            ;;
        h )
            show_help
            exit 0
            ;;
        * )
            WRF_VERSION=${WRF_DEFAULT_VERSION}
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

    WRF_PATH="/opt/wrf-omp/${WRF_VERSION}/${compiler_name}/${compiler_version}"

    # Check if already installed
    if [ -d ${WRF_PATH} ];
    then
        echo "WRF already installed in ${WRF_PATH}"
        continue
    fi

    # Create build directory in /tmp
    WORKDIR=`mktemp -d -p /tmp -t wrf_XXXXXXXXXXXX`
    cd ${WORKDIR}

    # Retreive wrf from git repo
    git clone -b v"${WRF_VERSION}" ${WRF_URL}
    cd WRF

    # Enable large file support
    export WRFIO_NCD_LARGE_FILE_SUPPORT=1

    # Link NETCDF C and Fortran
    ln -sf $NETCDF_FORTRAN_HOME/include/* $NETCDF_C_HOME/include/
    find -L $NETCDF_FORTRAN_HOME/lib -maxdepth 1 -name "*" -type f -exec ln -sf {} $NETCDF_C_HOME/lib/ \;
    find -L $NETCDF_FORTRAN_HOME/lib/pkgconfig -maxdepth 1 -name "*" -type f -exec ln -sf {} $NETCDF_C_HOME/lib/pkgconfig/ \;

    # Set env var for WRF
    export PHDF5=$HDF5_PARALLEL_HOME
    export NETCDF=$NETCDF_C_HOME
    export PNETCDF=$PNETCDF_HOME

    if [[ "${compiler_name}" == "intel" ]]; then
        WRF_CONFIG="67"
    elif [[ "${compiler_name}" == "gcc" ]]; then
        WRF_CONFIG="35"
    fi

    ./configure <<< $WRF_CONFIG


    ./compile -j `nproc` em_real

    mkdir -p ${WRF_PATH}/bin
    cp main/wrf.exe ${WRF_PATH}/bin

    mkdir -p ${MODULES_PATH}/wrf-omp

    #Create module file
    cat > ${MODULES_PATH}/wrf-omp/${WRF_VERSION}-${compiler_name}-${compiler_version} << EOF
#%Module

# NOTE: This is an automatically-generated file!
proc ModulesHelp { } {
   puts stderr "This module adds WRF v${WRF_VERSION} to various paths"
}

module-whatis "Sets up WRF v${WRF_VERSION} in your environment"

EOF

    for i in ${MODULE_DEPENDENCIES}
    do
        cat >> ${MODULES_PATH}/wrf-omp/${WRF_VERSION}-${compiler_name}-${compiler_version} << EOF
module load ${i}

EOF
    done

    cat >> ${MODULES_PATH}/wrf-omp/${WRF_VERSION}-${compiler_name}-${compiler_version} << EOF
prepend-path PATH "${WRF_PATH}/bin"

EOF


    #Clean up
    cd
    rm -rf ${WORKDIR}
done

# Retreive wrf from git repo
WRF_SRC_PATH="/opt/wrf-omp/src"
mkdir -p ${WRF_SRC_PATH}
git clone -b v"${WRF_VERSION}" ${WRF_URL} ${WRF_SRC_PATH}
