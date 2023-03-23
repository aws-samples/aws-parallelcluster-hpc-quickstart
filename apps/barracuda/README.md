# Barracuda on AWS ParallelCluster

Barracuda on AWS ParallelCluster provides steps and code samples to build and run Barracuda Virtual Reactor on AWS using [AWS ParallelCluster](<https://docs.aws.amazon.com/parallelcluster/>).

## Barracuda On AWS

Barracuda Virtual Reactor simulates the 3D, transient behavior in fluid-particle systems including the multiphase hydrodynamics, heat balance and chemical reactions.
It is a product from CPFD Software, visit their [webpage](https://cpfd-software.com/) for more information.

### Architecture

![Barracuda ParallelCluster Architecture](<docs/images/barracuda_architecture.png>)

## Deploying Barracuda on AWS

### AWS CloudShell

[AWS CloudShell](<https://docs.aws.amazon.com/cloudshell/latest/userguide/welcome.html>) is a browser-based, pre-authenticated shell that you can launch directly from the AWS Management Console.
You can run AWS CLI commands against AWS services using your preferred shell, such as Bash, PowerShell, or Z shell.
And, you can do this without needing to download or install command line tools.

You can launch AWS CloudShell from the AWS Management Console, and the AWS credentials that you used to sign in to the console are automatically available in a new shell session.
This pre-authentication of AWS CloudShell users allows you to skip configuring credentials when interacting with AWS services using AWS CLI version 2.
The AWS CLI is pre-installed on the shell's compute environment.

[Launch AWS CloudShell](<https://console.aws.amazon.com/cloudshell/home>)


### Prerequisites

Let start by downloading the Barracuda repository containing the Infrastructure as Code on your **AWS CloudShell**.

On the **AWS CloudShell**, run the script below to install the prerequisited software:

```bash
wget https://github.com/aws-samples/awsome-hpc/archive/refs/heads/main.tar.gz
mkdir -p AWSome-hpc
tar -xvzf main.tar.gz -C AWSome-hpc --strip-components 1
cd AWSome-hpc/apps/barracuda
bash ./scripts/setup/install_prerequisites.sh
```

The script will install the following on the Cloud9 instance:

- [AWS CLI version 2](<https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html>).
- [jq](<https://stedolan.github.io/jq/>).
- [yq](<https://github.com/mikefarah/yq>).

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
echo "export CLUSTER_NAME=${CLUSTER_NAME}" >> ~/.bashrc
pcluster create-cluster -n ${CLUSTER_NAME} -c config/barracuda-cluster.yaml --region ${AWS_REGION}
```

Connect to the cluster

```bash
pcluster ssh -n ${CLUSTER_NAME} -i ~/.ssh/${SSH_KEY_NAME} --region ${AWS_REGION}
```

Download Barracuda
```bash
wget -P /shared https://cpfd-software.com/wp-content/uploads/2022/11/barracuda_virtual_reactor-22.1.0-Linux.tar.gz
```

Extract archive
```bash
tar -xvzf /shared/barracuda_virtual_reactor-22.1.0-Linux.tar.gz -C /shared
```

Install Barracuda
```bash
/shared/barracuda_virtual_reactor-22.1.0-Linux/barracuda_virtual_reactor-22.1.0-Linux.run install --default-answer --accept-licenses --confirm-command --root /shared/Barracuda/22.1.0
echo "export PATH=/shared/Barracuda/22.1.0/bin:$PATH" >> ~/.bashrc
```

## Run Barracuda

In this section, you will go through the steps to run test case(s) provided by Barracuda on AWS ParallelCluster.

### Gasifier

In this section, you will learn how to run Barracuda on a Gasifier test case.

#### Setup

Download Sample case.
```bash
wget -P /shared https://cpfd-software.com/wp-content/uploads/2023/02/barracuda_sample_case.zip
```

Add your license file in `/shared/ls.rlmcloud.com.lic`

Create submission script.
```bash
cat > barracuda-gasifier-sub.sh << EOF
#!/bin/bash

#SBATCH --job-name=barracuda-gasifier
#SBATCH --output=%x_%j.out
#SBATCH --error=%x_%j.err
#SBATCH --partition=gpu-od-queue
#SBATCH --ntasks=1
#SBATCH --gpus=v100:1
#SBATCH --constraint=p3

# Set WORK_DIR as scratch if local storage exist.
# Otherwise use tmp
export WORK_DIR=/scratch/\$SLURM_JOB_ID

if [ ! -d /scratch ]; then
    export WORK_DIR=/tmp/\$SLURM_JOB_ID
fi

echo \$WORK_DIR
unzip -j /shared/barracuda_sample_case.zip -d \${WORK_DIR}
cd \${WORK_DIR}

export cpfd_LICENSE="/shared/ls.rlmcloud.com.lic"
/shared/Barracuda/22.1.0/bin/cpfd.x -ow -cc -ct -cbc -cic -qmdp -qll -qfe -gpu -d0 -fallback quit gasifier.prj

tar -czf /shared/barracuda-gasifier-results.tar.gz \${WORK_DIR}
EOF
```

#### Submit test case to Slurm

```bash
sbatch barracuda-gasifier-sub.sh << EOF
```

The job should complete in ~4 hours on one `p3.2xlarge` Amazon EC2 Instances.

#### Visualize Gasifier results

Once the simulation is completed, you can visualize the results.

Extract the results archive
```bash
tar -xvzf /shared/barracuda-gasifier-results.tar.gz
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

Copy and Paste the https link to a new tab of your web brower.
It will create a remote visualization session.
Launch Barracuda by typing `barracuda` in the terminal.

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
