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

# This file contains functions to help loading module environement and track dependencies
source /etc/profile.d/modules.sh

# Load environment: compiler, mpi and dependent modules
load_environment() {
    compiler_mpi=$1
    dependencies=$2

    MODULE_DEPENDENCIES=""
    local COMPILER=$(echo $comp_mpi | cut -d';' -f1)
    local MPI=$(echo $comp_mpi | cut -d';' -f2)

    compiler_name=$(echo $COMPILER | cut -d'/' -f1)
    compiler_version=$(echo $COMPILER | cut -d'/' -f2)

    mpi_name=$(echo $MPI | cut -d'/' -f1)
    mpi_version=$(echo $MPI | cut -d'/' -f2)

    module purge

    if ! module_exist compiler/${COMPILER}; then
        install_software ${COMPILER}
    fi
    load_modules compiler/${COMPILER}

    if [[ "${mpi_name}" == "intel" ]]; then

        load_modules mpi/${MPI}
    else
        if ! module_exist mpi/${MPI}-${compiler_name}-${compiler_version}; then
            install_software ${MPI} ${compiler_name}/${compiler_version}
        fi
        load_modules mpi/${MPI}-${compiler_name}-${compiler_version}
    fi

    if [[ "${compiler_name}" == "intel" ]]; then
        export I_MPI_CC=icc
        export I_MPI_CXX=icpc
        export I_MPI_FC=ifort
        export I_MPI_F90=ifort
    fi

    # Load depdencies
    for i in ${dependencies}
    do
        if [[ "$i" == "mkl"* ]]; then
            load_modules ${i}
        else
            if ! module_exist ${i}-${compiler_name}-${compiler_version}; then
                install_software ${i} "${compiler_name}/${compiler_version};${mpi_name}/${mpi_version}"
            fi
            load_modules ${i}-${compiler_name}-${compiler_version}
        fi
    done
}

# Load modules
load_modules() {

    module load $1
    add_dependent_modules $1
}


# Add modules
add_dependent_modules() {
    if [[ ! -z ${MODULE_DEPENDENCIES} ]]; then
        MODULE_DEPENDENCIES+=" "
    fi

    MODULE_DEPENDENCIES+="$1"
}

# Check software exist
module_exist() {
    return $(module is-avail $1)
}

# Install software
install_software() {
    local SOFTWARE=$1
    local COMPILER=$2

    name=$(echo $SOFTWARE | cut -d'/' -f1)
    version=$(echo $SOFTWARE | cut -d'/' -f2)
    # Find parent path
    PARENT_PATH=$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )

    if [ -z ${COMPILER} ]; then
        . ${PARENT_PATH}/${name}_install.sh -v ${version}
    else
        bash ${PARENT_PATH}/${name}_install.sh -v ${version} -c ${COMPILER}
    fi
}
