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

# Find parent path
PARENT_PATH=$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )


# Define AWS Region
if [ -z ${AWS_REGION} ]; then
    echo "[ERROR] AWS_REGION environment variable is not set"
    return 1
else
    echo "[INFO] AWS_REGION = ${AWS_REGION}"
    echo "export AWS_REGION=${AWS_REGION}" >> ~/.bashrc
fi

# Define Instances seperated by ','
export INSTANCES="p4de.24xlarge"


# Create SSH Key
export SSH_KEY_NAME="barracuda-ssh-key"
echo "export SSH_KEY_NAME=${SSH_KEY_NAME}" >> ~/.bashrc

[ ! -d ~/.ssh ] && mkdir -p ~/.ssh && chmod 700 ~/.ssh

SSH_KEY_EXIST=`aws ec2 describe-key-pairs --query KeyPairs[*] --filters Name=key-name,Values=${SSH_KEY_NAME} --region ${AWS_REGION} | jq "select(length > 0)"`

if [[ -z ${SSH_KEY_EXIST} ]]; then
    KEY_INFO=`aws ec2 create-key-pair --key-name ${SSH_KEY_NAME} \
        --key-type ed25519 \
        --region ${AWS_REGION} \
        --output json`

    KEY_PAIR=`echo $KEY_INFO | jq -r .KeyMaterial`
    echo "${KEY_PAIR}" > ~/.ssh/${SSH_KEY_NAME}
    chmod 400 ~/.ssh/${SSH_KEY_NAME}

    KEY_PAIR_ID=`echo $KEY_INFO | jq -r .KeyPairId`
    aws ssm put-parameter --name /ec2/keypair/${KEY_PAIR_ID} \
        --value "${KEY_PAIR}" \
        --type SecureString \
        --tier Standard \
        --data-type text \
        --region ${AWS_REGION}
else
    echo "[WARNING] SSH_KEY_NAME ${SSH_KEY_NAME} already exist"
    echo "[WARNING] Retrieving ${SSH_KEY_NAME} from Parameter Store"
    KEY_PAIR_ID=`aws ec2 describe-key-pairs --query KeyPairs[0].KeyPairId \
    --filters Name=key-name,Values=${SSH_KEY_NAME} \
    --output text \
    --region ${AWS_REGION}`

    chmod 700 ~/.ssh/${SSH_KEY_NAME}
    aws ssm get-parameter --name /ec2/keypair/${KEY_PAIR_ID} \
        --with-decryption \
        --query Parameter.Value \
        --output text \
        --region ${AWS_REGION} \
        > ~/.ssh/${SSH_KEY_NAME}
    chmod 400 ~/.ssh/${SSH_KEY_NAME}
fi

echo "[INFO] SSH_KEY_NAME = ${SSH_KEY_NAME}"


# Retrieve VPC ID and Subnet ID
# You can alternatively set to the VPC ID of your choice insteasd of the default VPC
if [[ -z ${VPC_ID} ]]; then
   export  VPC_ID=`aws ec2 describe-vpcs --output text \
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


export SUBNET_ID=`aws ec2 describe-subnets --query "Subnets[*].SubnetId" \
    --filters Name=vpc-id,Values=${VPC_ID} \
    --region ${AWS_REGION} \
    | jq -r .[]`

if [[ ! -z $SUBNET_ID ]]; then
    echo "[INFO] SUBNET_ID = ${SUBNET_ID}"
else
    echo "[ERROR] failed to retrieve SUBNET ID"
    return 1
fi


export SUBNET_ID_HEADNODE=`echo ${SUBNET_ID} | awk '{print $1}'`

echo "[INFO] Create AWS ParallelCluster configuration file for Barracuda Cluster"
# Change the cluster configuration file
PARALLELCLUSTER_CONFIG="${PARENT_PATH}/../../config/barracuda-cluster.yaml"

yq -i '.Region = strenv(AWS_REGION)' ${PARALLELCLUSTER_CONFIG}
yq -i '.HeadNode.Ssh.KeyName = strenv(SSH_KEY_NAME)' ${PARALLELCLUSTER_CONFIG}
yq -i '.HeadNode.Networking.SubnetId = strenv(SUBNET_ID_HEADNODE)' ${PARALLELCLUSTER_CONFIG}

it=0
for i in $SUBNET_ID
do
    export TMP_SUB=${i}
    export TMP_IT=${it}
    yq -i '.Scheduling.SlurmQueues[0].Networking.SubnetIds[strenv(TMP_IT)] = strenv(TMP_SUB)' ${PARALLELCLUSTER_CONFIG}
   it=$(( $it + 1 ))
done

echo "[DONE] Created AWS ParallelCluster configuration file for Barracuda Cluster"
