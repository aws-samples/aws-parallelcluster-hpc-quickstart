#!/bin/bash

#SBATCH --job-name=c5n-intel-lj
#SBATCH --partition=c5n-od
#SBATCH --output=/fsx/performance/%x_%j.out
#SBATCH --error=/fsx/performance/%x_%j.err
#SBATCH --export=ALL
#SBATCH --ntasks=1152


export I_MPI_OFI_LIBRARY_INTERNAL=0
export I_MPI_OFI_PROVIDER=efa

module purge
module load compiler/intel/2022.2.0 mpi/intel/2022.2.0 lammps/stable_29Oct2020-intel-2022.2.0


WORK_DIR="/fsx/performance/$SLURM_JOB_NAME_$SLURM_JOB_ID"
mkdir -p ${WORK_DIR}
wget -P ${WORK_DIR} https://raw.githubusercontent.com/lammps/lammps/stable_29Oct2020/bench/in.lj

mpirun lmp_intel_cpu_intelmpi -var x 30 -var y 30 -var z 30 -in ${WORK_DIR}/in.lj
