#!/bin/bash

# Find parent path
PARENT_PATH=$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )

if [ -z ${AWS_REGION} ]; then
    echo "[ERROR] AWS_REGION environment variable is not set"
    return 1
else
    echo "[INFO] AWS_REGION = ${AWS_REGION}"
fi

PARALLELCLUSTER_CONFIG="${PARENT_PATH}/../../config/mpas-x86-64.yaml"

SSH_KEY_NAME=`crudini --get ${PARALLELCLUSTER_CONFIG} "cluster default" key_name`

# Delete AWS Key pair
echo "[INFO] Deleting SSH Key Pair = ${SSH_KEY_NAME}"
aws ec2 delete-key-pair --key-name ${SSH_KEY_NAME} --region ${AWS_REGION}


# Delete MPAS Image(s) and associated snapshot(s)
MPAS_AMIS=$(aws ec2 describe-images --owners self --query 'Images[*].ImageId' --filters "Name=name,Values=*mpas*" --output text --region ${AWS_REGION})
echo "[INFO] Deleting MPAS AMIs = ${MPAS_AMIS}"
MPAS_SNAPSHOTS=$(aws ec2 describe-images --owners self --query 'Images[*].BlockDeviceMappings[0].Ebs.SnapshotId' --filters "Name=name,Values=*mpas*" --output text --region ${AWS_REGION})
for i in ${MPAS_AMIS}; do aws ec2 deregister-image --image-id ${i} --region ${AWS_REGION} ; done
for i in ${MPAS_SNAPSHOTS}; do aws ec2 delete-snapshot --snapshot-id ${i} --region ${AWS_REGION}; done
