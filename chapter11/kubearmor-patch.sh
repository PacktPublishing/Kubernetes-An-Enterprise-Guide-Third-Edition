#!/bin/bash
clear

# Install apparmor utilites in the kind cluster nodes
# Special thanks to Rahul Jadhav from Accuknox for the assistance on the requirements to enable Kubearmor on KinD
#docker exec -it cluster01-worker bash -c "apt update && apt install apparmor-utils -y && systemctl restart containerd"
#docker exec -it cluster01-control-plane bash -c "apt update && apt install apparmor-utils -y && systemctl restart containerd"

tput setaf 5
echo -e "\n \n*******************************************************************************************************************"
echo -e "Adding apparmor-utils to the Cluster Nodes"
echo -e "*******************************************************************************************************************"
tput setaf 3
docker exec -it cluster01-worker bash -c "apt install apparmor-utils -y && systemctl restart containerd"
docker exec -it cluster01-control-plane bash -c "apt install apparmor-utils -y && systemctl restart containerd"

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
karmor install
sleep 10

# Add Kubearmor-relay to Apparmor unconfined mode 
tput setaf 5
echo -e "\n \n*******************************************************************************************************************"
echo -e "Patching the kubearmor-relay Deployment"
echo -e "*******************************************************************************************************************"
tput setaf 3
kubectl patch deploy -n $(kubectl get deploy -l kubearmor-app=kubearmor-relay -A -o custom-columns=:'{.metadata.namespace}',:'{.metadata.name}') --type=json -p='[{"op": "add", "path": "/spec/template/metadata/annotations/container.apparmor.security.beta.kubernetes.io~1kubearmor-relay-server", "value": "unconfined"}]'

# Download and Deploy the Discovery Engine from Accuknos's site
tput setaf 5
echo -e "\n \n*******************************************************************************************************************"
echo -e "Installing the Accuknox Discovery Engine"
echo -e "*******************************************************************************************************************"
tput setaf 3
kubectl apply -f https://raw.githubusercontent.com/accuknox/discovery-engine/dev/deployments/k8s/deployment.yaml
