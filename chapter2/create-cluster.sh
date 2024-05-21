#!/bin/bash
clear

# Most of the coding segments in the book have been removed to make room for additional technical contact.  Scripts will now
# contain more documentation to help users understand what the scripts are executing.
tput setaf 3
echo -e "*******************************************************************************************************************"
echo -e "Creating KinD Cluster"
echo -e "*******************************************************************************************************************"

# Download the version of KinD that all exercises have been tested with - Any version of KinD other than v0.19.0 may not work
# with the exercies in the book due to breaking changes and compatibility with the Kubernetes versions.
tput setaf 5
echo -e "\n*******************************************************************************************************************"
echo -e "Downloading the KinD v0.22.0 Binary"
echo -e "All of the exercises in the book have been tested against KinD v0.22.0.  We cannot guarantee that the scripts will"
echo -e "will work on any other KinD release."
echo -e "*******************************************************************************************************************"
tput setaf 2
curl -Lo ./kind https://github.com/kubernetes-sigs/kind/releases/download/v0.22.0/kind-linux-amd64
chmod +x ./kind

tput setaf 5
echo -e "\n*******************************************************************************************************************"
echo -e "Moving the KinD Binary to /usr/bin"
echo -e "*******************************************************************************************************************"
tput setaf 2
sudo mv ./kind /usr/bin

tput setaf 3
echo -e "\n*******************************************************************************************************************"
echo -e "KinD installation complete"
echo -e "*******************************************************************************************************************"
tput setaf 2

tput setaf 5
# Install kubectli to interact with the KinD Cluster
echo -e "\n \n*******************************************************************************************************************"
echo -e "Install kubectl"
echo -e "*******************************************************************************************************************"
tput setaf 3
# Sudo snap install kubectl --classic
curl -LO https://storage.googleapis.com/kubernetes-release/release/`curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt`/bin/linux/amd64/kubectl
chmod +x ./kubectl
sudo mv ./kubectl /usr/local/bin/kubectl

tput setaf 5
# Install helmi and jq - We will use these in future chapters
echo -e "\n \n*******************************************************************************************************************"
echo -e "Installing Helm3 and jq"
echo -e "*******************************************************************************************************************"
tput setaf 3
# Get the official HELM downloder script
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh

sudo apt install snapd -y
sudo snap install jq  --classic

tput setaf 5
# Create KIND Cluster calle cluster01 using config cluster01-kind.yaml
# KinD will deploy a cluster using the v1.27.1 Image - This has been tested with all of the book exercises and any K8s version
# other than 1.30 may not work with all the book scripts due to any changes in K8s.
# Unofficially, the scripts have been tested against KinD running 1.28.x, 1.29.x, and 1.30.x images
# To change the K8s cluster version, comment the create cluster for the 1.30 image and uncomment the image you would like to use
# instead (ie: uncomment the line #kind create cluster --name cluster01 --config cluster01-kind.yaml --image kindest/node:v1.29.2)
echo -e "\n \n*******************************************************************************************************************"
echo -e "Create KinD Cluster using cluster01-kind.yaml configuration - Using the v.1.30.0 Image"
echo -e "*******************************************************************************************************************"
tput setaf 3
#Use a custom image for 1.30 until KinD releases the official 1.30.0 image
kind create cluster --name cluster01 --config cluster01-kind.yaml --image kindest/node:v1.30.0@sha256:047357ac0cfea04663786a612ba1eaba9702bef25227a794b52890dd8bcd692e
#Use the K8s 1.29.2 Image
#kind create cluster --name cluster01 --config cluster01-kind.yaml --image kindest/node:v1.29.2@sha256:51a1434a5397193442f0be2a297b488b6c919ce8a3931be0ce822606ea5ca245
#Use the K8s 1.28.0 Image
#kind create cluster --name cluster01 --config cluster01-kind.yaml --image kindest/node:v1.28.0@sha256:b7a4cad12c197af3ba43202d3efe03246b3f0793f162afb40a33c923952d5b31

# Add a label to the worker node, ingress-ready=true.  The NGINX deployment will only deploy to nodes that have this label.
tput setaf 5
echo -e "\n \n*******************************************************************************************************************"
echo -e "Adding node label for Ingress Controller to worker node"
echo -e "*******************************************************************************************************************"
tput setaf 3
kubectl label node cluster01-worker ingress-ready=true

# Install Calico
# The Calico scripts have been downloaded and added to the GIT repo to maintain the best release to use with KinD
# The only changes to the scripts is the POD CIDR range we use which needs to match the range in the custom-resoures.yaml manifest.
#     ipPools:
#    - blockSize: 26
#      cidr: 10.240.0.0/16
# Of this doesnt match the CIDR range of the KinD cluster, Calico will fail to start.

echo -e "\n \n*******************************************************************************************************************"
echo -e "Install Calico from local file, using 10.240.0.0/16 as the pod CIDR"
echo -e "*******************************************************************************************************************"
tput setaf 3
kubectl create -f calico/tigera-operator.yaml
kubectl create -f calico/custom-resources.yaml

# Deploy NGINX
# This is a standard nginx-deployment manifest that has been downloaded to the book repo to maintain compatibility with the KiND
# version we use for the book.  Newer releases may work, but there is no guarantee.
tput setaf 5
echo -e "\n \n*******************************************************************************************************************"
echo -e "Install NGINX Ingress Controller"
echo -e "*******************************************************************************************************************"
tput setaf 3
kubectl create -f nginx-ingress/nginx-deploy.yaml

# Find IP address of Docker Host
# We need to know the IP of the Host since we use nip.io for name resolution.  Nip.ip names follow the standard <url>.<host ip>.nip.io
# For example, if you wanted to have two Ingress rules, one for a sales web site and one for an ordering website, and your Host IP is 192.168.1.1
# your nip.io names would be sales.192.168.1.1.nip.io and ordering.192.168.1.1.nip.io
# This does assume that the first IP found is the correct IP address of the Host.  In a multi-homed system you may need to use a different
# IP address, but we have no easy way to know the correct IP to use if there are multiple IP addresses on a Host system.
tput setaf 3
hostip=$(hostname  -I | cut -f1 -d' ')
echo -e "\n \n*******************************************************************************************************************"
echo -e "Cluster Creation Complete.  Please see the summary below for key information that will be used in later chapters"
echo -e "*******************************************************************************************************************"

# Use the IP found in the previous step:
# Summarize the KinD deployment and show the user an example of a nip.io address that can be used for Ingress rules.
tput setaf 7
echo -e "\n \n*******************************************************************************************************************"
echo -e "Your Kind Cluster Information: \n"
echo -e "Ingress Domain: $hostip.nip.io \n"
echo -e "Ingress rules will need to use the IP address of your Linux Host in the Domain name \n"
echo -e "Example:  You have a web server you want to expose using a host called ordering."
echo -e "          Your ingress rule would use the hostname: ordering.$hostip.nip.io"
echo -e "******************************************************************************************************************* \n\n"

tput setaf 2
