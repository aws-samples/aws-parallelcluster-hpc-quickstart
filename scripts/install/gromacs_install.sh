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

# Help Options
show_help() {
    cat << EOF
Usage: ${0##*/} [-h] [-v GROMACS_VERSION]
Do stuff with FILE and write the result to standard output. With no FILE
or when FILE is -, read standard input.

    -h                   display this help and exit
    -v GROMACS_VERSION    GROMACS version
EOF
}

# Parse options
OPTIND=1 # Reset if getopts used previously
if (($# == 0)); then
    show_help
    exit 2
fi

while getopts ":v:h:" opt; do
    case ${opt} in
        v )
            GROMACS_VERSION=$OPTARG
            ;;
        h )
            show_help
            exit 0
            ;;
        * )
            GROMACS_VERSION="v2021.4"
            ;;
    esac
done

GROMACS_URL=https://gitlab.com/gromacs/gromacs.git
MODULES_PATH="/usr/share/Modules/modulefiles"
ENVIRONMENT="intel/2022.2.0;intel/2022.2.0 gcc/10.3.0;openmpi/4.1.4"


yum install -y \
    environment-modules \
    gcc \
    gcc-c++ \
    gcc-gfortran \
    git \
    hostname \
    make \
    man \
    man-pages \
    cmake3 \
    bsdtar

#Load module
source /etc/profile.d/modules.sh

# Add modules
add_dependent_modules() {
    if [[ ! -z ${MODULE_DEPENDENCIES} ]]; then
        MODULE_DEPENDENCIES+=" "
    fi

    MODULE_DEPENDENCIES+="$1"
}

#Load compilers
for comp_mpi in $ENVIRONMENT
do

    MODULE_DEPENDENCIES=""
    COMPILER=$(echo $comp_mpi | cut -d';' -f1)
    MPI=$(echo $comp_mpi | cut -d';' -f2)

    compiler_name=$(echo $COMPILER | cut -d'/' -f1)
    compiler_version=$(echo $COMPILER | cut -d'/' -f2)

    mpi_name=$(echo $MPI | cut -d'/' -f1)
    mpi_version=$(echo $MPI | cut -d'/' -f2)

    module purge
    module load compiler/${COMPILER}
    add_dependent_modules "compiler/${COMPILER}"

    if [[ "${mpi_name}" == "intel" ]]; then

        module load mpi/${MPI}
        add_dependent_modules "mpi/${MPI}"
    else
        module load mpi/${MPI}-${compiler_name}-${compiler_version}
        add_dependent_modules "mpi/${MPI}-${compiler_name}-${compiler_version}"
    fi

    if [[ "${compiler_name}" == "intel" ]]; then
        export I_MPI_CC=icc
        export I_MPI_CXX=icpc
        export I_MPI_FC=ifort
        export I_MPI_F90=ifort
    fi

    # Create build directory in /tmp
    WORKDIR=`mktemp -d -p /tmp -t gromacs_XXXXXXXXXX`
    cd ${WORKDIR}

    GROMACS_PATH="/opt/gromacs/${GROMACS_VERSION}/${compiler_name}/${compiler_version}"
    mkdir -p ${GROMACS_PATH}/bin

    # Load depdencies
    for i in $DEPENDS_ON
    do
        if [[ "$i" == "mkl"* ]]; then
            module load ${i}
            add_dependent_modules "${i}"
        else
            module load ${i}-${compiler_name}-${compiler_version}
            add_dependent_modules "${i}-${compiler_name}-${compiler_version}"
        fi
    done


    echo "Cloning Gromacs release branch"

    git clone -b ${GROMACS_VERSION} ${GROMACS_URL} gromacs_git

    cd gromacs_git
    mkdir -p build
    cd build


    echo "Compiling GROMACS code"
    cmake3 .. \
        -DGMX_BUILD_OWN_FFTW=ON \
        -DREGRESSIONTEST_DOWNLOAD=OFF \
        -DCMAKE_C_COMPILER=mpicc \
        -DCMAKE_CXX_COMPILER=mpicxx \
        -DGMX_MPI=on \
        -DGMX_OPENMP=on \
        -DGMX_DOUBLE=OFF \
        -DBUILD_SHARED_LIBS=OFF \
        -DGMXAPI=OFF \
        -DGMX_SIMD=AVX_512

    make -j

    cp ${WORKDIR}/gromacs_git/build/bin/gmx_mpi  ${GROMACS_PATH}/bin/gmx_mpi


    #Create module file
    mkdir -p ${MODULES_PATH}/gromacs

    cat > ${MODULES_PATH}/gromacs/${GROMACS_VERSION}-${compiler_name}-${compiler_version} << EOF
#%Module

# NOTE: This is an automatically-generated file!
proc ModulesHelp { } {
   puts stderr "This module adds Gromacs v${GROMACS_VERSION} to various paths"
}

module-whatis "Sets up Gromacs v${GROMACS_VERSION} in your environment"

EOF


    for i in ${MODULE_DEPENDENCIES}
    do
        cat >> ${MODULES_PATH}/gromacs/${GROMACS_VERSION}-${compiler_name}-${compiler_version} << EOF
module load ${i}

EOF
    done

    cat >> ${MODULES_PATH}/gromacs/${GROMACS_VERSION}-${compiler_name}-${compiler_version} << EOF
prepend-path PATH "${GROMACS_PATH}/bin"

EOF
    #Clean up
    cd
    rm -rf ${WORKDIR}
done
