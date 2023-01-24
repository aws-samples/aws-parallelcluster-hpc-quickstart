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

LAMMPS_DEFAULT_VERSION="stable_29Oct2020"
LAMMPS_URL=https://github.com/lammps/lammps.git

MODULES_PATH="/usr/share/Modules/modulefiles"

DEPENDS_ON="mkl/2022.1.0"
ENVIRONMENT="intel/2022.2.0;intel/2022.2.0"

# Help Options
show_help() {
    cat << EOF
Usage: ${0##*/} [-h] [-v LAMMPS_VERSION]
Do stuff with FILE and write the result to standard output. With no FILE
or when FILE is -, read standard input.

    -h                   display this help and exit
    -v LAMMPS_VERSION    LAMMPS version
EOF
}

show_default() {
    LAMMPS_VERSION=${LAMMPS_DEFAULT_VERSION}
    cat << EOF
No LAMMPS Version specified
Using default: ${LAMMPS_VERSION}
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
            LAMMPS_VERSION=$OPTARG
            ;;
        h )
            show_help
            exit 0
            ;;
        * )
            LAMMPS_VERSION=${LAMMPS_DEFAULT_VERSION}
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
    LAMMPS_PATH="/opt/lammps/${LAMMPS_VERSION}/${compiler_name}/${compiler_version}"

    if [ -d ${LAMMPS_PATH} ]; then
        echo "LAMMPS already installed in ${LAMMPS_PATH}"
        continue
    fi
    # Create build directory in /tmp
    WORKDIR=`mktemp -d -p /tmp -t lammps_XXXXXXXXXX`
    cd ${WORKDIR}

    echo "Cloning LAMMPS stable branch"

    git clone -b ${LAMMPS_VERSION} ${LAMMPS_URL} lammps_git

    cd lammps_git/src

    if [[ "${compiler_name}" == "intel" ]]; then

        echo "Editing intel options make file for intel optimizations"
        sed -i "s%-xHost%-xCORE-AVX512%g" MAKE/OPTIONS/Makefile.intel_cpu_intelmpi
        echo "Compiling LAMMPS code"
        make -j 8 intel_cpu_intelmpi
        LAMMPS_BINARY=${WORKDIR}/lammps_git/src/lmp_intel_cpu_intelmpi
    else
        echo "Compiling LAMMPS code"
        make -j 8 g++_openmpi
        LAMMPS_BINARY=${WORKDIR}/lammps_git/src/lmp_g++_openmpi

    fi

    mkdir -p ${LAMMPS_PATH}/bin
    cp ${LAMMPS_BINARY} ${LAMMPS_PATH}/bin/

    mkdir -p ${MODULES_PATH}/lammps

    #Create module file
    cat > ${MODULES_PATH}/lammps/${LAMMPS_VERSION}-${compiler_name}-${compiler_version} << EOF
#%Module

# NOTE: This is an automatically-generated file!
proc ModulesHelp { } {
   puts stderr "This module adds LAMMPS v${LAMMPS_VERSION} to various paths"
}

module-whatis "Sets up LAMMPS v${LAMMPS_VERSION} in your environment"

EOF


    for i in ${MODULE_DEPENDENCIES}
    do
        cat >> ${MODULES_PATH}/lammps/${LAMMPS_VERSION}-${compiler_name}-${compiler_version} << EOF
module load ${i}

EOF
    done

    cat >> ${MODULES_PATH}/lammps/${LAMMPS_VERSION}-${compiler_name}-${compiler_version} << EOF
prepend-path PATH "${LAMMPS_PATH}/bin"

EOF
    #Clean up
    cd
    rm -rf ${WORKDIR}
done
