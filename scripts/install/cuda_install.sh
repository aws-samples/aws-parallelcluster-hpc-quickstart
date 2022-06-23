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

MODULES_PATH="/usr/share/Modules/modulefiles"

PACKAGE_NAME="cuda"

CUDA_DRIVER_VERSION="510"

CUDA_TOOLKIT_VERSION="11-6"

sudo amazon-linux-extras install -y epel

sudo yum-config-manager --add-repo https://developer.download.nvidia.com/compute/cuda/repos/rhel7/x86_64/cuda-rhel7.repo
sudo yum update

# Install Nvidia Fabric Manager
sudo yum install -y nvidia-driver-branch-${CUDA_DRIVER_VERSION} nvidia-fabricmanager-${CUDA_DRIVER_VERSION}
sudo systemctl enable nvidia-fabricmanager

# Install Cuda toolkit
sudo yum install -y cuda-toolkit-${CUDA_TOOLKIT_VERSION}

# Enable persistence mode
sudo nvidia-persistenced


CUDA_TOOLKIT_VERSION=`echo ${CUDA_TOOLKIT_VERSION} | sed 's/-/./g'`

mkdir -p ${MODULES_PATH}/${PACKAGE_NAME}

cat > ${MODULES_PATH}/${PACKAGE_NAME}/${CUDA_TOOLKIT_VERSION} << EOF
#%Module

# NOTE: This is an automatically-generated file!
proc ModulesHelp { } {
   puts stderr "This module adds CUDA toolkit v${CUDA_TOOLKIT_VERSION} to various paths"
}

module-whatis "Sets up CUDA toolkit v${CUDA_TOOLKIT_VERSION} in your environment"

set CUDA_HOME "/usr/local/cuda-${CUDA_TOOLKIT_VERSION}"
setenv CUDA_HOME "${CUDA_HOME}"

prepend-path PATH "${CUDA_HOME}/bin"
prepend-path CPATH "${CUDA_HOME}/include"
prepend-path LD_LIBRARY_PATH "${CUDA_HOME}/lib"
prepend-path LD_LIBRARY_PATH "${CUDA_HOME}/lib64"
prepend-path LIBRARY_PATH "${CUDA_HOME}/lib"
prepend-path LIBRARY_PATH "${CUDA_HOME}/lib64"
prepend-path MANPATH "${CUDA_HOME}/share/man"
EOF
