#!/bin/bash
set -e

# Help Options
show_help() {
    cat << EOF
Usage: ${0##*/} [-h] [-v MPAS_VERSION]
Do stuff with FILE and write the result to standard output. With no FILE
or when FILE is -, read standard input.

    -h                display this help and exit
    -v MPAS_VERSION    MPAS version number
EOF
}

# Parse options
OPTIND=1 # Reset if getopts used previously
if (($# == 0)); then
    show_help
    exit 2
fi

while getopts ":v:h:" opt; do
    case ${opt} in
        v )
            MPAS_VERSION=$OPTARG
            ;;
        h )
            show_help
            exit 0
            ;;
        * )
            MPAS_VERSION="7.1"
            ;;
    esac
done

MODULES_PATH="/usr/share/Modules/modulefiles"

DEPENDS_ON="hdf5-parallel/1.10.6 pnetcdf/1.12.2 netcdf-c/4.7.4 netcdf-fortran/4.5.3 pio/2.5.4"

MPAS_URL="https://github.com/MPAS-Dev/MPAS-Model.git"

ENVIRONMENT="intel/2021.3.0;intel/2021.3.0 gcc/10.2.0;openmpi/4.1.0"

yum install -y \
    environment-modules \
    gcc \
    gcc-c++ \
    gcc-gfortran \
    git \
    hostname \
    make \
    man \
    man-pages

#Load module
source /etc/profile.d/modules.sh

# Add modules
add_dependent_modules() {
    if [[ ! -z ${MODULE_DEPENDENCIES} ]]; then
        MODULE_DEPENDENCIES+=" "
    fi

    MODULE_DEPENDENCIES+="$1"
}

#Load compilers
for comp_mpi in $ENVIRONMENT
do

    MODULE_DEPENDENCIES=""
    COMPILER=$(echo $comp_mpi | cut -d';' -f1)
    MPI=$(echo $comp_mpi | cut -d';' -f2)

    compiler_name=$(echo $COMPILER | cut -d'/' -f1)
    compiler_version=$(echo $COMPILER | cut -d'/' -f2)

    mpi_name=$(echo $MPI | cut -d'/' -f1)
    mpi_version=$(echo $MPI | cut -d'/' -f2)

    module purge
    module load compiler/${COMPILER}
    add_dependent_modules "compiler/${COMPILER}"

    if [[ "${mpi_name}" == "intel" ]]; then

        module load mpi/${MPI}
        add_dependent_modules "mpi/${MPI}"
    else
        module load mpi/${MPI}-${compiler_name}-${compiler_version}
        add_dependent_modules "mpi/${MPI}-${compiler_name}-${compiler_version}"
    fi

    if [[ "${compiler_name}" == "intel" ]]; then
        export I_MPI_CC=icc
        export I_MPI_CXX=icpc
        export I_MPI_FC=ifort
        export I_MPI_F90=ifort
    fi

    # Create build directory in /tmp
    WORKDIR=`mktemp -d -p /tmp -t mpas_XXXXXXXXXXXX`
    cd ${WORKDIR}

    MPAS_PATH="/opt/mpas-omp/${MPAS_VERSION}/${compiler_name}/${compiler_version}"

    # Check if already installed
    if [ -d ${MPAS_PATH} ];
    then
        echo "MPAS already installed in ${MPAS_PATH}"
        continue
    fi

    # Load depdencies
    for i in $DEPENDS_ON
    do
        module load ${i}-${compiler_name}-${compiler_version}
        add_dependent_modules "${i}-${compiler_name}-${compiler_version}"
    done


    # Retreive mpas from git repo
    git clone -b v"${MPAS_VERSION}" ${MPAS_URL}
    cd MPAS-Model

    # Link NETCDF C and Fortran
    ln -sf $NETCDF_FORTRAN_HOME/include/* $NETCDF_C_HOME/include/
    find -L $NETCDF_FORTRAN_HOME/lib -maxdepth 1 -name "*" -type f -exec ln -sf {} $NETCDF_C_HOME/lib/ \;
    find -L $NETCDF_FORTRAN_HOME/lib/pkgconfig -maxdepth 1 -name "*" -type f -exec ln -sf {} $NETCDF_C_HOME/lib/pkgconfig/ \;

    # Set env var for MPAS
    export PHDF5=$HDF5_PARALLEL_HOME
    export NETCDF=$NETCDF_C_HOME
    export PNETCDF=$PNETCDF_HOME
    export PIO=$PIO_HOME

    if [[ "${compiler_name}" == "intel" ]]; then
        MPAS_CONFIG="ifort"
    elif [[ "${compiler_name}" == "gcc" ]]; then
        MPAS_CONFIG="gfortran"
    fi

    make clean CORE=atmosphere PRECISION=single
    make -j $(nproc) ${MPAS_CONFIG} CORE=atmosphere PRECISION=single USE_PIO2=true OPENMP=true
    
    make clean CORE=init_atmosphere PRECISION=single
    make -j $(nproc) ${MPAS_CONFIG} CORE=init_atmosphere PRECISION=single USE_PIO2=true OPENMP=true

    mkdir -p ${MPAS_PATH}/bin
    cp atmosphere_model ${MPAS_PATH}/bin
    cp init_atmosphere_model ${MPAS_PATH}/bin

    mkdir -p ${MODULES_PATH}/mpas-omp

    #Create module file
    cat > ${MODULES_PATH}/mpas-omp/${MPAS_VERSION}-${compiler_name}-${compiler_version} << EOF
#%Module

# NOTE: This is an automatically-generated file!
proc ModulesHelp { } {
   puts stderr "This module adds MPAS v${MPAS_VERSION} to various paths"
}

module-whatis "Sets up MPAS v${MPAS_VERSION} in your environment"

EOF

    for i in ${MODULE_DEPENDENCIES}
    do
        cat >> ${MODULES_PATH}/mpas-omp/${MPAS_VERSION}-${compiler_name}-${compiler_version} << EOF
module load ${i}

EOF
    done

    cat >> ${MODULES_PATH}/mpas-omp/${MPAS_VERSION}-${compiler_name}-${compiler_version} << EOF
prepend-path PATH "${MPAS_PATH}/bin"

EOF


    #Clean up
    cd
    rm -rf ${WORKDIR}
done

# Retreive mpas from git repo
MPAS_SRC_PATH="/opt/mpas-omp/src"
mkdir -p ${MPAS_SRC_PATH}
git clone -b v"${MPAS_VERSION}" ${MPAS_URL} ${MPAS_SRC_PATH}
