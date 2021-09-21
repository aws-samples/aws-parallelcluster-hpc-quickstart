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

if [ -z ${AWS_REGION} ]; then
    echo "[ERROR] AWS_REGION environment variable is not set"
    return 1
else
    echo "[INFO] AWS_REGION = ${AWS_REGION}"
fi

PARALLELCLUSTER_CONFIG="${PARENT_PATH}/../../config/wrf-x86-64.ini"

SSH_KEY_NAME=`crudini --get ${PARALLELCLUSTER_CONFIG} "cluster default" key_name`

# Delete AWS Key pair
echo "[INFO] Deleting SSH Key Pair = ${SSH_KEY_NAME}"
aws ec2 delete-key-pair --key-name ${SSH_KEY_NAME} --region ${AWS_REGION}


# Delete WRF Image(s) and associated snapshot(s)
WRF_AMIS=$(aws ec2 describe-images --owners self --query 'Images[*].ImageId' --filters "Name=name,Values=*wrf*" --output text --region ${AWS_REGION})
echo "[INFO] Deleting WRF AMIs = ${WRF_AMIS}"
WRF_SNAPSHOTS=$(aws ec2 describe-images --owners self --query 'Images[*].BlockDeviceMappings[0].Ebs.SnapshotId' --filters "Name=name,Values=*wrf*" --output text --region ${AWS_REGION})
for i in ${WRF_AMIS}; do aws ec2 deregister-image --image-id ${i} --region ${AWS_REGION} ; done
for i in ${WRF_SNAPSHOTS}; do aws ec2 delete-snapshot --snapshot-id ${i} --region ${AWS_REGION}; done
