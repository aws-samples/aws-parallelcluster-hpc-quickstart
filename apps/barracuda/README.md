# Barracuda on AWS ParallelCluster

Barracuda on AWS ParallelCluster provides steps and code samples to build and run Barracuda on AWS using [AWS ParallelCluster](<https://docs.aws.amazon.com/parallelcluster/>).
It is targeted Nvidia GPU instances.

## Barracuda On AWS

### Architecture

![Barracuda ParallelCluster Architecture](<docs/images/openfoam_architecture.png>)

## Deploying Barracuda on AWS

### AWS Cloud9 Environment

[AWS Cloud9](<https://aws.amazon.com/cloud9/>) is a cloud-based integrated development environment (IDE) that lets you write, run, and debug your code with just a browser.

AWS Cloud9 contains a collection of tools that let you code, build, run, test, debug, and release software in the cloud using your internet browser. The IDE offers support for python, pip, AWS CLI, and provides easy access to AWS resources through Identity and Access Management (IAM) user credentials. The IDE includes a terminal with sudo privileges to the managed instance that is hosting your development environment. This makes it easy for you to quickly run commands and directly access AWS services.

#### Create an AWS Cloud9 environment:

The link below will create an AWS Cloud9 environment from which you will be able to create your cluster.

[![Launch Stack](<https://samdengler.github.io/cloudformation-launch-stack-button-svg/images/us-east-1.svg>)](<https://us-east-1.console.aws.amazon.com/cloudformation/home?region=us-east-1#/stacks/create/template?stackName=hpcsolutions-cloud9&templateURL=https://awsome-hpc.s3.amazonaws.com/cf_hpc_solutions_cloud9.yaml>)

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

Let start by downloading the Barracuda repository containing the Infrastructure as Code on your **Cloud9 instance**.

On the **Cloud9 instance terminal**, run the script below to install the prerequisited software:

```bash
wget https://github.com/aws-samples/awsome-hpc/archive/refs/heads/main.tar.gz
mkdir -p AWSome-hpc
tar -xvzf main.tar.gz -C AWSome-hpc --strip-components 1
cd AWSome-hpc/apps/barracuda
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
pip3 install aws-parallelcluster==3.4.1
```

Set AWS Region
The command below will query the metadata of the AWS Cloud9 instance to determine in which region it has been created.

```bash
export AWS_REGION=`curl --silent http://169.254.169.254/latest/meta-data/placement/region`
```

### Deploy AWS ParallelCluster with Barracuda

Create the AWS ParallelCluster Configuration file.
Instances that will be used are p4de.24xlarge.

```bash
. ./scripts/setup/create_parallelcluster_config.sh
```

Create the Barracuda Cluster

```bash
CLUSTER_NAME="barracuda-cluster"
pcluster create-cluster -n ${CLUSTER_NAME} -c config/barracuda-cluster.yaml --region ${AWS_REGION}
```

Connect to the cluster

```bash
pcluster ssh -n ${CLUSTER_NAME} -i ~/.ssh/${SSH_KEY_NAME} --region ${AWS_REGION}
```

Download Barracuda
```bash
wget -P /shared https://cpfd-software.com/wp-content/uploads/2023/01/barracuda_virtual_reactor-22.1.1-Linux.tar.gz
```

Extract archive
```bash
tar -xvzf /shared/barracuda_virtual_reactor-22.1.1-Linux.tar.gz -C /shared
```

Install Barracuda
```bash
/shared/barracuda_virtual_reactor-22.1.1-Linux/barracuda_virtual_reactor-22.1.1-Linux.run install --default-answer --accept-licenses --confirm-command --root /shared/Barracuda/22.1.0
```

## Run Barracuda

In this section, you will go through the steps to run test case(s) provided by Barracuda on AWS ParallelCluster.

Once you are connected to the Barracuda cluster, you should navigate to the `/fsx` directory.
Here are the steps:

### Gasifier

In this section, you will learn how to run Barracuda on a Gasifier test case.

#### Run simpleFoam

Download Sample case
```bash
wget -P /fsx https://cpfd-software.com/wp-content/uploads/2023/02/barracuda_sample_case.zip
```

Extract the sample case archive
```bash
unzip /fsx/barracuda_sample_case.zip -d /fsx
```

Submission
```bash
cat > sbatch-barracuda-gasifier.sh << EOF
#!/bin/bash

#SBATCH --job-name=barracuda-gasifier
#SBATCH --output=%x_%j.out
#SBATCH --error=%x_%j.err
#SBATCH --partition=gpu-od-queue
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=12
#SBATCH --gres=gpu:1


export cpfd_LICENSE="/shared/AWS-ls58.rlmcloud.com.lic"
/shared/Barracuda/22.1.0/bin/cpfd.x -ow -cc -ct -cbc -cic -qmdp -qll -qfe -gpu -dmulti 1 -fallback quit gasifier.prj
EOF
```

The job should complete in ~2 hours with the output and log files located in the `/fsx` directory.

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

To avoid unexpected charges to your account relative to the Barracuda cluster, make sure you delete the cluster and associated resources.

### Delete the cluster.

```bash
pcluster delete-cluster -n ${CLUSTER_NAME} --region ${AWS_REGION}
```

**The steps below are optional if you plan to deploy a cluster with Barracuda in the future.**

Delete remaining components of the Barracuda solution

```bash
. ./scripts/cleanup/cleanup_solution_components.sh
```

### Delete the AWS Cloud9 environment:

1. Open the [AWS CloudFormation](<https://console.aws.amazon.com/cloudformation>).
1. Select **hpcsolutions-cloud9**.
1. Choose **Delete**.
1. Choose **Delete** to confirm deletion.
