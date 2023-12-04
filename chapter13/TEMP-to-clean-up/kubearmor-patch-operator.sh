#!/bin/bash
clear

# Install apparmor utilites in the kind cluster nodes
# Special thanks to Rahul Jadhav from Accuknox for the assistance on the requirements to enable Kubearmor on KinD
tput setaf 5
echo -e "\n \n*******************************************************************************************************************"
echo -e "Downloading the latest karmor release from get.kubearmor.io"
echo -e "*******************************************************************************************************************"
tput setaf 3
curl -sfL http://get.kubearmor.io/ | sudo sh -s -- -b /usr/local/bin

tput setaf 5
echo -e "\n \n*******************************************************************************************************************"
echo -e "Updating APT and Installing the apparmor-utils package on the Nodes"
echo -e "*******************************************************************************************************************"
tput setaf 3
docker exec -it cluster01-worker bash -c "apt update && apt install apparmor-utils -y && systemctl restart containerd"
docker exec -it cluster01-control-plane bash -c "apt update && apt install apparmor-utils -y && systemctl restart containerd"

# Add calico-typha to Apparmor unconfined mode
tput setaf 5
echo -e "\n \n*******************************************************************************************************************"
echo -e "Patching the Calico deployment to work with KinD and Kubearmor"
echo -e "*******************************************************************************************************************"
tput setaf 3
kubectl patch deploy -n calico-system calico-typha --type=json -p='[{"op": "add", "path": "/spec/template/metadata/annotations/container.apparmor.security.beta.kubernetes.io~1calico-typha", "value": "unconfined"}]'

echo -e "\nWaiting for the calico-typha deployment to be in a ready state:"
tput setaf 3
kubectl wait deploy/calico-typha --for condition=available -n calico-system
tput setaf 7
echo -e "\nCalico-typha restart is complete - Moving on to deploying the Kubearmor operator\n"

# Install Kubearmor using Helm
tput setaf 5
echo -e "\n \n*******************************************************************************************************************"
echo -e "Installing Kubearmor operator using Helm and patching it to work with KinD"
echo -e "*******************************************************************************************************************"
tput setaf 3
helm repo add kubearmor https://kubearmor.github.io/charts
helm repo update kubearmor
helm upgrade --install kubearmor-operator kubearmor/kubearmor-operator -n kubearmor --create-namespace
kubectl patch deployment kubearmor-operator -n kubearmor --patch-file kubearmor-operator-patch.yaml

# Wait for the operator to deploy before we try to use the Kubearmor CRD
tput setaf 5
echo -e "\n \n*******************************************************************************************************************"
echo -e "Installing Kubearmor with default settings using the Kubearmor CRD"
echo -e "*******************************************************************************************************************"
tput setaf 7
echo -e "\nWaiting for the operator to be in a ready state:"
tput setaf 3
kubectl wait deploy/kubearmor-operator --for condition=available -n kubearmor
tput setaf 7
echo -e "\nOperator is running - deploying Kubearmor to the cluster\n"
tput setaf 3
kubectl apply -f https://raw.githubusercontent.com/kubearmor/KubeArmor/main/pkg/KubeArmorOperator/config/samples/sample-config.yml

#karmor install
sleep 10

# Add Kubearmor-relay to Apparmor unconfined mode 
# This is required for kubearmor-relay to function in a KinD cluster - this is not required for standard K8s clusters
tput setaf 5
echo -e "\n \n*******************************************************************************************************************"
echo -e "Patching the kubearmor-relay Deployment"
echo -e "*******************************************************************************************************************"
tput setaf 3
kubectl patch deploy -n $(kubectl get deploy -l kubearmor-app=kubearmor-relay -A -o custom-columns=:'{.metadata.namespace}',:'{.metadata.name}') --type=json -p='[{"op": "add", "path": "/spec/template/metadata/annotations/container.apparmor.security.beta.kubernetes.io~1kubearmor-relay-server", "value": "unconfined"}]'

# To enable logging we need to add two environment variables to enable STDOUT logging for Kubearmor policies
tput setaf 5
echo -e "\n \n*******************************************************************************************************************"
echo -e "Patching the kubearmor-relay Deployment"
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
