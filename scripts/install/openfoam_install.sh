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


OPENFOAM_DEFAULT_VERSION="2012"
OPENFOAM_URL="https://develop.openfoam.com/Development/openfoam.git"
OPENFOAM_THIRDPARY_URL="https://develop.openfoam.com/Development/ThirdParty-common.git"
SCOTCH_URL="https://gitlab.inria.fr/scotch/scotch.git"
# Have to use a different variable name than SCOTCH_VERSION that is used internally by OpenFOAM.
SCOTCH_LOCAL_VERSION="6.0.9"

MODULES_PATH="/usr/share/Modules/modulefiles"
ENVIRONMENT="intel/2022.2.0;intel/2022.2.0 gcc/10.3.0;openmpi/4.1.4"

# Help Options
show_help() {
    cat << EOF
Usage: ${0##*/} [-h] [-v OPENFOAM_VERSION]
Do stuff with FILE and write the result to standard output. With no FILE
or when FILE is -, read standard input.

    -h                   display this help and exit
    -v OPENFOAM_VERSION  OpenFOAM version
EOF
}

show_default() {
    OPENFOAM_VERSION=${OPENFOAM_DEFAULT_VERSION}
    cat << EOF
No OpenFOAM Version specified
Using default: ${OPENFOAM_VERSION}
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
            OPENFOAM_VERSION=$OPTARG
            ;;
        h )
            show_help
            exit 0
            ;;
        * )
            OPENFOAM_VERSION=${OPENFOAM_DEFAULT_VERSION}
            ;;
    esac
done


yum install -y \
    autoconf \
    automake \
    environment-modules \
    flex \
    gcc \
    gcc-c++ \
    gcc-gfortran \
    git \
    hostname \
    m4 \
    make \
    man \
    man-pages

#Load module
source /etc/profile.d/modules.sh

# Find parent path
PARENT_PATH=$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )

# Modules function
source ${PARENT_PATH}/modules_functions.sh

#Load compilers
for comp_mpi in $ENVIRONMENT
do

    load_environment $comp_mpi "$DEPENDS_ON"
    OPENFOAM_PATH="/opt/openfoam/${OPENFOAM_VERSION}/${compiler_name}/${compiler_version}"

    # Check if already installed
    if [ -d ${OPENFOAM_PATH} ];
    then
        echo "OpenFOAM already installed in ${OPENFOAM_PATH}"
        continue
    fi

    # Create build directory in /tmp
    WORKDIR=`mktemp -d -p /tmp -t OPENFOAM_XXXXXXXXXX`
    cd ${WORKDIR}

    echo "Cloning OpenFOAM ${OPENFOAM_VERSION} branch"
    git clone -b OpenFOAM-v${OPENFOAM_VERSION} ${OPENFOAM_URL} ${OPENFOAM_PATH}
    git clone -b v${OPENFOAM_VERSION} ${OPENFOAM_THIRDPARY_URL} ${OPENFOAM_PATH}/ThirdParty
    git clone -b v${SCOTCH_LOCAL_VERSION} ${SCOTCH_URL} ${OPENFOAM_PATH}/ThirdParty/scotch_${SCOTCH_LOCAL_VERSION}


    if [[ "${compiler_name}" == "intel" ]]; then
        echo "export WM_COMPILER=Icc" >> ${OPENFOAM_PATH}/etc/prefs.sh
        echo "export WM_MPLIB=INTELMPI" >> ${OPENFOAM_PATH}/etc/prefs.sh
        sed -i -e 's%-UCOMMON_FILE_COMPRESS%-DCOMMON_FILE_COMPRESS_GZ -DCOMMON_PTHREAD%g' \
            -e 's%-Drestrict=__restrict%-Drestrict=%g' \
            -e 's%-lm -lrt%-lz -lm -lrt -pthread%g' \
            ${OPENFOAM_PATH}/ThirdParty/etc/makeFiles/scotch/Makefile.inc.OpenFOAM-Linux.shlib
    elif [[ "${compiler_name}" == "gcc" ]]; then
        echo "export WM_COMPILER=Gcc" >> ${OPENFOAM_PATH}/etc/prefs.sh
        echo "export WM_MPLIB=SYSTEMOPENMPI" >> ${OPENFOAM_PATH}/etc/prefs.sh
    fi

    source ${OPENFOAM_PATH}/etc/bashrc

    echo "Compiling OpenFOAM code"
    ${OPENFOAM_PATH}/Allwmake -j


    #Create module file
    mkdir -p ${MODULES_PATH}/openfoam

    cat > ${MODULES_PATH}/openfoam/${OPENFOAM_VERSION}-${compiler_name}-${compiler_version} << EOF
