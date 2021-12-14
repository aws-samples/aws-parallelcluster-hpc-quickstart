#!/bin/bash
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
    wget


# Create build directory in /tmp
WORK_DIR=$(mktemp -d /tmp/modules.XXXXXXXXX)
cd ${WORK_DIR}

# Saving current modules
cp ${MODULES_PATH}/../init/.modulespath ${WORK_DIR}/

# Download modules
curl -LOJ https://github.com/cea-hpc/modules/releases/download/v${MODULES_VERSION}/modules-${MODULES_VERSION}.tar.gz
tar -xvzf modules-${MODULES_VERSION}.tar.gz
cd modules-${MODULES_VERSION}

# Install Environment modules
./configure --prefix=${MODULES_INSTALL_PATH} --modulefilesdir=${MODULES_PATH}
make
make install

# Restore modules
cp ${WORK_DIR}/.modulespath ${MODULES_PATH}/../init/.modulespath

# Delete work_dir
cd
rm -rf ${WORK_DIR}
