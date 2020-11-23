#!/bin/bash

# Logs
exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1>>/tmp/cloudcreation_log.out 2>&1

echo '### INSTALL_VEP.SH ###'

# Default parameters
INSTALL="false"
OUTPUT_PATH=""
VEP_VERSION="95"
ASSEMBLY="GRCh38"
IMAGE="konradjk/vep95_loftee:0.2"
CACHE="homo_sapiens_merged"

# Read CLI script parameters
while [ $# -gt 0 ]; do
    case "$1" in
     --install)
      shift
      INSTALL=$1
      ;;
     --output-path)
      shift
      OUTPUT_PATH=$1
      ;;
    --vep-version)
      shift
      VEP_VERSION=$1
      ;;
    --cache)
      shift
      CACHE=$1
      ;;
    --assembly)
      shift
      ASSEMBLY=$1
      ;;
    --docker-image)
      shift
      IMAGE=$1
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

# Test if install needed
if [[ "$INSTALL" == "false" ]]; then
    echo "# VEP NOT INSTALLED #"
    echo '### END INSTALL_VEP.SH ###'
    exit 0
fi

# Test if output path exists
if [ -z "$OUTPUT_PATH" ]
then
  echo "OUTPUT_PATH Required !"
  echo '### END INSTALL_VEP.SH ###'
  exit 0
fi

echo '# Parameters #'
echo "OUTPUT_PATH: $OUTPUT_PATH"
echo "VEP_VERSION: $VEP_VERSION"
echo "CACHE: $CACHE"
echo "ASSEMBLY: $ASSEMBLY"
echo "IMAGE: $IMAGE"

echo '# Test if vep_data exists #'
echo "aws s3 ls ${OUTPUT_PATH}${CACHE}/${VEP_VERSION}_${ASSEMBLY}/ | grep info.txt | wc -c"
wc=`aws s3 ls ${OUTPUT_PATH}${CACHE}/${VEP_VERSION}_${ASSEMBLY}/ | grep info.txt | wc -c`
echo "word count = ${wc}"

if [ "${wc}" -eq 0 ]
then
  echo "vep data NOT FOUND for VEP v${VEP_VERSION} - ${CACHE} ${ASSEMBLY}"
#  exit 1
fi

echo '# Create directories #'
sudo mkdir -p /mnt/vep/vep_data/${CACHE}
sudo chmod -R a+rwx /mnt/vep
sudo chown -R hadoop:hadoop /mnt/vep

echo '# Download vep_data #'
sudo aws s3 sync ${OUTPUT_PATH}${CACHE}/ /mnt/vep/vep_data/${CACHE}/

echo '# Install Docker #'
sudo yum install docker -y
echo '# Setup Docker group #'
sudo usermod -aG docker hadoop
echo '# Start Docker #'
sudo systemctl start docker
echo '# Pull VEP image #'
sudo docker pull $IMAGE

echo '# Create VEP exec #'

export IMAGE=$IMAGE

sudo touch /vep.c 
sudo chmod 666 /vep.c

sudo cat >/vep.c <<EOF
#include <unistd.h>
#include <stdio.h>

int
main(int argc, char *const argv[]) {
  if (setuid(geteuid()))
    perror( "setuid" );

  execv("/vep.sh", argv);
  return 0;
}
EOF

sudo gcc -Wall -Werror -O2 /vep.c -o /vep
sudo chmod u+s /vep

sudo touch /vep.sh 
sudo chmod 666 /vep.sh
sudo cat >/vep.sh <<EOF
#!/bin/bash

docker run -i -v /mnt/vep/vep_data/:/opt/vep/.vep/:ro ${IMAGE} \
  /opt/vep/src/ensembl-vep/vep "\$@"
EOF

sudo chmod +x /vep.sh

echo '### END INSTALL_VEP.SH ###'
