# OpenFOAM on AWS ParallelCluster

OpenFOAM on AWS ParallelCluster provides steps and code samples to build and run OpenFOAM on AWS using [AWS ParallelCluster](<https://docs.aws.amazon.com/parallelcluster/>).
It is targeted for Intel and AMD CPU Platform from Haswell and onward.

## OpenFOAM On AWS

### Architecture

![OpenFOAM ParallelCluster Architecture](<docs/images/openfoam_architecture.png>)

## Deploying OpenFOAM on AWS

### AWS Cloud9 Environment

[AWS Cloud9](<https://aws.amazon.com/cloud9/>) is a cloud-based integrated development environment (IDE) that lets you write, run, and debug your code with just a browser.

AWS Cloud9 contains a collection of tools that let you code, build, run, test, debug, and release software in the cloud using your internet browser. The IDE offers support for python, pip, AWS CLI, and provides easy access to AWS resources through Identity and Access Management (IAM) user credentials. The IDE includes a terminal with sudo privileges to the managed instance that is hosting your development environment. This makes it easy for you to quickly run commands and directly access AWS services.

#### Create an AWS Cloud9 environment:

The link below will create an AWS Cloud9 environment from which you will be able to create your cluster.

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

Let start by downloading the OpenFOAM repository containing the Infrastructure as Code on your **Cloud9 instance**.

On the **Cloud9 instance terminal**, run the script below to install the prerequisited software:

```bash
wget https://github.com/aws-samples/awsome-hpc/archive/refs/heads/main.tar.gz
mkdir -p AWSome-hpc
tar -xvzf main.tar.gz -C AWSome-hpc --strip-components 1
cd AWSome-hpc/apps/openfoam
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
python3 -m venv .env
source .env/bin/activate
```

Install AWS ParallelCluster

```bash
pip3 install aws-parallelcluster==3.2.0
```

Set AWS Region
The command below will query the metadata of the AWS Cloud9 instance to determine in which region it has been created.

```bash
export AWS_REGION=`curl --silent http://169.254.169.254/latest/meta-data/placement/region`
```

### Building OpenFOAM Image using Packer on AWS

The sample relies on packer to build an AWS Machine Image (AMI) containing an installation of OpenFOAM.
It is compiled and optimized for Intel Xeon Scalable Processor using the following compiler and MPI combination:

- Intel oneAPI compiler and Intel oneAPI MPI 2022.2.0
- GNU 10.3.0 and Open MPI 4.1.4

The packer scripts are located in the amis folder and are organized by Operating System (OS) such as `\[OS\]-pc-openfoam`.
The available OS for this solution are:

- Amazon Linux 2

The AMI name is generated as \[company\_name\]-\[OS\]-parallelcluster-\[parallel\_cluster\_version\]-\[application\_name\]-\[application\_version\]-\[isotime YYYMMDDHHmmss\].

Different variables are passed to packer to build the OpenFOAM AMI. For simplicity, they have preset values and you can find the list and description of the variables in this [document](<docs/packer_ami_variables.md>).

#### Build an AMI

Navigate to the `amis` folder, choose the desired OS, build the AMI using packer.
You can accomplish this by typing:

```bash
# Set OS for OpenFOAM to be amzn2 or CentOS 7
COMPANY_NAME=AnyCompany
OS_TYPE=amzn2

# Go to the corresponding folder
cd amis/${OS_TYPE}-pc-openfoam

# Build the ami using packer
packer build \
    -var-file variables.json \
    -var aws_region=${AWS_REGION} \
    -var parallel_cluster_version=`pcluster version | jq -r '.version'` \
    -var company_name=${COMPANY_NAME} \
    ${OS_TYPE}-pc-openfoam.json
```

### Deploy AWS ParallelCluster with OpenFOAM

Create the AWS ParallelCluster Configuration file.
Instances that will be used are c5n.18xlarge

```bash
# Going back from where you started
cd ../../

. ./scripts/setup/create_parallelcluster_config.sh
```

Create the OpenFOAM Cluster

```bash
CLUSTER_NAME="openfoam-cluster"
pcluster create-cluster -n ${CLUSTER_NAME} -c config/openfoam-x86-64.yaml --region ${AWS_REGION}
```

Connect to the cluster

```bash
pcluster ssh -n ${CLUSTER_NAME} -i ~/.ssh/${SSH_KEY_NAME} --region ${AWS_REGION}
```

## Run OpenFOAM

In this section, you will go through the steps to run test case(s) provided by OpenFOAM on AWS ParallelCluster.

Once you are connected to the OpenFOAM cluster, you should navigate to the `/fsx` directory.
Here are the steps:

### MotorBike 4 Million Cells

In this section, you will learn how to run simpleFoam from OpenFoam on a Motorobike test case.

#### Run simpleFoam

Create a work directory on FSx for Lustre, `/fsx`
```bash
MOTORBIKE_DIR="/fsx/motorBikeDemo"
mkdir -p ${MOTORBIKE_DIR}
```

Load OpenFoam environment for Intel oneAPI compiler.
```bash
module load openfoam/2012-intel-2022.2.0
```

Copy MotorBike tutorial case to FSx for Lustre
```bash
cp -r $FOAM_TUTORIALS/incompressible/simpleFoam/motorBike/* ${MOTORBIKE_DIR}/
```

Create a script to change the default tutorial Motorbike case to 4 Million cells.
```bash
cat > ~/change_motorbike.sh << EOF
#Change the number of subdomains to 192 to run on 192 cores.

sed  's%numberOfSubdomains.*$%numberOfSubdomains 192;%g;s%(.*$%(8 6 4);%g' \${MOTORBIKE_DIR}/system/decomposeParDict.6 > \${MOTORBIKE_DIR}/system/decomposeParDict.hierarchical

cat > \${MOTORBIKE_DIR}/system/decomposeParDict.ptscotch  << EOF
FoamFile
{
    version     2.0;
    format      ascii;
    class       dictionary;
    object      decomposeParDict;
}
// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * //

numberOfSubdomains 192;

method          ptscotch;
EOF


#Change the maximum number of cells per core and total for the domain to obtain a 4 million cells domain.
sed  -i -e 's%maxLocalCells.*$%maxLocalCells 10000000;%g'\
    -e 's%maxGlobalCells.*$%maxGlobalCells 200000000;%g' \
    -e 's%finalLayerThickness.*%finalLayerThickness 0.5;%g' \
    -e 's% minThickness.*% minThickness 0.2;%g' \
    -e 's%levels.*%levels ((1E15 5));%g' \${MOTORBIKE_DIR}/system/snappyHexMeshDict


#Change the simulaion time and the interval to save results.
sed  -i 's%writeInterval.*$%writeInterval 50;%g;s%endTime .*$%endTime 50;%g' \${MOTORBIKE_DIR}/system/controlDict

#Change the number of cells per axis.
sed  -i 's%hex (.*$%hex (0 1 2 3 4 5 6 7) (30 12 12) simpleGrading (1 1 1)%g' \${MOTORBIKE_DIR}/system/blockMeshDict
```

Execute the script to create a 4 Million cells motorbike case.
```bash
bash ~/change_motorbike.sh
```

Create a slurm submission script
```bash
cat > slurm-hpc6a-openfoam-motorbike.sh << EOF
#!/bin/bash
#SBATCH --job-name=foam-192
#SBATCH --ntasks=192
#SBATCH --output=%x_%j.out
#SBATCH --error=%x_%j.err
#SBATCH --partition=queue0
#SBATCH --constraint=hpc6a.48xlarge

export I_MPI_OFI_LIBRARY_INTERNAL=0

module load libfabric-aws
module load openfoam/2012-intel-2022.2.0

export FI_EFA_FORK_SAFE=1
export I_MPI_OFI_PROVIDER=efa
export I_MPI_FABRICS=shm:ofi


cd ${MOTORBIKE_DIR}
mkdir -p log
cp \$FOAM_TUTORIALS/resources/geometry/motorBike.obj.gz constant/triSurface/

surfaceFeatureExtract  > ./log/surfaceFeatureExtract.log 2>&1
blockMesh  > ./log/blockMesh.log 2>&1
decomposePar -decomposeParDict system/decomposeParDict.hierarchical  > ./log/decomposePar.log 2>&1
mpirun snappyHexMesh -parallel -overwrite -decomposeParDict system/decomposeParDict.hierarchical   > ./log/snappyHexMesh.log 2>&1
mpirun checkMesh -parallel -allGeometry -constant -allTopology -decomposeParDict system/decomposeParDict.hierarchical > ./log/checkMesh.log 2>&1
mpirun redistributePar -parallel -overwrite -decomposeParDict system/decomposeParDict.ptscotch > ./log/decomposePar2.log 2>&1
mpirun renumberMesh -parallel -overwrite -constant -decomposeParDict system/decomposeParDict.ptscotch > ./log/renumberMesh.log 2>&1
mpirun patchSummary -parallel -decomposeParDict system/decomposeParDict.ptscotch > ./log/patchSummary.log 2>&1
ls -d processor* | xargs -i rm -rf ./{}/0
ls -d processor* | xargs -i cp -r 0.orig ./{}/0
mpirun potentialFoam -parallel -noFunctionObjects -initialiseUBCs -decomposeParDict system/decomposeParDict.ptscotch > ./log/potentialFoam.log 2>&1
mpirun simpleFoam -parallel  -decomposeParDict system/decomposeParDict.ptscotch > ./log/simpleFoam.log 2>&1
EOF
```

Run the MotorBike test case on 2 x hpc6a.48xlarge instances
```bash
sbatch slurm-hpc6a-openfoam-motorbike.sh
```

The job should complete in a couple of minutes with the output and log files located in the `/fsx` directory.

#### Visualize Motorbike Results

Once the simulation is completed, you can visualize the results using [Paraview](https://www.paraview.org)

Download and extract Paraview archive
```bash
curl -o ~/ParaView-5.10.1-MPI-Linux-Python3.9-x86_64.tar.gz "https://www.paraview.org/paraview-downloads/download.php?submit=Download&version=v5.10&type=binary&os=Linux&downloadFile=ParaView-5.10.1-MPI-Linux-Python3.9-x86_64.tar.gz" && \
tar -xvzf ~/ParaView-5.10.1-MPI-Linux-Python3.9-x86_64.tar.gz
```

Let's exit the head node of AWS ParallelCluster to return to AWS Cloud9 environment.
```bash
exit
```

To visualize the results of the motorbike test case, you will create remote visualization session using [DCV](https://aws.amazon.com/hpc/dcv/)
```bash
pcluster dcv-connect -n ${CLUSTER_NAME} --key-path ~/.ssh/${SSH_KEY_NAME} --region ${AWS_REGION}
```

You should obtain a reponse like this.
![DCV link](<docs/images/dcv_connect.png>)

Copy and Paste the https link to a new tab of your web brower. It will create a remote visualization session.
Launch Paraview by navigating to `~/ParaView-5.10.1-MPI-Linux-Python3.9-x86_64/bin/paraview`

Through Paraview, open the file at `/fsx/motorBikeDemo/postProcessing/cuttingPlane/50/yNormal.vtp`.
Select the '+Y' option.
![Paraview](<docs/images/paraview_y.png>)

You'll get the view of the fluid flow on the motorbike.
![Paraview](<docs/images/paraview_motorbike_4m.png>)

## Cleanup your cluster

To avoid unexpected charges to your account relative to the OpenFOAM cluster, make sure you delete the cluster and associated resources.

### Delete the cluster.

```bash
pcluster delete-cluster -n ${CLUSTER_NAME} --region ${AWS_REGION}
```

**The steps below are optional if you plan to deploy a cluster with OpenFOAM in the future.**

Delete remaining components of the OpenFOAM solution

```bash
. ./scripts/cleanup/cleanup_solution_components.sh
```

### Delete the AWS Cloud9 environment:

1. Open the [AWS CloudFormation](<https://console.aws.amazon.com/cloudformation>).
1. Select **hpcsolutions-cloud9**.
1. Choose **Delete**.
1. Choose **Delete** to confirm deletion.
