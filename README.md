# Hail-on-AWS

Deploy an [EMR cluster on AWS](https://aws.amazon.com/emr/), with Spark, [Hail](https://hail.is/index.html), [Zeppelin](https://zeppelin.apache.org/) and [Ensembl VEP](https://ensembl.org/info/docs/tools/vep/index.html) using [CloudFormation service](https://aws.amazon.com/cloudformation/).

## Requirements

* A valid AWS account with appropriate permissions
* A VPC, a subnet and a security group ready to ensure appropriate access to the cluster
* A S3 bucket to receive the data
* A github repository to store the zeppelin notebooks
* A github account with write permission on the repository and a personal access token with full repo permissions.

In addition you may want to install / be able to run Ensembl's Variant Effect Predictor (VEP)

* A S3 bucket containining VEP cache data, see section [Install Ensembl's Variant Effect Predictor (VEP)](#install-ensembls-variant-effect-predictor-vep).

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

* Connect to AWS Management Console
* Navigate to CloudFormation service
* Create a new stack using the template of this repo
* Set the parameters to fit your requirements and launch the Stack.

### CloudFormation template parameters

The template used below create a cluster with cheaper instance (AWS Spot instances). Note that if user require 0 CPU, a minimal cluster is created with 1 MASTER of 4 CPUs and 1 CORE of 4 CPUs, both instances been charged on demand. Additional spot instances are created when `SpotCPUCount > 4`

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
* HailVersion `0.2.60`
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

## Install Ensembl's Variant Effect Predictor (VEP)

First we need to download VEP cache and store it on AWS.
Be aware that the data represents ~25Gb.
Set `DiskSizeGB` CloudFormation template parameter accordingly

### Re-connect to EMR master node (shell)

```sh
  # Replace [EMRMasterDNS] below by the value displayed in stack Outputs
  # Replace [path/to/key] below by the path to your EC2 Key .pem file
  # SSH on the master node (with tunnel)
  # * Hadoop                :8088
  # * Zeppelin              :8890
  # * SparkUI               :18080
  MASTER=[EMRMasterDNS]; ssh -i [path/to/key].pem -L 8088:$MASTER:8088 -L 8890:$MASTER:8890 -L 18080:$MASTER:18080 hadoop@$MASTER
```

### Download VEP Docker image

```sh
# For VEP92, replace [image] below by 'owjl/vep92_loftee:latest'
# For VEP95, replace [image] below by 'konradjk/vep95_loftee:0.2'
IMAGE=[image]; sudo docker pull $IMAGE
```

### Create vep_data directory

```sh
sudo mkdir /mnt/vep/vep_data
sudo chmod a+rwx /mnt/vep/vep_data
```

### Download VEP cache

```sh
# Replace [assembly] below by 'GRCh37' or GRCh38'
ASSEMBLY=[assembly]
docker run -v /mnt/vep/vep_data:/opt/vep/.vep -w /opt/vep/src/ensembl-vep $IMAGE perl INSTALL.pl -a cf -s homo_sapiens_merged -y $ASSEMBLY -n
```

### Copy vep_data to S3 bucket referenced in the Cloudformation template

```sh
# Replace [Bucket] below with your personal bucket name
aws s3 cp /mnt/vep/vep_data//homo_sapiens_merged/ s3://[Bucket]/Hail-on-AWS/vep_data/homo_sapiens_merged/ --recursive
```

### CloudFormation template parameters (VEP)

Now we can create a cluster with VEP installed by default

* DiskSizeGB: `50`
* VEPInstall: `true`
* VEPBucket: `s3://[Bucket]/Hail-on-AWS/vep_data/`
* VEPVersion: `95`
* Assembly: `GRCh38`

### Run VEP on your data

```py
# Load sites
# Replace [Path/to/table] below by the path of the hail table you wish to annotate
ht = hl.read_table('s3://[Path/to/table].ht')
# Filter out * alleles (not allowed by VEP)
ht_nostar = ht.filter((ht.alleles[0] != '*') & (ht.alleles[1] != '*'))
# Add VEP fields
# Replace [Bucket] below with your personal bucket name
# Replace [VEPVersion] below by the value of the template parameters
# Replace [Assembly] below by the value of the template parameters
ht_vep = hl.vep(ht_nostar, 's3://[Bucket]/Hail-on-AWS/vep_data/vep[VEPVersion]_[Assembly]_config.json')
# Write table
ht.write('s3://[Path/to/table].vep.ht', overwrite=True)
```

## Export to Elasticsearch

In Hail v0.2.60, the function `hl.export_elasticsearch` is not compatible with scala v2.12.x that is included in emr-6.x. Hail team is actively working on that issue, see [#9767](https://github.com/hail-is/hail/issues/9767)

In the mean time we can deploy Hail on emr-5.x that includes scala v2.11.x where `hl.export_elasticsearch` works.

Note that emr-6.x and emr-5.x includes different version of zeppelin (v0.8 vs v0.9) with incompatibility. Therefore the notebooks created on one emr version will not appears on the other emr version that.

### CloudFormation template parameters (elasticsearch)

* EMRReleaseLabel: `emr-5.31.0`

## END
