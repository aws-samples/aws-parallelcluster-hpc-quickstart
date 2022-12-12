# MPAS on AWS

MPAS repo provides steps and code samples to deploy MPAS on AWS using [AWS ParallelCluster](<https://docs.aws.amazon.com/parallelcluster/>).
It is targeted for x86 architectures.

### Architecture

![MPAS_Architecture](<docs/images/mpas_architecture.png>)

## Deploying MPAS on AWS

### AWS Cloud9 Environment

[AWS Cloud9](<https://aws.amazon.com/cloud9/>) is a cloud-based integrated development environment (IDE) that lets you write, run, and debug your code with just a browser.

AWS Cloud9 contains a collection of tools that let you code, build, run, test, debug, and release software in the cloud using your internet browser. The IDE offers support for python, pip, AWS CLI, and provides easy access to AWS resources through Identity and Access Management (IAM) user credentials. The IDE includes a terminal with sudo privileges to the managed instance that is hosting your development environment. This makes it easy for you to quickly run commands and directly access AWS services.

#### Create an AWS Cloud9 environment:

The link below will create an AWS Cloud9 environment from which you will be able to create your cluster.

[![Launch Stack](<https://samdengler.github.io/cloudformation-launch-stack-button-svg/images/us-east-1.svg>)](<https://us-east-1.console.aws.amazon.com/cloudformation/home?region=us-east-1#/stacks/create/template?stackName=hpcsolutions-cloud9&templateURL=https://awsome-hpc.s3.amazonaws.com/cf_hpc_solutions_cloud9.yaml>)

[![Launch Stack](<https://samdengler.github.io/cloudformation-launch-stack-button-svg/images/us-east-2.svg>)](<https://us-east-2.console.aws.amazon.com/cloudformation/home?region=us-east-2#/stacks/create/template?stackName=hpcsolutions-cloud9&templateURL=https://awsome-hpc.s3.amazonaws.com/cf_hpc_solutions_cloud9.yaml>)

1. Open the [AWS Cloud9 console](<https://console.aws.amazon.com/cloud9>).
1. Select **MyCloud9Env**.
1. Choose **Open IDE**.

#### Disable AWS managed temporary credentials:

1. Once the Cloud9 environment is created.
1. Choose the **gear icon** in the top right to open the Prefences tab.
1. In the **Preferences** tab, choose **AWS SETTINGS**.
1. Turn off the **AWS managed temporary credentials**.
1. Close the **Preferences** tab.

### Prerequisites

Let start by downloading the MPAS repository containing the Infrastructure as Code on your Cloud9 instance.

On the Cloud9 instance terminal, run the script below to install the prerequisited software:

```bash
wget https://github.com/aws-samples/awsome-hpc/archive/refs/heads/main.tar.gz
mkdir -p AWSome-hpc
tar -xvzf main.tar.gz -C AWSome-hpc --strip-components 1
cd AWSome-hpc/apps/mpas
bash ./scripts/setup/install_prerequisites.sh
```

The script will install the following on the Cloud9 instance:

- [Python3 and pip](<https://pip.pypa.io/en/latest/installing/>).
- [Packer version 1.6.0 and above](<https://learn.hashicorp.com/tutorials/packer/getting-started-install?in=packer/getting-started>).
- [AWS CLI version 2](<https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html>).
- [Session Manager plugin](<https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html>).

### Install AWS ParallelCluster

Create your Python3 virtual environment

```bash
#Create Python3 virtual environment
python3 -m venv .env
source .env/bin/activate
```

Install AWS ParallelCluster

```bash
pip3 install aws-parallelcluster==3.2.0

# Set AWS Region
export AWS_REGION=`curl --silent http://169.254.169.254/latest/meta-data/placement/region`
```

### Building MPAS Image using Packer on AWS

The sample relies on packer to build an AWS Machine Image (AMI) containing an installation of MPAS.
It is compiled and optimized for Intel Xeon Scalable Processor using the following compiler and MPI combination:

- Intel oneAPI compiler and Intel oneAPI MPI 2022.2.0
- GNU 10.3.0 and Open MPI 4.1.4

The packer scripts are located in the amis folder and are organized by Operating System (OS) such as `\[OS\]-pc-mpas`.
The available OS for this solution are:

- Amazon Linux 2

The AMI name is generated as \[company\_name\]-\[OS\]-parallelcluster-\[parallel\_cluster\_version\]-\[application\_name\]-\[application\_version\]-\[isotime YYYMMDDHHmmss\].

Different variables are passed to packer to build the MPAS AMI. For simplicity, they have preset values and you can find the list and description of the variables in this [document](<docs/packer_ami_variables.md>).

#### Build an AMI

Navigate to the `amis` folder, choose the desired OS, build the AMI using packer.
You can accomplish this by typing:

```bash
# Set OS for MPAS to be amzn2
OS_MPAS=amzn2

# Go to the corresponding folder
cd amis/amzn2-pc-mpas

# Build the ami using packer
packer build \
    -var-file variables.json \
    -var aws_region=${AWS_REGION} \
    -var parallel_cluster_version=`pcluster version | jq -r '.version'` \
    -var company_name=[COMPANY_NAME] \
    amzn2-pc-mpas.json
```

### Deploy AWS ParallelCluster with MPAS

Create the AWS ParallelCluster Configuration file.
Instances that will be used are c5n.18xlarge

```bash
# Going back from where you started
cd ../../
source ./scripts/setup/create_parallelcluster_config.sh
```

Create the MPAS Cluster

```bash
CLUSTER_NAME="mpas-cluster"
pcluster create-cluster -n ${CLUSTER_NAME} -c config/mpas-x86-64.yaml --region ${AWS_REGION}
```

Connect to the cluster

```bash
pcluster ssh -n ${CLUSTER_NAME} -i ~/.ssh/${SSH_KEY_NAME} --region ${AWS_REGION}
```

### Run Supercell test case

#### Download Supercell thunderstorm case

The Supercell thunderstorm is an idealized test-case on the Cartesian plane. The test-case includes an MPAS mesh file, mesh decomposition files for certain MPI tasks counts, a namelist file for creating initial conditions and a namelist file for running the model.

On the HPC Cluster, download the Supercell test case from the [repo](<https://mpas-dev.github.io/atmosphere/test_cases.html>) into the **/fsx** directory.
**/fsx** is the mount point of the high performance file system, [Amazon FSx for Lustre](<https://aws.amazon.com/fsx/lustre/>).

Here are the steps:

```bash
cd /fsx
curl -LO http://www2.mmm.ucar.edu/projects/mpas/test_cases/v7.0/supercell.tar.gz
tar -xzf supercell.tar.gz && cd supercell
```

#### Run the Supercell simulation

In this step, you create the SLURM batch script that will run the MPAS-Atmosphere Supercell test case on 72 physical cores distributed over 2 x c5n.18xlarge EC2 instances.

```bash
cat > slurm-c5n-mpas-supercell.sh << EOF
#!/bin/bash

#SBATCH --job-name=MPAS-Supercell
#SBATCH --partition=c5n18large
#SBATCH --output=%x_%j.out
#SBATCH --error=%x_%j.err
#SBATCH --ntasks=72
#SBATCH --ntasks-per-node 36
#SBATCH --cpus-per-task=1


export I_MPI_OFI_LIBRARY_INTERNAL=0
export I_MPI_OFI_PROVIDER=efa

module purge
module load metis/5.1.0-gcc-10.3.0
module load mpas-omp/7.1-intel-2022.2.0

#Create mesh decomposition for the specified MPI ranks
gpmetis -minconn -contig -niter=200 supercell.graph.info \${SLURM_NPROCS}

#Create initial conditions
mpirun init_atmosphere_model

#Run the model
mpirun atmosphere_model
EOF
```

Run the Supercell test case on 2 x c5n.18xlarge instances

```bash
sbatch slurm-c5n-mpas-supercell.sh
```

Note that this will dynamically spin up the requested instances (i.e. 2x c5n.18xlarge) The job should complete in a few minutes after the instances are up with the output and error files located in the run directory.

## Cleanup your cluster

To avoid unexpected charges to your account relative to the WRF cluster, make sure you delete the cluster and associated resources.

### Delete the cluster.

```bash
pcluster delete-cluster -n ${CLUSTER_NAME} --region ${AWS_REGION}
```

**The steps below are optional if you plan to deploy a cluster with WRF in the future.**

Delete remaining components of the WRF solution

```bash
. ./scripts/cleanup/cleanup_solution_components.sh
```

### Delete the AWS Cloud9 environment:

1. Open the [AWS CloudFormation](<https://console.aws.amazon.com/cloudformation>).
1. Select **hpcsolutions-cloud9**.
1. Choose **Delete**.
1. Choose **Delete** to confirm deletion.
