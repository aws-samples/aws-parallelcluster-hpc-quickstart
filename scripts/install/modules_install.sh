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

MODULES_VERSION="4.7.1"

MODULES_INSTALL_PATH="/usr/share/Modules"

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
    tcl \
    tcl-devel \
    wget


# Create build directory in /tmp
WORK_DIR=$(mktemp -d /tmp/modules.XXXXXXXXX)
cd ${WORK_DIR}

# Saving current modules
if [ -f ${MODULES_PATH}/../init/.modulespath ]; then
    cp ${MODULES_PATH}/../init/.modulespath ${WORK_DIR}/
fi


# Download modules
curl -LOJ https://github.com/cea-hpc/modules/releases/download/v${MODULES_VERSION}/modules-${MODULES_VERSION}.tar.gz
tar -xvzf modules-${MODULES_VERSION}.tar.gz
cd modules-${MODULES_VERSION}

# Install Environment modules
./configure --prefix=${MODULES_INSTALL_PATH} \
    --modulefilesdir=${MODULES_PATH} \
    --enable-modulespath
make
make install

# Restore modules
if [ -f ${WORK_DIR}/.modulespath ]; then
    cp ${WORK_DIR}/.modulespath ${MODULES_PATH}/../init/.modulespath
fi

# Add modules to environment
if [ ! -f /etc/profile.d/modules.sh ]; then
    ln -s ${MODULES_PATH}/../init/profile.sh /etc/profile.d/modules.sh
fi


# Delete work_dir
cd
rm -rf ${WORK_DIR}