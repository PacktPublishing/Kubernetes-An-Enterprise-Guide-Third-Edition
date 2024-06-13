#!/bin/bash
clear

# Install apparmor utilites in the kind cluster nodes
# Special thanks to Rahul Jadhav from Accuknox for the assistance on the requirements to enable Kubearmor on KinD
tput setaf 5
echo -e "\n \n*******************************************************************************************************************"
echo -e "Downloading karmor release from get.kubearmor.io and moving it to /usr/bin"
echo -e "*******************************************************************************************************************"
tput setaf 3
./get-kubearmor-bin.sh v1.2.2
sudo mv ./bin/karmor /usr/bin

tput setaf 5
echo -e "\n \n*******************************************************************************************************************"
echo -e "Updating APT and Installing the apparmor-utils package on the Nodes"
echo -e "*******************************************************************************************************************"
tput setaf 3
docker exec -it cluster01-worker bash -c "apt update && apt install apparmor-utils -y && systemctl restart containerd && systemctl start apparmor"
docker exec -it cluster01-control-plane bash -c "apt update && apt install apparmor-utils -y && systemctl restart containerd && systemctl start apparmor"

# Add calico-typha to Apparmor unconfined mode
tput setaf 5
echo -e "\n \n*******************************************************************************************************************"
echo -e "Patching the Calico deployment to work with KinD and Kubearmor"
echo -e "*******************************************************************************************************************"
tput setaf 3
kubectl patch deploy -n calico-system calico-typha --type=json -p='[{"op": "add", "path": "/spec/template/metadata/annotations/container.apparmor.security.beta.kubernetes.io~1calico-typha", "value": "unconfined"}]'

# Install Kubearmor using the karmor utility
tput setaf 5
echo -e "\n \n*******************************************************************************************************************"
echo -e "Install Kubearmor"
echo -e "*******************************************************************************************************************"
tput setaf 3
kubectl create ns kubearmor
karmor install -n kubearmor
sleep 10

# Add Kubearmor-relay to Apparmor unconfined mode 
# This is required for kubearmor-relay to function in a KinD cluster - this is not required for standard K8s clusters
tput setaf 5
echo -e "\n \n*******************************************************************************************************************"
echo -e "Patching the kubearmor-relay Deployment - Apparmor unconfined mode"
echo -e "*******************************************************************************************************************"
tput setaf 3
kubectl patch deploy -n $(kubectl get deploy -l kubearmor-app=kubearmor-relay -A -o custom-columns=:'{.metadata.namespace}',:'{.metadata.name}') --type=json -p='[{"op": "add", "path": "/spec/template/metadata/annotations/container.apparmor.security.beta.kubernetes.io~1kubearmor-relay-server", "value": "unconfined"}]'

# To enable logging we need to add two environment variables to enable STDOUT logging for Kubearmor policies
tput setaf 5
echo -e "\n \n*******************************************************************************************************************"
echo -e "Patching the kubearmor-relay Deployment to enable Logging"
echo -e "*******************************************************************************************************************"
tput setaf 3
kubectl patch deploy kubearmor-relay -n kubearmor --patch-file patch-relay.yaml

tput setaf 7
echo -e "\n \n*******************************************************************************************************************"
echo -e "Kubearmor deployment complete - It will take a few minutes for the pods to restart for some workloads"
echo -e "Patching some deployments is required due to the K8s nodes running in containers and sharing a kernel"
echo -e "This is not required when using standard nodes running on VMs / Physical Servers"
echo -e "*******************************************************************************************************************\n\n"
tput setaf 2

