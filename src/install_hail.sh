#!/bin/bash

# Logs
exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1>>/tmp/cloudcreation_log.out 2>&1

echo '### INSTALL_HAIL.SH v4.3.5 ###'

# Read CLI script parameters
while [ $# -gt 0 ]; do
    case "$1" in
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

if [ -z "$EMR_VERSION" ]
then
  echo "EMR_VERSION Required !"
  exit 0
fi

# Adjust for EMR version
if [ "${EMR_VERSION}" = "emr-5.31.0" ]
then
  HAIL_VERSION='0.2.60'
  PYTHON_VERSION='3.7'
  SPARK_VERSION='2.4.6'
  SCALA_VERSION='2.11.12'
  # sudo make install-on-cluster HAIL_COMPILE_NATIVES=1 SCALA_VERSION=2.11.12 SPARK_VERSION=2.4.6
elif [ "${EMR_VERSION}" = "emr-6.1.0" ]
then
  HAIL_VERSION='0.2.60'
  PYTHON_VERSION='3.7'
  SPARK_VERSION='3.0.0'
  SCALA_VERSION='2.12.10'
  # sudo make install-on-cluster HAIL_COMPILE_NATIVES=1 SCALA_VERSION=2.12.10 SPARK_VERSION=3.0.0
elif [ "${EMR_VERSION}" = "emr-6.9.1" ]
then
  HAIL_VERSION='0.2.124'
  PYTHON_VERSION='3.9'
  PYTHON_PATCH='18'
  SPARK_VERSION='3.3.0'
  SCALA_VERSION='2.12.15'
  # sudo make install-on-cluster HAIL_COMPILE_NATIVES=1 SCALA_VERSION=2.12.15 SPARK_VERSION=3.3.0
else
  echo "EMR version ${EMR_VERSION} not supported !"
  exit 0
fi

echo '# Parameters #'
echo "EMR_VERSION: $EMR_VERSION"
echo "HAIL_VERSION: $HAIL_VERSION"
echo "PYTHON_VERSION: $PYTHON_VERSION.$PYTHON_PATCH"
echo "SPARK_VERSION: $SPARK_VERSION"
echo "SCALA_VERSION: $SCALA_VERSION"

# python default to 3.7
if [ "${PYTHON_VERSION}" = "3.9" ]
then
  echo "# Update python to $PYTHON_VERSION.$PYTHON_PATCH #"
  # FROM https://repost.aws/questions/QUfxjbaGrXRTSKGy4-rnQ8Uw/how-to-upgrade-python-version-in-emr-since-python-3-7-support-discontinued
  sudo yum install libffi-devel -y
  sudo wget https://www.python.org/ftp/python/${PYTHON_VERSION}.${PYTHON_PATCH}/Python-${PYTHON_VERSION}.${PYTHON_PATCH}.tgz   
  sudo tar -zxvf Python-${PYTHON_VERSION}.${PYTHON_PATCH}.tgz
  cd Python-${PYTHON_VERSION}.${PYTHON_PATCH}
  sudo ./configure --enable-optimizations
  sudo make altinstall
  python3.9 -m pip install --upgrade awscli --user
  sudo ln -sf /usr/local/bin/python3.9 /usr/bin/python3

  # # Activate Python
  # sudo update-alternatives --install /usr/bin/python python /usr/local/python${PYTHON_VERSION}.${PYTHON_PATCH}/bin/python${PYTHON_VERSION} 10
  # # sudo mkdir /usr/local/lib/python${PYTHON_VERSION}/
  # # sudo ln -s /usr/local/python${PYTHON_VERSION}.${PYTHON_PATCH}/lib/python${PYTHON_VERSION}/site-packages /usr/local/lib/python${PYTHON_VERSION}/site-packages
fi

# PYTHON_PACKAGES="/usr/local/lib/python3.7/"

# echo '# Update system #'
# sudo yum update -y --skip-broken
# sudo python -m pip install --upgrade pip

# echo '# Install libs #'
# sudo yum install -y lz4 lz4-devel
# sudo yum install -y git

# echo '# Fix Java #'
# sudo ln -s /etc/alternatives/java_sdk/include /etc/alternatives/jre/include
# echo 3 | sudo alternatives --config java
# echo


# echo '# Clone Hail #'
# git clone --branch $HAIL_VERSION --depth 1 https://github.com/broadinstitute/hail.git

# echo '# Build Hail #'
# cd hail/hail/
# make install-on-cluster HAIL_COMPILE_NATIVES=1 SCALA_VERSION=${SCALA_VERSION} SPARK_VERSION=${SPARK_VERSION}

# echo '# Fix Hail #'
# sudo ln -s /usr/local/lib/python${PYTHON_VERSION}/site-packages/hail/backend /opt/hail/backend

echo '### END INSTALL_HAIL.SH ###'
