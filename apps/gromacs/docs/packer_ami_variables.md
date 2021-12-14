# Packer AMIs Variables

The amis folder contains the packer scripts to a AWS Machine Image (AMI) of LAMMPS.
It is organized by Operating System (OS) with folder name convention such as `OS-pc-lammps`

Each OS folder has in their respective `variables.json` file that holds the same variables.

Here is a description of the variables and their default value:

| Name                       | Description                                      | Type    | Default                | Required |
| -------------------------- | ------------------------------------------------ | ------- | ---------------------- | -------- |
| application\_name          | Application name                                 | String  | lammps                 | no       |
| application\_version       | LAMMPS version                                   | String  | stable\_29Oct2020      | no       |
| aws\_region                | AWS Region where packer will create the instance | String  | us-east-2              | no       |
| company\_name              | Company Name used as AMI name prefix             | String  | None                   | yes      |
| encrypt\_boot              | Encrypt snaphot and AMI                          | Boolean | False                  | no       |
| env                        | AWS environment type: dev, staging, prod         | String  | dev                    | no       |
| name                       | Name used as AMI name in the middle              | String  | \[OS\]-parallelcluster | no       |
| instance\_type             | EC2 instance type                                | String  | m5zn.3xlarge           | no       |
| intel\_serial\_number      | Intel license serial number                      | String  | None                   | no       |
| parallel\_cluster\_version | ParallelCluster version to base AMI from         | String  | 2.11.3                 | no       |
| public\_ip                 | Assign an elastic public IP                      | Boolean | True                   | no       |
| ssh\_interface             | SSH interface either SSH or Session Manager      | String  | session\_manager       | no       |
| state                      | AMI state: active, deprecated, obsolete          | String  | active                 | no       |
