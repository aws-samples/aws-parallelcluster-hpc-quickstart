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

CMAKE_VERSION=3.17.2
CMAKE_PATH="/opt/cmake/${CMAKE_VERSION}"

# Directory used for installation
WORK_DIR=$(mktemp -d /tmp/cmake.XXXXXXXXX)

# Check if already installed
if [ -d ${CMAKE_PATH} ];
then
    echo "CMAKE ${CMAKE_VERSION} already installed in ${CMAKE_PATH}"
    exit 0
fi

yum install -y \
    gcc \
    gcc-c++ \
    openssl \
    openssl-devel



wget https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}.tar.gz -P ${WORK_DIR}
tar xzvf ${WORK_DIR}/cmake-${CMAKE_VERSION}.tar.gz -C ${WORK_DIR}
mkdir ${WORK_DIR}/obj.cmake-${CMAKE_VERSION}
cd ${WORK_DIR}/cmake-${CMAKE_VERSION}

cd ${WORK_DIR}/obj.cmake-${CMAKE_VERSION}
${WORK_DIR}/cmake-${CMAKE_VERSION}/configure --prefix=${CMAKE_PATH}

make -j $(nproc)
make install

#Clean up
cd
rm -rf ${WORK_DIR}

mkdir -p ${MODULES_PATH}/cmake

cat > ${MODULES_PATH}/cmake/${CMAKE_VERSION} << EOF
#%Module

# NOTE: This is an automatically-generated file!
proc ModulesHelp { } {
   puts stderr "This module adds cmake v${CMAKE_VERSION} to various paths"
}

module-whatis "Sets up cmake v${CMAKE_VERSION} in your environment"

setenv CMAKE_HOME "${CMAKE_PATH}"

prepend-path PATH "${CMAKE_PATH}/bin"
prepend-path MANPATH "${CMAKE_PATH}/share/man"

EOF
