#!/bin/bash

clear
tput setaf 5
echo -e "\n*******************************************************************************************************************"
echo -e "Downloading the Velero Binary"
echo -e "*******************************************************************************************************************"
tput setaf 2
wget https://github.com/vmware-tanzu/velero/releases/download/v1.12.1/velero-v1.12.1-linux-amd64.tar.gz

tput setaf 5
echo -e "\n*******************************************************************************************************************"
echo -e "Extracting archive"
echo -e "*******************************************************************************************************************"
tput setaf 2
tar xvf velero-v1.12.1-linux-amd64.tar.gz

tput setaf 5
echo -e "\n*******************************************************************************************************************"
echo -e "Moving Velero binary to /usr/bin"
echo -e "*******************************************************************************************************************"
tput setaf 2
sudo mv velero-v1.12.1-linux-amd64/velero /usr/bin

tput setaf 5
echo -e "\n*******************************************************************************************************************"
echo -e "Removing extra files"
echo -e "*******************************************************************************************************************"
tput setaf 2
rm -rf velero-v1.12.1-linux-amd64

tput setaf 3
echo -e "\n*******************************************************************************************************************"
echo -e "Velero binary install complete, you should see the version below"
echo -e "*******************************************************************************************************************"
tput setaf 2
velero version

echo -e "\n\n"

