# Packer AMIs Variables

The amis folder contains the packer scripts to a AWS Machine Image (AMI) of MPAS.
It is organized by Operating System (OS) with folder name convention such as `OS-pc-mpas`

Each OS folder has in their respective `variables.json` file that holds the same variables.

Here is a description of the variables and their default value:

| Name                       | Description                                      | Type    | Default          | Required |
| -------------------------- | ------------------------------------------------ | ------- | ---------------- | -------- |
| application\_name          | Application name                                 | String  | mpas             | no       |
| application\_version       | MPAS version                                     | String  | 7.1              | no       |
| aws\_region                | AWS Region where packer will create the instance | String  | us-east-1        | no       |
| company\_name              | Company Name used as AMI name prefix             | String  | None             | yes      |
| encrypt\_boot              | Encrypt snaphot and AMI                          | Boolean | False            | no       |
| env                        | AWS environment type: dev, stating, prod         | String  | dev              | no       |
| name                       | Name used as AMI name in the middle              | String  | \[OS\]-base      | no       |
| instance\_type             | EC2 instance type                                | String  | m5zn.3xlarge     | no       |
| intel\_serial\_number      | Intel license serial number                      | String  | None             | no       |
| parallel\_cluster\_version | ParallelCluster version to base AMI from         | String  | 3.4.1            | no       |
| public\_ip                 | Assign an elastic public IP                      | Boolean | True             | no       |
| ssh\_interface             | SSH interface either SSH or Session Manager      | String  | session\_manager | no       |
| state                      | AMI state: active, deprecated, obsolete          | String  | active           | no       |
