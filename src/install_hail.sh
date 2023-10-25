#!/bin/bash

# Logs
exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1>>/tmp/cloudcreation_log.out 2>&1

echo '### INSTALL_HAIL.SH v4.0.0 ###'

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

echo '### END INSTALL_HAIL.SH ###'
