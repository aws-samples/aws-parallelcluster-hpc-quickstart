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
set -ev # exit on error

exec &> >(tee -a "/tmp/gromacs_data.log")

DATA_DIR="/fsx/performance/"

mkdir -p $DATA_DIR

cd $DATA_DIR

mkdir -p Gromacs-TestCaseA
mkdir -p Gromacs-TestCaseB

cd $DATA_DIR/Gromacs-TestCaseA
wget -qO- https://www.mpibpc.mpg.de/15615646/benchPEP.zip | bsdtar xf - -C $DATA_DIR/Gromacs-TestCaseA

cd $DATA_DIR/Gromacs-TestCaseB
wget -qO- https://www.mpibpc.mpg.de/15101328/benchRIB.zip | bsdtar xf - -C $DATA_DIR/Gromacs-TestCaseB
