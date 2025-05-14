#!/bin/bash

# Logs
exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1>>/tmp/cloudcreation_log.out 2>&1

echo '### CONFIG_CLUSTER v2.2.0 ###'

# Install Java 11
sudo update-alternatives --set java /usr/lib/jvm/java-11-amazon-corretto.aarch64/bin/java

sudo systemctl stop livy-server
# Increase Livy server memory
sudo sed -i 's|\$LIVY_SERVER_JAVA_OPTS |$LIVY_SERVER_JAVA_OPTS -Xmx16g |' /etc/livy/conf/livy-env.sh
# Force new line
sudo bash -c "echo ' ' >> /etc/livy/conf/livy-env.sh"
# Set Java home
sudo bash -c "echo 'export JAVA_HOME=/usr/lib/jvm/java-11-amazon-corretto.aarch64' >> /etc/livy/conf/livy-env.sh"
# Set python path
sudo bash -c "echo 'export PYSPARK_PYTHON=/usr/bin/python3' >> /etc/livy/conf/livy-env.sh"
sudo bash -c "echo 'export PYSPARK_DRIVER_PYTHON=/usr/bin/python3' >> /etc/livy/conf/livy-env.sh"

sudo systemctl start livy-server

echo '### END CONFIG_CLUSTER.SH ###'
