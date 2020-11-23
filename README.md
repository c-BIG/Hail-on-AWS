# Hail-on-AWS

Deploy an EMR cluster on AWS, with Spark, Hail, Zeppelin and Ensembl VEP using CloudFormation service.

## Quick Start

### Prerequise

* VEP cache data and fasta for Human are store in a S3 bucket (unpacked homo_sapiens_merged_vep_95_GRCh38.tar.gz) see [documentation](https://github.com/c-BIG/Hail-AWS-CloudFormation/wiki/Documentation#prepare-vep-data)
* A valid AWS account with appropriate permissions
* A VPN, a subnet and a security group ready to ensure appropriate access to the cluster
* A S3 bucket to receive the data
* A github repository to store the zeppelin notebooks
* A github account with write permission on the repository and a personal access token with full repo permissions.

### Launch Cluster

* Clone this repository

```sh
git clone git@github.com:c-BIG/Hail-AWS-CloudFormation.git
```

* Copy the source files to a S3 bucket

```sh
# Replace [Bucket] below by your personal bucket name
aws s3 sync src/ s3://[Bucket]/Hail-AWS-CloudFormation/
```

* Connect to AWS Management Console and CloudFormation service

* Create a new stack using the template of this repo

* Set the parameters to fit your requirements and launch the Stack.

### Spot instances

The template used below create a cluster with cheaper instance (AWS Spot instances). Note that if user require 0 CPU, a minimal cluster is created with 1 MASTER of 4 CPUs and 1 CORE of 4 CPUs, both instances been charged on demand. Additional spot instances are created when `SpotCPUCount > 0`

* Template URL: `https://s3.amazonaws.com/[Bucket]/Hail-AWS-CloudFormation/hail_emr_spot.yml`
* Stack Name: `EMRCluster-zep-hail-zep-vep`
* EMRClusterName `emr-cluster`
* EMRReleaseLabel `emr-6.1.0`
* EMRLogBucket `s3n://[Bucket]/EMR_logs/`
* Subnet `[Subnet]`
* SecurityGroup `[SecurityGroup]`
* KeyName `[Key]`
* InstanceType `r5`
* SpotCPUCount `4`
* DiskSizeGB `100`
* BidPercentage `45`
* GitHubAccount `[username]`
* GitHubRepository `[repo]`
* GitHubToken `[Personal access token]`
* CFNBucket `s3://[Bucket]/Hail-AWS-CloudFormation/`
* HailVersion `0.2.59`
* VEPInstall: `false`
* VEPBucket: `s3://[Bucket]/Hail-AWS-CloudFormation/vep_data/`
* VEPVersion `95`
* Assembly `GRCh38`
* NameTag `emr-node`
* OwnerTag `owner`
* ProjectTag `project`

### Use Cluster

* Connect to EMR master node

```sh
  # Replace [EMRMasterDNS] below by the value displayed in stack Outputs
  # Replace [path/to/key] below by the path to your EC2 Key .pem file
  # SSH on the master node (with tunnel)
  # * Hadoop                :8088
  # * Zeppelin              :8890
  # * SparkUI               :18080
  MASTER=[EMRMasterDNS]; ssh -i [path/to/key].pem -L 8088:$MASTER:8088 -L 8890:$MASTER:8890 -L 18080:$MASTER:18080 hadoop@$MASTER
 ```

* Visite [Zeppelin](http://localhost:8890)
* Create a new note
* Launch Hail

```py
%pyspark
# Import and launch Hail
import hail as hl
hl.init(sc)
```

* Import Bokehjs

```py
%pyspark
# Import bokeh
from bokeh.io import show, output_notebook
from bokeh.plotting import figure
# Import bokeh-zeppelin
import bkzep
output_notebook(notebook_type='zeppelin')
```

* Commit your changes
  * in Zeppelin menu, click on **Version control**
  * Write a commit message and click on **Commit**
  * Click on **Ok**
* Save your work on github

```sh
%sh
cd /opt/zeppelin
git push origin master
```

## END
