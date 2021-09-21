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
fi

# Define Instances seperated by ','
export INSTANCES="c5n.18xlarge"


# Create a bucket that hosts the input data and will hydrate the AWS FSx for Lustre file system
BUCKET_POSTFIX=$(python3 -S -c "import uuid; print(str(uuid.uuid4().hex)[:10])")
BUCKET_NAME_DATA="parallelcluster-lammps-data-${BUCKET_POSTFIX}"

echo "[INFO] Creating logs for S3 bucket for LAMMPS test data"
BUCKET_NAME_DATA_LOGS="${BUCKET_NAME_DATA}-logs"

aws s3 mb s3://${BUCKET_NAME_DATA_LOGS} --region ${AWS_REGION}
aws s3api put-bucket-encryption --bucket ${BUCKET_NAME_DATA_LOGS}  --server-side-encryption-configuration '{"Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]}' --region ${AWS_REGION}
aws s3api put-public-access-block --bucket ${BUCKET_NAME_DATA_LOGS} --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" --region ${AWS_REGION}
aws s3api put-bucket-policy --bucket ${BUCKET_NAME_DATA_LOGS} --policy '{"Version": "2012-10-17","Statement": [{"Sid": "AllowSSLRequestsOnly","Action": "s3:*","Effect": "Deny","Resource": ["arn:aws:s3:::'$BUCKET_NAME_DATA_LOGS'","arn:aws:s3:::'$BUCKET_NAME_DATA_LOGS'/*"],"Condition": {"Bool": {"aws:SecureTransport": "false"}},"Principal": "*"}]}' --region ${AWS_REGION}
aws s3api put-bucket-acl --bucket ${BUCKET_NAME_DATA_LOGS} --grant-write URI=http://acs.amazonaws.com/groups/s3/LogDelivery --grant-read-acp URI=http://acs.amazonaws.com/groups/s3/LogDelivery --region ${AWS_REGION}
echo "[INFO] Created logs for S3 bucket for LAMMPS test data = ${BUCKET_NAME_DATA_LOGS}"


echo "[INFO] Creating S3 bucket for LAMMPS test data"
aws s3 mb s3://${BUCKET_NAME_DATA} --region ${AWS_REGION}
aws s3api put-bucket-encryption --bucket ${BUCKET_NAME_DATA}  --server-side-encryption-configuration '{"Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]}' --region ${AWS_REGION}
aws s3api put-public-access-block --bucket ${BUCKET_NAME_DATA} --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" --region ${AWS_REGION}
aws s3api put-bucket-policy --bucket ${BUCKET_NAME_DATA} --policy '{"Version": "2012-10-17","Statement": [{"Sid": "AllowSSLRequestsOnly","Action": "s3:*","Effect": "Deny","Resource": ["arn:aws:s3:::'$BUCKET_NAME_DATA'","arn:aws:s3:::'$BUCKET_NAME_DATA'/*"],"Condition": {"Bool": {"aws:SecureTransport": "false"}},"Principal": "*"}]}' --region ${AWS_REGION}
aws s3api put-bucket-logging --bucket ${BUCKET_NAME_DATA} --bucket-logging-status '{"LoggingEnabled": {"TargetBucket": "'$BUCKET_NAME_DATA_LOGS'", "TargetPrefix": "'$BUCKET_NAME_DATA'/"}}' --region ${AWS_REGION}
aws s3api put-object --bucket ${BUCKET_NAME_DATA} --key performance/ --metadata '{"file-group":"1000", "file-owner":"1000","file-permissions": "0100775"}'  --region ${AWS_REGION}
aws s3 cp ${PARENT_PATH}/../../performance s3://${BUCKET_NAME_DATA}/performance/  --recursive --metadata '{"file-group":"1000", "file-owner":"1000", "file-permissions": "0100664"}' --region ${AWS_REGION}
echo "[INFO] Created S3 bucket for LAMMPS test data = ${BUCKET_NAME_DATA}"


# Create SSH Key
export SSH_KEY_NAME="lammps-ssh-key"

[ ! -d ~/.ssh ] && mkdir -p ~/.ssh && chmod 700 ~/.ssh

SSH_KEY_EXIST=`aws ec2 describe-key-pairs --query KeyPairs[*] --filters Name=key-name,Values=${SSH_KEY_NAME} --region ${AWS_REGION} | jq "select(length > 0)"`

if [[ -z ${SSH_KEY_EXIST} ]]; then
    aws ec2 create-key-pair --key-name ${SSH_KEY_NAME} \
        --query KeyMaterial \
        --region ${AWS_REGION} \
        --output text > ~/.ssh/${SSH_KEY_NAME}

    chmod 400 ~/.ssh/${SSH_KEY_NAME}
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
SUBNET_ID=`aws ec2 describe-subnets --query "Subnets[*].SubnetId" \
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


# Retrieve LAMMPS Image ID
LAMMPS_AMI=`aws ec2 describe-images --owners self \
    --query 'Images[*].{ImageId:ImageId,CreationDate:CreationDate}' \
    --filters "Name=name,Values=*-amzn2-parallelcluster-2.10.4-lammps-*" \
    --region ${AWS_REGION} \
    | jq -r 'sort_by(.CreationDate)[-1] | .ImageId'`

if [[ ! -z $LAMMPS_AMI && $LAMMPS_AMI != "null" ]]; then
    echo "[INFO] LAMMPS_AMI = ${LAMMPS_AMI}"
else
    echo "[ERROR] failed to retrieve LAMMPS AMI ID"
    return 1
fi


# Clone crudini repository
[ ! -d crudini ] && git clone https://github.com/pixelb/crudini


# Install crudini
cd crudini && pip3 install -e . && cd ..


echo "[INFO] Create AWS ParallelCluster configuration file for LAMMPS"
# Change the cluster configuration file
PARALLELCLUSTER_CONFIG="${PARENT_PATH}/../../config/lammps-x86-64.ini"

crudini --set ${PARALLELCLUSTER_CONFIG} "aws" aws_region_name "${AWS_REGION}"
crudini --set ${PARALLELCLUSTER_CONFIG} "vpc public" vpc_id "${VPC_ID}"
crudini --set ${PARALLELCLUSTER_CONFIG} "vpc public" master_subnet_id "${SUBNET_ID}"
crudini --set ${PARALLELCLUSTER_CONFIG} "cluster default" key_name "${SSH_KEY_NAME}"
crudini --set ${PARALLELCLUSTER_CONFIG} "cluster default" custom_ami "${LAMMPS_AMI}"
crudini --set ${PARALLELCLUSTER_CONFIG} "fsx parallel-fs" import_path "s3://${BUCKET_NAME_DATA}"

echo "[DONE] Created AWS ParallelCluster configuration file for LAMMPS"
