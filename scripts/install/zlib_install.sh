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

ZLIB_VERSION="1.2.11"

ZLIB_URL="https://zlib.net/fossils/zlib-${ZLIB_VERSION}.tar.gz"
ZLIB_PATH="/opt/zlib/${ZLIB_VERSION}"

# Directory used for installation
WORK_DIR=$(mktemp -d /tmp/zlib.XXXXXXXXX)

yum install -y \
    gcc \
    gzip \
    make \
    tar

cd ${WORK_DIR}

curl -O ${ZLIB_URL}

tar xvzf zlib-${ZLIB_VERSION}.tar.gz
cd zlib-${ZLIB_VERSION}

./configure --prefix=${ZLIB_PATH}
make check
make test
make install

#Clean up
rm -rf ${WORK_DIR}
