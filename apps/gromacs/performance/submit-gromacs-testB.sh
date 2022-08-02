#!/bin/bash

#SBATCH --job-name=gromacs-testB
#SBATCH --partition=c5n-od
#SBATCH --output=/fsx/performance/%x_%j.out
#SBATCH --error=/fsx/performance/%x_%j.err
#SBATCH --export=ALL
#SBATCH --nodes=16
#SBATCH --ntasks-per-node=36
#SBATCH --cpus-per-task=1

export I_MPI_OFI_LIBRARY_INTERNAL=0
export I_MPI_OFI_PROVIDER=efa

export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK

module purge
module load compiler/intel/2022.2.0 mpi/intel/2022.2.0 gromacs/v2021.4-intel-2022.2.0

cd Gromacs-TestCaseB
mpirun gmx_mpi mdrun -ntomp $OMP_NUM_THREADS -s benchRIB.tpr -resethway