#%Module

# NOTE: This is an automatically-generated file!
proc ModulesHelp { } {
   puts stderr "This module adds OpenFOAM v${OPENFOAM_VERSION} to various paths"
}

module-whatis "Sets up OpenFOAM v${OPENFOAM_VERSION} in your environment"

EOF


    for i in ${MODULE_DEPENDENCIES}
    do
        cat >> ${MODULES_PATH}/openfoam/${OPENFOAM_VERSION}-${compiler_name}-${compiler_version} << EOF
module load ${i}

EOF
    done

    cat >> ${MODULES_PATH}/openfoam/${OPENFOAM_VERSION}-${compiler_name}-${compiler_version} << EOF
set OPENFOAM_HOME ${OPENFOAM_PATH}
setenv WM_PROJECT "OpenFOAM"
setenv WM_PROJECT_VERSION "v$OPENFOAM_VERSION"
setenv WM_THIRD_PARTY_DIR  "\$OPENFOAM_HOME/ThirdParty"
setenv FOAM_INST_DIR "\$OPENFOAM_HOME/\$env(WM_PROJECT)"


setenv WM_ARCH linux64
setenv WM_COMPILE_OPTION Opt
setenv WM_COMPILER $WM_COMPILER
setenv WM_COMPILER_LIB_ARCH 64
setenv WM_COMPILER_TYPE system
setenv WM_DIR \$OPENFOAM_HOME/wmake
setenv WM_LABEL_OPTION Int32
setenv WM_LABEL_SIZE 32
setenv WM_MPLIB $WM_MPLIB
setenv WM_PRECISION_OPTION DP
setenv WM_PROJECT_DIR \$OPENFOAM_HOME
setenv WM_PROJECT_USER_DIR /shared
setenv WM_THIRD_PARTY_DIR \$OPENFOAM_HOME/ThirdParty
setenv WM_OPTIONS "\$env(WM_ARCH)\$env(WM_COMPILER)\$env(WM_PRECISION_OPTION)\$env(WM_LABEL_OPTION)\$env(WM_COMPILE_OPTION)"


