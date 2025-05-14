#!/bin/bash

# Disable ssm agent
sudo systemctl stop amazon-ssm-agent
sudo systemctl disable amazon-ssm-agent

# Install Java 11
sudo yum install -y java-11-amazon-corretto-devel
sudo update-alternatives --set java /usr/lib/jvm/java-11-amazon-corretto.aarch64/bin/java
sudo update-alternatives --set javac /usr/lib/jvm/java-11-amazon-corretto.aarch64/bin/javac

# Install Hail dependencies (yum)
sudo yum install -y python3-devel python3-pip git
sudo yum install -y lz4 lz4-devel openblas openblas-devel lapack lapack-devel

# Remove package in conflict with hail
sudo yum remove -y python3-requests

# Install Hail dependencies (pip)
sudo python3 -m pip install \
'ipython==7.34.0' \
'prompt-toolkit==3.0.38' \
'python-dateutil==2.8.2'

# Install hail on root
sudo python3 -m pip install 'hail==0.2.134'

# Re-install dependencies
sudo yum install -y cloud-init 
sudo yum install -y cloud-init-cfg-ec2
