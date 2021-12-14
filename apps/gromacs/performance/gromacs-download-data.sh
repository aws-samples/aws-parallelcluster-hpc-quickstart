#!/bin/bash
# fbaruffa@amazon.com

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
