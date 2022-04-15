#!/bin/bash

# Find parent path
PARENT_PATH=$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )


# Define AWS Region
if [ -z ${AWS_REGION} ]; then
    echo "[ERROR] AWS_REGION environment variable is not set"
    return 1
else
    echo "[INFO] AWS_REGION = ${AWS_REGION}"
fi


# Define Instances seperated by ','
export INSTANCES="c5n.18xlarge"


# Create SSH Key
export SSH_KEY_NAME="mpas-ssh-key"

[ ! -d ~/.ssh ] && mkdir -p ~/.ssh && chmod 700 ~/.ssh

SSH_KEY_EXIST=`aws ec2 describe-key-pairs --query KeyPairs[*] --filters Name=key-name,Values=${SSH_KEY_NAME} --region ${AWS_REGION} | jq "select(length > 0)"`

if [[ -z ${SSH_KEY_EXIST} ]]; then
    aws ec2 create-key-pair --key-name ${SSH_KEY_NAME} \
        --query KeyMaterial \
        --region ${AWS_REGION} \
        --output text > ~/.ssh/${SSH_KEY_NAME}

    chmod 600 ~/.ssh/${SSH_KEY_NAME}
else
    echo "[WARNING] SSH_KEY_NAME ${SSH_KEY_NAME} already exist"
fi

echo "[INFO] SSH_KEY_NAME = ${SSH_KEY_NAME}"


# Retrieve VPC ID and Subnet ID
# You can alternatively set to the VPC ID of your choice insteasd of the default VPC
if [[ -z ${VPC_ID} ]]; then
    VPC_ID=`aws ec2 describe-vpcs --output text \
        --query 'Vpcs[*].VpcId' \
        --filters Name=isDefault,Values=true \
        --region ${AWS_REGION}`
fi

if [[ ! -z $VPC_ID ]]; then
    echo "[INFO] VPC_ID = ${VPC_ID}"
else
    echo "[ERROR] failed to retrieve VPC ID"
    return 1
fi


# Find in which avaibility zone instances are available
AZ_W_INSTANCES=`aws ec2 describe-instance-type-offerings --location-type "availability-zone" \
    --filters Name=instance-type,Values=${INSTANCES} \
    --query InstanceTypeOfferings[].Location \
    --region ${AWS_REGION} | jq -r ".[]" | sort`

INSTANCE_TYPE_COUNT=`echo ${INSTANCES} | awk -F "," '{print NF-1}'`

if [ ${INSTANCE_TYPE_COUNT} -gt 0 ]; then
    AZ_W_INSTANCES=`echo ${AZ_W_INSTANCES} | tr ' ' '\n' | uniq -d`
fi
AZ_W_INSTANCES=`echo ${AZ_W_INSTANCES} | tr ' ' ',' | sed 's%,$%%g'`


if [[ -z $AZ_W_INSTANCES ]]; then
    echo "[ERROR] failed to retrieve availability zone"
    return 1
fi

AZ_COUNT=`echo $AZ_W_INSTANCES | tr -s ',' ' ' | wc -w`
export SUBNET_ID=`aws ec2 describe-subnets --query "Subnets[*].SubnetId" \
    --filters Name=vpc-id,Values=${VPC_ID} \
    Name=availability-zone,Values=${AZ_W_INSTANCES} \
    --region ${AWS_REGION} \
    | jq -r .[$(python3 -S -c "import random; print(random.randrange(${AZ_COUNT}))")]`

if [[ ! -z $SUBNET_ID ]]; then
    echo "[INFO] SUBNET_ID = ${SUBNET_ID}"
else
    echo "[ERROR] failed to retrieve SUBNET ID"
    return 1
fi

#Get AWS ParallelCluster Version
PCLUSTER_VERSION=`pcluster version | jq -r '.version'`

# Retrieve MPAS Image ID
export MPAS_AMI=`aws ec2 describe-images --owners self \
    --query 'Images[*].{ImageId:ImageId,CreationDate:CreationDate}' \
    --filters "Name=name,Values=*-amzn2-parallelcluster-${PCLUSTER_VERSION}-mpas-7.1-*" \
    --region ${AWS_REGION} \
    | jq -r 'sort_by(.CreationDate)[-1] | .ImageId'`

if [[ ! -z $MPAS_AMI && $MPAS_AMI != "null" ]]; then
    echo "[INFO] MPAS_AMI = ${MPAS_AMI}"
else
    echo "[ERROR] failed to retrieve MPAS AMI ID"
    return 1
fi

echo "[INFO] Create AWS ParallelCluster configuration file for MPAS"
# Change the cluster configuration file
PARALLELCLUSTER_CONFIG="${PARENT_PATH}/../../config/mpas-x86-64.yaml"

# Change the cluster configuration file
yq -i '.Region = strenv(AWS_REGION)' ${PARALLELCLUSTER_CONFIG}
yq -i '.Image.CustomAmi = strenv(MPAS_AMI)' ${PARALLELCLUSTER_CONFIG}
yq -i '.HeadNode.Ssh.KeyName = strenv(SSH_KEY_NAME)' ${PARALLELCLUSTER_CONFIG}
yq -i '.HeadNode.Networking.SubnetId = strenv(SUBNET_ID)' ${PARALLELCLUSTER_CONFIG}
yq -i '.Scheduling.SlurmQueues[0].Networking.SubnetIds[0] = strenv(SUBNET_ID)' ${PARALLELCLUSTER_CONFIG}

echo "[DONE] Created AWS ParallelCluster configuration file for MPAS"
