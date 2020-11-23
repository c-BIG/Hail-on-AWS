# Hail-on-AWS

Deploy an [EMR cluster on AWS](https://aws.amazon.com/emr/), with Spark, [Hail](https://hail.is/index.html), [Zeppelin](https://zeppelin.apache.org/) and [Ensembl VEP](https://ensembl.org/info/docs/tools/vep/index.html) using [CloudFormation service](https://aws.amazon.com/cloudformation/).

## Prerequisites

* A valid AWS account with appropriate permissions
* A VPN, a subnet and a security group ready to ensure appropriate access to the cluster
* A S3 bucket to receive the data
* A github repository to store the zeppelin notebooks
* A github account with write permission on the repository and a personal access token with full repo permissions.

In addition you may want to install / be able to run Ensembl's Variant Effect Predictor (VEP) 
* A S3 bucket containining VEP cache data, see section [Install / enable Ensembl's Variant Effect Predictor (VEP)](#Install--enable-Ensembls-Variant-Effect-Predictor-VEP).

## Create a Spark/Hail/Zeppelin EMR using AWS CloudFormation service

* Clone this repository

```sh
git clone git@github.com:c-BIG/Hail-on-AWS.git
```

* Copy the source files to a S3 bucket

```sh
# Replace [Bucket] below by your personal bucket name
aws s3 sync src/ s3://[Bucket]/Hail-on-AWS/
```

* Connect to AWS Management Console and CloudFormation service

* Create a new stack using the template of this repo

* Set the parameters to fit your requirements and launch the Stack.

### CloudFormation template parameters

The template used below create a cluster with cheaper instance (AWS Spot instances). Note that if user require 0 CPU, a minimal cluster is created with 1 MASTER of 4 CPUs and 1 CORE of 4 CPUs, both instances been charged on demand. Additional spot instances are created when `SpotCPUCount > 0`

* Template URL: `https://s3.amazonaws.com/[Bucket]/Hail-on-AWS/hail_emr_spot.yml`
* Stack Name: `EMRCluster-hail-zep-vep`
* EMRClusterName `emr-cluster`
* EMRReleaseLabel `emr-6.1.0`
* EMRLogBucket `s3n://[Bucket]/EMR_logs/`
* Subnet `[Subnet]`
* SecurityGroup `[SecurityGroup]`
* KeyName `[Key]`
* InstanceType `r5`
* SpotCPUCount `4`
* DiskSizeGB `30`
* BidPercentage `45`
* GitHubAccount `[username]`
* GitHubRepository `[repo]`
* GitHubToken `[Personal access token]`
* CFNBucket `s3://[Bucket]/Hail-on-AWS/`
* HailVersion `0.2.59`
* VEPInstall: `false`
* VEPBucket: `s3://[Bucket]/Hail-on-AWS/vep_data/`
* VEPVersion `95`
* Assembly `GRCh38`
* NameTag `emr-node`
* OwnerTag `owner`
* ProjectTag `project`

## Accessing the AWS CloudFormation created Spark/Hail/Zeppelin EMR

### Connect to EMR master node (shell)

```sh
  # Replace [EMRMasterDNS] below by the value displayed in stack Outputs
  # Replace [path/to/key] below by the path to your EC2 Key .pem file
  # SSH on the master node (with tunnel)
  # * Hadoop                :8088
  # * Zeppelin              :8890
  # * SparkUI               :18080
  MASTER=[EMRMasterDNS]; ssh -i [path/to/key].pem -L 8088:$MASTER:8088 -L 8890:$MASTER:8890 -L 18080:$MASTER:18080 hadoop@$MASTER
 ```

### Accessing the EMR cluster via Zeppelin UI  
* Visit [Zeppelin](http://localhost:8890)
* Create a new note(book)
* Import and initialize Hail and SparkContext

```py
%pyspark
# Import and initialize Hail
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

### Commit changes to Zeppelin note(book)
  * in Zeppelin menu, click on **Version control**
  * Write a commit message and click on **Commit**
  * Click on **Ok**
* Save your work on github

```sh
%sh
cd /opt/zeppelin
git push origin master
```

## Install / enable Ensembl's Variant Effect Predictor (VEP) 
First we need to download VEP cache and store it on AWS. 
Be aware that for VEP v95 and GRCh38, the data represents ~25Gb. Set `DiskSizeGB` CloudFormation template parameter accordingly

### CloudFormation template parameters
* DiskSizeGB `100`
* VEPInstall: `true`
* VEPBucket: `s3://[Bucket]/Hail-on-AWS/vep_data/`
* VEPVersion `95`
* Assembly `GRCh38`

### Download VEP Docker image

```sh
sudo docker pull konradjk/vep95_loftee:0.2
```

### Create vep_data directory

```sh
sudo mkdir /mnt/vep/vep_data
sudo chmod a+rwx /mnt/vep/vep_data
```

### Download VEP (version 95, as used by gnomAD as of r3.1) cache

```sh
docker run -v /mnt/vep/vep_data:/opt/vep/.vep -w /opt/vep/src/ensembl-vep konradjk/vep95_loftee:0.2 perl INSTALL.pl -a cf -s homo_sapiens_merged -y GRCh38 -n
# - getting list of available cache files
# NB: Remember to use --merged when running the VEP with this cache!
# - downloading ftp://ftp.ensembl.org/pub/release-95/variation/VEP/homo_sapiens_merged_vep_95_GRCh38.tar.gz
# - unpacking homo_sapiens_merged_vep_95_GRCh38.tar.gz
# - converting cache, this may take some time but will allow VEP to look up variants and frequency data much faster
# - Processing homo_sapiens_merged
# - Processing version 95_GRCh38
# - Processing _var cache type
# (16145 files ~25G)
```

### Copy vep_data to S3 bucket referenced in the Cloudformation template

```sh
# Replace [Bucket] below with your personal bucket name
aws s3 cp /mnt/vep/vep_data//homo_sapiens_merged/ s3://[Bucket]/Hail-on-AWS/vep_data/homo_sapiens_merged/ --recursive
```

## END
