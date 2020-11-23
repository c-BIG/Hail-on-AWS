#!/bin/bash

# Logs
exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1>>/tmp/cloudcreation_log.out 2>&1

echo '### INSTALL_ZEPPELIN.SH ###'

# Default parameters
ACCOUNT=""
REPO=""
TOKEN=""

# Read CLI script parameters
while [ $# -gt 0 ]; do
    case "$1" in
     --account)
      shift
      ACCOUNT=$1
      ;;
    --repo)
      shift
      REPO=$1
      ;;
    --token)
      shift
      TOKEN=$1
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

echo '# Parameters #'
echo "ACCOUNT: $ACCOUNT"
echo "REPO: $REPO"
echo "TOKEN: $TOKEN"

echo '# Update system #'
sudo yum update -y --skip-broken
sudo yum install -y python-pip
sudo python3 -m pip install --upgrade pip
sudo yum install -y git

echo '# Install dependencies #'
sudo python3 -m pip install bkzep

echo '# Clone notebooks'
sudo mkdir -p /opt/zeppelin
cd /opt/zeppelin
sudo git clone --depth 1 https://${ACCOUNT}:${TOKEN}@github.com/${REPO}.git .
sudo chmod -R 777 /opt/zeppelin/

echo '### END INSTALL_ZEPPELIN.SH ###'
