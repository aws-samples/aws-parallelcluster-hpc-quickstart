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

INTEL_VERSION="2021.3.0"

INTEL_PATH="/opt/intel/oneapi"

INTEL_BASE_URL="https://registrationcenter-download.intel.com/akdlm/irc_nas"


show_help() {
    cat << EOF
Usage: ${0##*/} [-hv]

    -h                  display this help and exit
    -v INTEL_VERSION    Intel oneAPI Version
EOF
}

show_default() {
    cat << EOF
No Intel oneAPI Version specified
Using default: ${INTEL_VERSION}
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
            INTEL_VERSION=$OPTARG
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


case ${INTEL_VERSION} in
    2021.3.0 )
        INTEL_BASE_TOOLKIT_ARCHIVE="l_BaseKit_p_2021.3.0.3219.sh"
        INTEL_BASE_TOOLKIT_URL="${INTEL_BASE_URL}/17977/${INTEL_BASE_TOOLKIT_ARCHIVE}"

        INTEL_HPC_TOOLKIT_ARCHIVE="l_HPCKit_p_2021.3.0.3230.sh"
        INTEL_HPC_TOOLKIT_URL="${INTEL_BASE_URL}/17912/${INTEL_HPC_TOOLKIT_ARCHIVE}"
        ;;

    2021.2.0 )
        INTEL_BASE_TOOLKIT_ARCHIVE="l_BaseKit_p_2021.2.0.2883.sh"
        INTEL_BASE_TOOLKIT_URL="${INTEL_BASE_URL}/17769/${INTEL_BASE_TOOLKIT_ARCHIVE}"

        INTEL_HPC_TOOLKIT_ARCHIVE="l_HPCKit_p_2021.2.0.2997.sh"
        INTEL_HPC_TOOLKIT_URL="${INTEL_BASE_URL}/17764/${INTEL_HPC_TOOLKIT_ARCHIVE}"
        ;;

    2021.1.1 )
        INTEL_BASE_TOOLKIT_ARCHIVE="l_BaseKit_p_2021.1.0.2659.sh"
        INTEL_BASE_TOOLKIT_URL="${INTEL_BASE_URL}/17431/${INTEL_BASE_TOOLKIT_ARCHIVE}"

        INTEL_HPC_TOOLKIT_ARCHIVE="l_HPCKit_p_2021.1.0.2684.sh"
        INTEL_HPC_TOOLKIT_URL="${INTEL_BASE_URL}/17427/${INTEL_HPC_TOOLKIT_ARCHIVE}"
        ;;
    * )
        echo "${INTEL_VERSION} is not supported or does not exist"
        exit 1
        ;;
esac

# Exit if already installed
if [ -d ${INTEL_PATH}/compiler/${INTEL_VERSION} ]; then
    echo "Intel oneAPI ${INTEL_VERSION} already installed"
    exit 0
fi

yum install -y \
    gcc \
    gcc-c++ \
    gcc-gfortran \
    gzip \
    make \
    man \
    man-pages \
    procps \
    tar \
    wget


# Create build directory in /tmp
WORK_DIR=$(mktemp -d /tmp/intel.XXXXXXXXX)
cd ${WORK_DIR}

# Saving current modules
cp ${MODULES_PATH}/../init/.modulespath .

# Install Environment modules
MODULES_VERSION="4.7.1"
curl -LOJ https://github.com/cea-hpc/modules/releases/download/v${MODULES_VERSION}/modules-${MODULES_VERSION}.tar.gz
tar -xvzf modules-${MODULES_VERSION}.tar.gz
cd modules-${MODULES_VERSION}
./configure --prefix=/usr/share/Modules --modulefilesdir=4{MODULES_PATH}
make
make install
cd ..

# Restore modules
cp .modulespath ${MODULES_PATH}/../init/.modulespath


# Retrieve Intel compiler
if [ ! -f ${INTEL_BASE_TOOLKIT_ARCHIVE} ]; then
    echo "Download Intel oneAPI Base ToolKit"
    curl -O ${INTEL_BASE_TOOLKIT_URL}
fi


# Remove cache
rm -rf /var/intel/installercache

bash ./${INTEL_BASE_TOOLKIT_ARCHIVE} -a -s \
    --components intel.oneapi.lin.dpcpp_dbg:intel.oneapi.lin.dpcpp-cpp-compiler:intel.oneapi.lin.mkl.devel \
    --eula accept \
    --install-dir ${INTEL_PATH}


# Retrieve Intel compiler
if [ ! -f ${INTEL_HPC_TOOLKIT_ARCHIVE} ]; then
    echo "Download Intel oneAPI HPC ToolKit"
    curl -O ${INTEL_HPC_TOOLKIT_URL}
fi

# Remove cache
rm -rf /var/intel/installercache

bash ./${INTEL_HPC_TOOLKIT_ARCHIVE} -a -s \
    --components intel.oneapi.lin.mpi.devel:intel.oneapi.lin.dpcpp-cpp-compiler-pro:intel.oneapi.lin.ifort-compiler \
    --eula accept \
    --install-dir ${INTEL_PATH}


#Clean up
rm -rf {WORK_DIR}

# Generate modules
${INTEL_PATH}/modulefiles-setup.sh --force
echo "${INTEL_PATH}/modulefiles" >> ${MODULES_PATH}/../init/.modulespath

#Copy module file
mkdir -p ${MODULES_PATH}/compiler/intel
ln -s ${INTEL_PATH}/compiler/${INTEL_VERSION}/modulefiles/compiler ${MODULES_PATH}/compiler/intel/${INTEL_VERSION}
sed -i "s%^module load debugger%#&%" ${INTEL_PATH}/compiler/${INTEL_VERSION}/modulefiles/compiler

mkdir -p ${MODULES_PATH}/mpi/intel
ln -s ${INTEL_PATH}/mpi/${INTEL_VERSION}/modulefiles/mpi ${MODULES_PATH}/mpi/intel/${INTEL_VERSION}
