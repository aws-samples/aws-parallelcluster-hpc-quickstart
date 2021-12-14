#!/bin/bash
set -e

MODULES_PATH="/usr/share/Modules/modulefiles"

INTEL_VERSION="2020.1.217"

INTEL_PATH="/opt/intel"

INTEL_ARCHIVE="parallel_studio_xe_2020_update1_cluster_edition.tgz"
INTEL_URL="https://registrationcenter-download.intel.com/akdlm/irc_nas/tec/16526/${INTEL_ARCHIVE}"

show_help() {
    cat << EOF
Usage: ${0##*/} [-hv] [-f OUTFILE] [FILE]...
Do stuff with FILE and write the result to standard output. With no FILE
or when FILE is -, read standard input.

    -h                  display this help and exit
    -l SERIAL_NUMBER    Intel Serial number
EOF
}

# Parse options
OPTIND=1 # Reset if getopts used previously
if (($# == 0)); then
    show_help
    exit 2
fi

while getopts ":l:h:" opt; do
    case ${opt} in
        l )
            INTEL_SERIAL_NUMBER=$OPTARG
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

# Exit if already installed
[ -f ${INTEL_PATH}/compilers_and_libraries_${INTEL_VERSION}/linux/bin/intel64/icc ] && exit 0

yum install -y \
    alsa-lib \
    gcc \
    gcc-c++ \
    gcc-gfortran \
    gtk2 \
    gzip \
    make \
    man \
    man-pages \
    pango \
    tar \
    util-linux \
    which \
    xorg-x11-server-Xorg

# Create build directory in /tmp
WORK_DIR=$(mktemp -d /tmp/intel.XXXXXXXXX)
cd ${WORK_DIR}

# Retrieve Intel compiler
if [ ! -f ${INTEL_ARCHIVE} ]; then
    echo "Download Intel studio archive"
    curl -O ${INTEL_URL}
fi

# Check if archive already untar
if [ ! -d ${INTEL_ARCHIVE%%.*} ]; then
    echo "Extract Intel studio archive"
    tar xzf ${INTEL_ARCHIVE}
fi

cd ${INTEL_ARCHIVE%%.*}


cat > intel.config << EOF
ACCEPT_EULA=accept
CONTINUE_WITH_OPTIONAL_ERROR=yes
PSET_INSTALL_DIR=${INTEL_PATH}
CONTINUE_WITH_INSTALLDIR_OVERWRITE=yes
COMPONENTS=;intel-conda-index-tool__x86_64;intel-comp__x86_64;intel-comp-32bit__x86_64;intel-comp-doc__noarch;intel-comp-l-all-common__noarch;intel-comp-l-all-vars__noarch;intel-comp-nomcu-vars__noarch;intel-comp-ps-32bit__x86_64;intel-comp-ps__x86_64;intel-comp-ps-ss-bec__x86_64;intel-comp-ps-ss-bec-32bit__x86_64;intel-openmp__x86_64;intel-openmp-32bit__x86_64;intel-openmp-common__noarch;intel-openmp-common-icc__noarch;intel-openmp-common-ifort__noarch;intel-openmp-ifort__x86_64;intel-openmp-ifort-32bit__x86_64;intel-tbb-libs-32bit__x86_64;intel-tbb-libs__x86_64;intel-tbb-libs-common__noarch;intel-conda-intel-openmp-linux-64-shadow-package__x86_64;intel-conda-intel-openmp-linux-32-shadow-package__x86_64;intel-conda-icc_rt-linux-64-shadow-package__x86_64;intel-icc__x86_64;intel-c-comp-common__noarch;intel-icc-common__noarch;intel-icc-common-ps__noarch;intel-icc-doc__noarch;intel-icc-ps__x86_64;intel-icc-ps-ss-bec__x86_64;intel-icx__x86_64;intel-icx-common__noarch;intel-ifort__x86_64;intel-ifort-common__noarch;intel-ifort-doc__noarch;intel-mkl-common__noarch;intel-mkl-core__x86_64;intel-mkl-core-rt__x86_64;intel-mkl-doc__noarch;intel-mkl-doc-ps__noarch;intel-mkl-gnu__x86_64;intel-mkl-gnu-rt__x86_64;intel-mkl-cluster__x86_64;intel-mkl-cluster-rt__x86_64;intel-mkl-common-ps__noarch;intel-mkl-core-ps__x86_64;intel-mkl-pgi__x86_64;intel-mkl-pgi-rt__x86_64;intel-conda-mkl-linux-64-shadow-package__x86_64;intel-conda-mkl-static-linux-64-shadow-package__x86_64;intel-conda-mkl-devel-linux-64-shadow-package__x86_64;intel-conda-mkl-include-linux-64-shadow-package__x86_64;intel-mkl-common-c__noarch;intel-mkl-core-c__x86_64;intel-mkl-common-c-ps__noarch;intel-mkl-cluster-c__noarch;intel-mkl-tbb__x86_64;intel-mkl-tbb-rt__x86_64;intel-mkl-pgi-c__x86_64;intel-mkl-gnu-c__x86_64;intel-mkl-common-f__noarch;intel-mkl-core-f__x86_64;intel-mkl-cluster-f__noarch;intel-mkl-gnu-f-rt__x86_64;intel-mkl-gnu-f__x86_64;intel-mkl-f95-common__noarch;intel-mkl-f__x86_64;intel-ipp-common__noarch;intel-ipp-common-ps__noarch;intel-ipp-st__x86_64;intel-ipp-mt__x86_64;intel-ipp-st-devel__x86_64;intel-ipp-mt-devel__x86_64;intel-ipp-doc__noarch;intel-conda-ipp-linux-64-shadow-package__x86_64;intel-conda-ipp-static-linux-64-shadow-package__x86_64;intel-conda-ipp-include-linux-64-shadow-package__x86_64;intel-conda-ipp-devel-linux-64-shadow-package__x86_64;intel-tbb-devel__x86_64;intel-tbb-common__noarch;intel-tbb-doc__noarch;intel-conda-tbb-linux-64-shadow-package__x86_64;intel-conda-tbb-devel-linux-64-shadow-package__x86_64;intel-daal-core__x86_64;intel-daal-common__noarch;intel-daal-doc__noarch;intel-conda-daal-linux-64-shadow-package__x86_64;intel-conda-daal-static-linux-64-shadow-package__x86_64;intel-conda-daal-include-linux-64-shadow-package__x86_64;intel-conda-daal-devel-linux-64-shadow-package__x86_64;intel-daal-doc-ps__noarch;intel-imb__x86_64;intel-mpi-rt__x86_64;intel-mpi-sdk__x86_64;intel-mpi-doc__x86_64;intel-mpi-samples__x86_64;intel-conda-impi_rt-linux-64-shadow-package__x86_64;intel-conda-impi-devel-linux-64-shadow-package__x86_64;intel-gdb__x86_64;intel-gdb-source__noarch;intel-gdb-python-source__noarch;intel-gdb-common__noarch;intel-gdb-common-ps__noarch;intel-icsxe__noarch;intel-psxe-common__noarch;intel-psxe-doc__noarch;intel-psxe-common-doc__noarch;intel-icsxe-doc__noarch;intel-psxe-licensing__noarch;intel-psxe-licensing-doc__noarch;intel-python3-psxe__noarch;intel-python-nopyver__noarch;intel-icsxe-pset
PSET_MODE=install
ACTIVATION_SERIAL_NUMBER=${INTEL_SERIAL_NUMBER}
ACTIVATION_TYPE=serial_number
AMPLIFIER_SAMPLING_DRIVER_INSTALL_TYPE=kit
AMPLIFIER_DRIVER_ACCESS_GROUP=vtune
AMPLIFIER_DRIVER_PERMISSIONS=660
AMPLIFIER_LOAD_DRIVER=no
AMPLIFIER_C_COMPILER=auto
AMPLIFIER_KERNEL_SRC_DIR=auto
AMPLIFIER_MAKE_COMMAND=auto
AMPLIFIER_INSTALL_BOOT_SCRIPT=no
AMPLIFIER_DRIVER_PER_USER_MODE=no
INTEL_SW_IMPROVEMENT_PROGRAM_CONSENT=no
ARCH_SELECTED=INTEL64
EOF

./install.sh -s intel.config

#Clean up
rm -rf {WORK_DIR}

mkdir -p ${MODULES_PATH}/compiler/intel

#Create module file
cat > ${MODULES_PATH}/compiler/intel/${INTEL_VERSION} << EOF
#%Module

# NOTE: This is an automatically-generated file!

## Required internal variables
set name     intel
set version  ${INTEL_VERSION}
set root     ${INTEL_PATH}/compilers_and_libraries_\$version

proc ModulesHelp { } {
   puts stderr "This module adds Intel Compiler ${INTEL_VERSION} to various paths"
}

module-whatis "Sets up Intel Compiler ${INTEL_VERSION} in your environment"

prepend-path PATH \$root/linux/bin
prepend-path PATH \$root/linux/bin/intel64
prepend-path LD_LIBRARY_PATH \$root/linux/compiler/lib/intel64_lin
prepend-path LIBRARY_PATH \$root/linux/compiler/lib/intel64_lin

#MKL
prepend-path CPATH \$root/linux/mkl/include
prepend-path LD_LIBRARY_PATH \$root/linux/mkl/lib/intel64_lin
prepend-path LIBRARY_PATH \$root/linux/mkl/lib/intel64_lin
prepend-path PKG_CONFIG_PATH \$root/linux/mkl/bin/pkgconfig
#IPP
prepend-path CPATH \$root/linux/ipp/include
prepend-path LD_LIBRARY_PATH \$root/linux/ipp/lib/intel64
prepend-path LIBRARY_PATH \$root/linux/ipp/lib/intel64
#DAAL
prepend-path CPATH \$root/linux/daal/include
prepend-path LD_LIBRARY_PATH \$root/linux/tbb/lib/intel64/gcc4.8:\$root/linux/tbb/lib/intel64/gcc4.8:\$root/linux/daal/lib/intel64_lin:\$root/linux/daal/../tbb/lib/intel64_lin/gcc4.4:\$root/linux/daal/../tbb/lib/intel64_lin/gcc4.8
prepend-path LIBRARY_PATH \$root/linux/tbb/lib/intel64/gcc4.8:\$root/linux/tbb/lib/intel64/gcc4.8:\$root/linux/daal/lib/intel64_lin:\$root/linux/daal/../tbb/lib/intel64_lin/gcc4.4:\$root/linux/daal/../tbb/lib/intel64_lin/gcc4.8
#TBB
prepend-path CPATH \$root/linux/tbb/include
prepend-path LD_LIBRARY_PATH \$root/linux/tbb/lib/intel64/gcc4.8:\$root/linux/tbb/lib/intel64/gcc4.8
prepend-path LIBRARY_PATH \$root/linux/tbb/lib/intel64/gcc4.8:\$root/linux/tbb/lib/intel64/gcc4.8
#PSTL
prepend-path CPATH \$root/linux/pstl/include:\$root/linux/pstl/stdlib

prepend-path MANPATH \$root/linux/man
prepend-path NLSPATH \$root/linux/compiler/lib/intel64/locale/%l_%t/%N:\$root/linux/mkl/lib/intel64_lin/locale/%l_%t/%N

setenv MKLROOT \$root/linux/mkl
setenv TBBROOT \$root/linux/tbb
setenv IPPROOT \$root/linux/ipp
setenv DAALROOT \$root/linux/daal

setenv INTEL_LICENSE_FILE \$root/linux/licenses
setenv PSTLROOT \$root/linux/pstl

EOF

mkdir -p ${MODULES_PATH}/mpi/intel

INTEL_MPI_VERSION=$(find -L /opt/intel/impi -samefile ${INTEL_PATH}/compilers_and_libraries_${INTEL_VERSION}/linux/mpi | awk -F "/" '{print $NF}')

cp ${INTEL_PATH}/compilers_and_libraries_${INTEL_VERSION}/linux/mpi/intel64/modulefiles/mpi ${MODULES_PATH}/mpi/intel/${INTEL_MPI_VERSION}
sed -i "s%\$topdir%${INTEL_PATH}/compilers_and_libraries_${INTEL_VERSION}/linux/mpi%g" ${MODULES_PATH}/mpi/intel/${INTEL_MPI_VERSION}
