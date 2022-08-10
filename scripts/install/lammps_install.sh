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
Usage: ${0##*/} [-h] [-v LAMMPS_VERSION]
Do stuff with FILE and write the result to standard output. With no FILE
or when FILE is -, read standard input.

    -h                   display this help and exit
    -v LAMMPS_VERSION    LAMMPS version
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
            LAMMPS_VERSION=$OPTARG
            ;;
        h )
            show_help
            exit 0
            ;;
        * )
            LAMMPS_VERSION="stable_29Oct2020"
            ;;
    esac
done

LAMMPS_URL=https://github.com/lammps/lammps.git
MODULES_PATH="/usr/share/Modules/modulefiles"
DEPENDS_ON="mkl/2022.1.0"
ENVIRONMENT="intel/2022.2.0;intel/2022.2.0 gcc/10.3.0;openmpi/4.1.0"

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
    WORKDIR=`mktemp -d -p /tmp -t lammps_XXXXXXXXXX`
    cd ${WORKDIR}

    LAMMPS_PATH="/opt/lammps/${LAMMPS_VERSION}/${compiler_name}/${compiler_version}"
    mkdir -p ${LAMMPS_PATH}/bin

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


    echo "Cloning LAMMPS stable branch"

    git clone -b ${LAMMPS_VERSION} ${LAMMPS_URL} lammps_git

    cd lammps_git/src

    if [[ "${compiler_name}" == "intel" ]]; then

        echo "Editing intel options make file for intel optimizations"
        sed -i "s%-xHost%-xCORE-AVX512%g" MAKE/OPTIONS/Makefile.intel_cpu_intelmpi
        echo "Compiling LAMMPS code"
        make -j 8 intel_cpu_intelmpi
        cp ${WORKDIR}/lammps_git/src/lmp_intel_cpu_intelmpi ${LAMMPS_PATH}/bin/
    else
        echo "Compiling LAMMPS code"
        make -j 8 g++_openmpi
        cp ${WORKDIR}/lammps_git/src/lmp_g++_openmpi ${LAMMPS_PATH}/bin/

    fi

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
