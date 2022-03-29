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

set -e

# Remove AWS temporary credentials
rm -vf $HOME/.aws/credentials

# Uninstall AWS CLI v1
echo "[INFO] Uninstalling AWS CLI version 1"

sudo rm -rf /usr/local/aws
sudo rm -f /usr/local/bin/aws

# Install AWS CLI v2
echo "[INFO] Installing AWS CLI version 2"

curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Install Packer

PACKER_VERSION="1.7.10"
PACKER_VERSION_SHA256SUM="1c8c176dd30f3b9ec3b418f8cb37822261ccebdaf0b01d9b8abf60213d1205cb"

echo "[INFO] Installing Packer"
curl -O https://releases.hashicorp.com/packer/${PACKER_VERSION}/packer_${PACKER_VERSION}_linux_amd64.zip
echo "${PACKER_VERSION_SHA256SUM}  packer_${PACKER_VERSION}_linux_amd64.zip" > checksum && sha256sum -c checksum
unzip packer_${PACKER_VERSION}_linux_amd64.zip
sudo unlink /usr/sbin/packer
sudo ln -s $PWD/packer /usr/sbin/packer


# Install Session Manager Plugin
echo "[INFO] Install Session Manager Plugin"
curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/linux_64bit/session-manager-plugin.rpm" -o "session-manager-plugin.rpm"
sudo yum install -y session-manager-plugin.rpm


# Install jq
echo "[INFO] Install jq"
sudo yum install -y jq


# Install yq
YQ_VERSION=4.21.1
sudo wget https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_amd64 -O /usr/bin/yq && sudo chmod +x /usr/bin/yq
