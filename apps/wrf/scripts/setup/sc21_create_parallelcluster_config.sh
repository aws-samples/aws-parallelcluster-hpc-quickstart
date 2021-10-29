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

# Define AWS Region
if [ -z ${AWS_REGION} ]; then
    echo "[ERROR] AWS_REGION environment variable is not set"
    return 1
else
    echo "[INFO] AWS_REGION = ${AWS_REGION}"
fi

# Define Instances seperated by ','.
if [ -z ${INSTANCES} ]; then
    echo "[ERROR] INSTANCES environment variable is not set. This variable defines the instance type for the head and compute node"
    return 1
else
    echo "[INFO] INSTANCES = ${INSTANCES}"
fi


# Create SSH Key
export SSH_KEY_NAME="hpc-lab-key"

[ ! -d ~/.ssh ] && mkdir -p ~/.ssh && chmod 700 ~/.ssh

SSH_KEY_EXIST=`aws ec2 describe-key-pairs --query KeyPairs[*] --filters Name=key-name,Values=${SSH_KEY_NAME} --region ${AWS_REGION} | jq "select(length > 0)"`

if [[ -z ${SSH_KEY_EXIST} ]]; then
    aws ec2 create-key-pair --key-name ${SSH_KEY_NAME} \
        --query KeyMaterial \
        --region ${AWS_REGION} \
        --output text > ~/.ssh/${SSH_KEY_NAME}

    chmod 400 ~/.ssh/${SSH_KEY_NAME}
    echo "${SSH_KEY_NAME}" >> env_vars
else
    echo "[WARNING] SSH_KEY_NAME ${SSH_KEY_NAME} already exist"
fi

echo "[INFO] SSH_KEY_NAME = ${SSH_KEY_NAME}"


# Retrieve VPC ID and Subnet ID
# By default, the script is looking for the default VPC and retrieve is ID.
# You can alternatively set to the VPC ID as an environment variable `VPC_ID` of your choice instead.
if [[ -z ${VPC_ID} ]]; then
    VPC_ID=`aws ec2 describe-vpcs --output text \
        --query 'Vpcs[*].VpcId' \
        --filters Name=isDefault,Values=true \
        --region ${AWS_REGION}`
fi

if [[ ! -z $VPC_ID ]]; then
    echo "${VPC_ID}" >> env_vars
    echo "[INFO] VPC_ID = ${VPC_ID}"
else
    echo "[ERROR] failed to retrieve VPC ID"
    return 1
fi


# Find in which Availability Zone Amazon EC2 instances are available.
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
    echo "[ERROR] failed to retrieve Availability Zone"
    return 1
fi

AZ_COUNT=`echo $AZ_W_INSTANCES | tr -s ',' ' ' | wc -w`

# Set a subnet id by finding which subnet of the VPC is corresponding to the Availability Zone
# where EC2 instance are available.
SUBNET_ID=`aws ec2 describe-subnets --query "Subnets[*].SubnetId" \
    --filters Name=vpc-id,Values=${VPC_ID} \
    Name=availability-zone,Values=${AZ_W_INSTANCES} \
    --region ${AWS_REGION} \
    | jq -r .[$(python3 -S -c "import random; print(random.randrange(${AZ_COUNT}))")]`

if [[ ! -z $SUBNET_ID ]]; then
    echo "${SUBNET_ID}" >> env_vars
    echo "[INFO] SUBNET_ID = ${SUBNET_ID}"
else
    echo "[ERROR] failed to retrieve SUBNET ID"
    return 1
fi
