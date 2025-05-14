#!/bin/bash

# Logs
exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1>>/tmp/cloudcreation_log.out 2>&1

echo '### CONFIG_JUPYTER.SH v4.1.0 ###'

# Default parameters
BRANCH="master"
ACCOUNT=""
REPO=""
CREDS=""

# Read CLI script parameters
while [ $# -gt 0 ]; do
    case "$1" in
    --branch)
      shift
      BRANCH=$1
      ;;
    --account)
      shift
      ACCOUNT=$1
      ;;
    --repo)
      shift
      REPO=$1
      ;;
    --creds)
      shift
      CREDS=$1
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
echo "BRANCH: $BRANCH"
echo "ACCOUNT: $ACCOUNT"
echo "REPO: $REPO"
echo "CREDS: $CREDS"

# Test if install needed
if [[ -z "$ACCOUNT" ]]; then
    echo "# ACCOUNT NOT DEFINED #"
    echo '### SKIP CONFIG_JUPYTER.SH ###'
    exit 0
fi

sudo yum install -y git

# echo '# Install python libs #'
# sudo python3 -m pip install ipython
# sudo python3 -m pip install Jinja2==3.0.3
# Use matplotlib version compatible with numpy 1.16.5
# numpy version is fixed on EMR (after bootstrap)
# sudo python3 -m pip install matplotlib==3.4.3
# sudo python3 -m pip install seaborn
# sudo python3 -m pip install statsmodels
# sudo python3 -m pip install umap-learn
# sudo python3 -m pip install pycrypto

echo '# Install docker libs #'
sudo docker exec jupyterhub conda install -c conda-forge \
jupyterlab git jupyterlab-git ipympl

# echo '# Setup github #'
# sudo docker exec jupyterhub git config --global user.name ${USERNAME}
# sudo docker exec jupyterhub git config --global user.email ${EMAIL}

echo '# Test branch #'
lsr=`git ls-remote --heads https://${CREDS}@github.com/${ACCOUNT}/${REPO}.git ${BRANCH} | wc -l`
echo "ls-rempte = ${lsr}"

if [ "${lsr}" -eq 0 ]
then
  echo '# Clone main & create branch #'
  sudo docker exec jupyterhub \
  git clone --depth 1 https://${CREDS}@github.com/${ACCOUNT}/${REPO}.git

  sudo docker exec -w /home/jovyan/${REPO}/ jupyterhub \
  git checkout -b ${BRANCH}

else 
  echo '# Clone branch #'
  sudo docker exec jupyterhub \
  git clone --depth 1 --branch ${BRANCH} https://${CREDS}@github.com/${ACCOUNT}/${REPO}.git
fi

echo '# Change mode #'
sudo docker exec jupyterhub chmod -R 777 /home/jovyan/${REPO}/
sudo docker exec jupyterhub chown -R jovyan:users /home/jovyan/${REPO}/

echo '### END CONFIG_JUPYTER.SH ###'
