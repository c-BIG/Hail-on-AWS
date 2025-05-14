# Hail-on-AWS

Deploy an [EMR cluster on AWS](https://aws.amazon.com/emr/), with Spark, [Hail](https://hail.is/index.html) and [JupyterLab](https://jupyter.org/about.html) using [CloudFormation service](https://aws.amazon.com/cloudformation/).

\* Ensembl's Variant Effect Predictor (VEP) was not tested with the current stack.

## Requirements

* A valid AWS account with appropriate permissions
* A VPC, a subnet and a security group ready to ensure appropriate access to the cluster
* A S3 bucket to receive the data
* A github repository to store the notebooks
* A github account with write permission on the repository and a personal access token with full repo permissions.

## Create an AMI with Hail library

This needs to be done only one time. Following instructions from Wayne Toh, AWS specialist

\* Replace mention in bracket by the relevant resource from your account.

### Create an EC2

* Log into `AWS web console` / `EC2` service
* Click on `Launch instance`
* Fill the EC2 Name: `[NAME]`
* Select AMI: `Amazon Linux 2023 AMI`
* Select Architecture: `64-bit (Arm)`
* Select Instance type: `t4g.xlarge` (4CPU 16Gb)
* Select Key pair: `[PEM_KEY]`
* Select a VPC: `[VPC]`
* Select a Subnet: `[SUBMET]`
* Select Auto-assign public IP: `Enable`
* Select Firewall: `Select existing security group`
* Select a Common security groups: `[SG]`
* Set Configure Storage: 1x `50` Gib `gp3`
* Click on `Launch instance`

A message indicates:
> Successfully initiated launch of instance (i-###)

### Install Hail & dependencoes on the EC2

* Log into `AWS web console` / `EC2` service / `Instances` section / `Instances` sub-section
* Click on the instance created above: `i-###`
* Copy the Public IPv4 DNS: `[ec2-###.compute.amazonaws.com]`
* SSH to the EC2

  ```sh
  # Replace [EMRMasterDNS] below by the value of Public IPv4 DNS
  # Replace [path/to/key] below by the path to your PEM key
  # SSH on the master node (with tunnel)
  # * Hadoop                :8088
  # * Jupyter               :9443
  # * SparkUI               :18080
  MASTER=[EMRMasterDNS]; ssh -i [path/to/key].pem -L 8088:$MASTER:8088 -L 9443:$MASTER:9443 -L 18080:$MASTER:18080 hadoop@$MASTER
  ```

* Install dependencies: Execute the code displayed in [hail_install.sh](src/hail_install.sh). Note that it is advised to copy paste instructions line by line in the terminal to ensure smooth execution.
* Disconnect from the EC2

### Create an AMI

* Log into `AWS web console` / `EC2` service / `Instances` section / `Instances` sub-section
* Click on the instance created above: `i-###`
* Click on `Actions` / `Image and templates` / `Create image`
* Fill Image name: `[NAME]`
* Fill Image description: `[DESC]`
* Click on `Create image`

A message indicates:
> Currently creating AMI ami-### from instance i-###.

## Get the CloudFormation template available

This needs to be done only one time.

* Clone this repository

```sh
git clone git@github.com:c-BIG/Hail-on-AWS.git
```

* Copy the source files to a S3 bucket

```sh
# Replace [BUCKET] below by your personal bucket name
aws s3 sync src/ s3://[BUCKET]/Hail-on-AWS/
```

## Create an EMR Cluster

* Create a parameter file

Create a json file that define the cluster parameters. See example below.

/!\ DO NOT push on github this file as it contains credentials

```json
[
  {"ParameterKey": "OwnerTag", "ParameterValue": "[OWNER]"},
  {"ParameterKey": "KeyName", "ParameterValue": "[PEM_KEY]"},
  {"ParameterKey": "ProjectTag", "ParameterValue": "[PROJECT]"},
  {"ParameterKey": "EnvironmentTag", "ParameterValue": "prod"},
  {"ParameterKey": "DemandCPUCount", "ParameterValue": "10"},
  {"ParameterKey": "SpotCPUCount", "ParameterValue": "0"},
  {"ParameterKey": "DiskSizeGB", "ParameterValue": "65"},
  {"ParameterKey": "NotebooksAccount", "ParameterValue": "[GITHUB_ACCOUNT]"},
  {"ParameterKey": "NotebooksRepo", "ParameterValue": "[GITHUB_REPO]"},
  {"ParameterKey": "CFNBucket", "ParameterValue": "s3://[BUCKET]/Hail-on-AWS/src/"},
  {"ParameterKey": "EMRLogBucket", "ParameterValue": "s3n://[BUCKET]/EMR/"},
  {"ParameterKey": "EMRLogEncryptionKey", "ParameterValue": "arn:aws:kms:[REGION]:[ACCOUNT]:key/[KMS_ID]"},
  {"ParameterKey": "HailAMI", "ParameterValue": "ami-###"},
  {"ParameterKey": "NotebooksCreds", "ParameterValue": "[GITHUB_USER]:[GITHUB_TOKEN]"},
  {"ParameterKey": "Subnet", "ParameterValue": "[SUBNET]"},
  {"ParameterKey": "SecurityGroup", "ParameterValue": "[SG]"},
  {"ParameterKey": "NameTag", "ParameterValue": "emr-node"}
]
```

* Create a EMR cluster using CLI

  ```sh
  # Replace [BUCKET] below by your personal bucket name
  aws cloudformation create-stack \
  --stack-name hail-on-aws \
  --template-url https://s3.amazonaws.com/[BUCKET]/Hail-on-AWS/src/stack-hail.yml \
  --parameters file://.params.json
  ```

## Accessing the EMR cluster via Terminal

* Monitor cluster creation
  * Connect to `AWS Management Console` / `CloudFormation` service
  * Click on the stack created above: `hail-on-aws`
  * Navigate to `Events` tab
  * Wait and refresh the page until the status become `CREATE_COMPLETE`
* Get the MASTER node IP address
  * Click on `Outputs` tab
  * Copy `EMRMasterDNS` value
* SSH into the MASTER node

   ```sh
  # Replace [EMRMasterDNS] below by the value displayed in stack Outputs
  # Replace [path/to/key] below by the path to your PEM key
  # SSH on the master node (with tunnel)
  # * Hadoop                :8088
  # * Jupyter               :9443
  # * SparkUI               :18080
  MASTER=[EMRMasterDNS]; ssh -i [path/to/key].pem -L 8088:$MASTER:8088 -L 9443:$MASTER:9443 -L 18080:$MASTER:18080 hadoop@$MASTER
  ```

## Accessing the EMR cluster via Jupyter Lab

* SSH into the MASTER node (see above)
* Visit [Jupyter](https://localhost:9443/user/jovyan/lab)
* Create a new notebook with pyspak kernel
* Set spark driver memory

  ```py
  %%configure -f
  {
      "driverMemory": "45G"
  }
  ```

* Import and initialize Hail and SparkContext

```py
# Import and initialize Hail
import hail as hl
hl.init(sc)
```

## END