setenv FOAM_API $OPENFOAM_VERSION
setenv FOAM_APPBIN "\$OPENFOAM_HOME/platforms/\$env(WM_ARCH)\$env(WM_COMPILER)\$env(WM_PRECISION_OPTION)\$env(WM_LABEL_OPTION)\$env(WM_COMPILE_OPTION)/bin"
setenv FOAM_APP \$OPENFOAM_HOME/applications
setenv FOAM_ETC \$OPENFOAM_HOME/etc
setenv FOAM_LIBBIN "\$OPENFOAM_HOME/platforms/\$env(WM_ARCH)\$env(WM_COMPILER)\$env(WM_PRECISION_OPTION)\$env(WM_LABEL_OPTION)\$env(WM_COMPILE_OPTION)/lib"
setenv FOAM_MPI $FOAM_MPI
setenv FOAM_RUN "\$env(WM_PROJECT_USER_DIR)/\$env(WM_PROJECT)/\$env(USER)-\$env(WM_PROJECT_VERSION)/run"
setenv FOAM_SITE_APPBIN "\$OPENFOAM_HOME/\$env(WM_PROJECT)/site/\$env(WM_PROJECT_VERSION)/platforms/\$env(WM_ARCH)\$env(WM_COMPILER)\$env(WM_PRECISION_OPTION)\$env(WM_LABEL_OPTION)\$env(WM_COMPILE_OPTION)/bin"
setenv FOAM_SITE_LIBBIN "\$OPENFOAM_HOME/platforms/\$env(WM_ARCH)\$env(WM_COMPILER)\$env(WM_PRECISION_OPTION)\$env(WM_LABEL_OPTION)\$env(WM_COMPILE_OPTION)/lib"
setenv FOAM_SOLVERS \$OPENFOAM_HOME/applications/solvers
setenv FOAM_SRC "\$OPENFOAM_HOME/src"
setenv FOAM_TUTORIALS \$OPENFOAM_HOME/tutorials
setenv FOAM_USER_APPBIN "\$env(WM_PROJECT_USER_DIR)/\$env(WM_PROJECT)/\$env(USER)-\$env(WM_PROJECT_VERSION)/platforms/\$env(WM_ARCH)\$env(WM_COMPILER)\$env(WM_PRECISION_OPTION)\$env(WM_LABEL_OPTION)\$env(WM_COMPILE_OPTION)/bin"
setenv FOAM_USER_LIBBIN "\$env(WM_PROJECT_USER_DIR)/\$env(WM_PROJECT)/\$env(USER)-\$env(WM_PROJECT_VERSION)/platforms/\$env(WM_ARCH)\$env(WM_COMPILER)\$env(WM_PRECISION_OPTION)\$env(WM_LABEL_OPTION)\$env(WM_COMPILE_OPTION)/lib"
setenv FOAM_UTILITIES "\$OPENFOAM_HOME/applications/utilities"
setenv FOAM_EXT_LIBBIN "\$env(WM_THIRD_PARTY_DIR)/platforms/\$env(WM_ARCH)\$env(WM_COMPILER)\$env(WM_PRECISION_OPTION)\$env(WM_LABEL_OPTION)/lib"



prepend-path PATH "\$env(FOAM_APPBIN)"
prepend-path LD_LIBRARY_PATH "\$env(FOAM_LIBBIN)"
prepend-path LD_LIBRARY_PATH "\$env(FOAM_LIBBIN)/dummy"
prepend-path LD_LIBRARY_PATH "\$env(FOAM_LIBBIN)/\$env(FOAM_MPI)"
prepend-path LD_LIBRARY_PATH "\$env(FOAM_EXT_LIBBIN)"
prepend-path LD_LIBRARY_PATH "\$env(FOAM_EXT_LIBBIN)/\$env(FOAM_MPI)"


set-alias run "cd \$env(FOAM_RUN)"
set-alias sol "cd \$env(FOAM_SOLVERS)"
set-alias src "cd \$env(FOAM_SRC)"
set-alias tut "cd \$env(FOAM_TUTORIALS)"
set-alias util "cd \$env(FOAM_UTILITIES)"
set-alias wm32 "wmSet WM_ARCH_OPTION=32"
set-alias wm64 "wmSet WM_ARCH_OPTION=64"
set-alias wmDP "wmSet WM_PRECISION_OPTION=DP"
set-alias wmSP "wmSet WM_PRECISION_OPTION=SP"
set-alias wmSchedOff "unset WM_SCHEDULER"
set-alias wmSchedOn "export WM_SCHEDULER=\$env(WM_PROJECT_DIR)/wmake/wmakeScheduler"
set-alias wmSet ". \$env(WM_PROJECT_DIR)/etc/bashrc"
set-alias wmUnset ". \$env(WM_PROJECT_DIR)/etc/config.sh/unset"

EOF
    #Clean up
    . ${OPENFOAM_PATH}/etc/config.sh/unset
    cd
    rm -rf ${WORKDIR}
done
