#!/bin/bash

# Logs
exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1>>/tmp/cloudcreation_log.out 2>&1

echo '### INSTALL_HAIL.SH ###'

# Default parameters
OUTPUT_PATH=""
HAIL_VERSION="0.2.60"
EMR_VERSION="emr-6.1.0"
PYTHON_PACKAGES="/usr/local/lib/python3.7/"

# Read CLI script parameters
while [ $# -gt 0 ]; do
    case "$1" in
    --output-path)
      shift
      OUTPUT_PATH=$1
      ;;
    --hail-version)
      shift
      HAIL_VERSION=$1
      ;;
      --emr-version)
      shift
      EMR_VERSION=$1
      ;;
    -*)
      error_msg "unrecognized option: $1"
      ;;
    *)
      break;
      ;;
    esac
    shift
done

if [ -z "$OUTPUT_PATH" ]
then
  echo "OUTPUT_PATH Required !"
  exit 0
fi

echo '# Parameters #'
echo "OUTPUT_PATH: $OUTPUT_PATH"
echo "HAIL_VERSION: $HAIL_VERSION"
echo "EMR_VERSION: $EMR_VERSION"
echo "PYTHON_PACKAGES: $PYTHON_PACKAGES"

echo '# Update system #'
sudo yum update -y --skip-broken
sudo yum install -y python-pip
sudo python3 -m pip install --upgrade pip

echo '# Install libs #'
sudo yum install -y lz4 lz4-devel
sudo yum install -y git

echo '# Test if hail exists #'
echo " aws s3 ls ${OUTPUT_PATH}${EMR_VERSION}/site-packages/| grep hail-${HAIL_VERSION}.dist-info | wc -c"
wc=`aws s3 ls ${OUTPUT_PATH}${EMR_VERSION}/site-packages/ | grep hail-${HAIL_VERSION}.dist-info | wc -c`
echo "word count = ${wc}"

if [ "${wc}" -eq 0 ]
then
  echo '# Clone Hail #'
  sudo mkdir -p /opt/broad-hail
  cd /opt/broad-hail
  sudo git clone --branch $HAIL_VERSION --depth 1 https://github.com/broadinstitute/hail.git .
  cd /opt/broad-hail/hail/

  echo '# Build Hail #'
  # Fix java
  sudo ln -s /etc/alternatives/java_sdk/include /etc/alternatives/jre/include

  # Adjust scala version
  if [ "${EMR_VERSION}" = "emr-5.31.0" ]
  then
    sudo make install-on-cluster HAIL_COMPILE_NATIVES=1 SCALA_VERSION=2.11.12 SPARK_VERSION=2.4.6
  elif [ "${EMR_VERSION}" = "emr-6.1.0" ]
  then
    sudo make install-on-cluster HAIL_COMPILE_NATIVES=1 SCALA_VERSION=2.12.10 SPARK_VERSION=3.0.0
  else
    echo "EMR version ${EMR_VERSION} not supported !"
    exit 0
  fi

  # Test if Hail already build by another node
  wc=`aws s3 ls ${OUTPUT_PATH}${EMR_VERSION}/site-packages/ | grep hail-${HAIL_VERSION}.dist-info | wc -c`
  if [ "${wc}" -eq 0 ]
  then
    echo '# Copy hail to S3'
    aws s3 sync ${PYTHON_PACKAGES}site-packages/hail/ ${OUTPUT_PATH}${EMR_VERSION}/site-packages/hail/
    aws s3 sync ${PYTHON_PACKAGES}site-packages/hailtop/ ${OUTPUT_PATH}${EMR_VERSION}/site-packages/hailtop/
    aws s3 sync ${PYTHON_PACKAGES}site-packages/hail-${HAIL_VERSION}.dist-info/ ${OUTPUT_PATH}${EMR_VERSION}/site-packages/hail-${HAIL_VERSION}.dist-info/
  fi
else
  echo '# Download hail #'
    sudo aws s3 sync ${OUTPUT_PATH}${EMR_VERSION}/site-packages/hail/ ${PYTHON_PACKAGES}site-packages/hail/
    sudo aws s3 sync ${OUTPUT_PATH}${EMR_VERSION}/site-packages/hailtop/ ${PYTHON_PACKAGES}site-packages/hailtop/
    sudo aws s3 sync ${OUTPUT_PATH}${EMR_VERSION}/site-packages/hail-${HAIL_VERSION}.dist-info/ ${PYTHON_PACKAGES}site-packages/hail-${HAIL_VERSION}.dist-info/
fi

echo '# Install hail dependencies #'
WHEELS="aiohttp>=3.6,<3.7
aiohttp-session<2.8,>=2.7
asyncinit<0.3,>=0.2.4
bkzep
bokeh>1.1,<1.3
decorator<5
Deprecated>=1.2.10,<1.3
dill<0.4,>=0.3.1.1
gcsfs==0.2.2
google-cloud-storage==1.25.*
humanize==1.0.0
hurry.filesize==0.9
nest-asyncio
parsimonious<0.9
pandas==0.25
PyJWT
pyspark>=2.4,<2.4.2
python-json-logger==0.1.11
requests==2.22.0
scipy==1.3
tabulate==0.8.3
tqdm==4.42.1"

for WHEEL_NAME in $WHEELS
do
  sudo python3 -m pip install $WHEEL_NAME
done

echo '### END INSTALL_HAIL.SH ###'
