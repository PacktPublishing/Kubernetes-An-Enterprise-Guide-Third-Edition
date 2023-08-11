#!/bin/bash
clear

# Deploy MetalLB using the downloaded manifest from the MetalLB repository.
tput setaf 5
echo -e "\n*******************************************************************************************************************"
echo -e "Installing MetalLB - NYC Cluster - Version v0.13.10"
echo -e "*******************************************************************************************************************"
tput setaf 2
kubectl create -f metallb-deploy.yaml

# Wait for MetalLB to deploy before creating custom resource
tput setaf 5
echo -e "\n*******************************************************************************************************************"
echo -e "Waiting for MetalLB to Deploy before continuing - This will take a minute or two"
echo -e "*******************************************************************************************************************"
kubectl wait deployment/controller --for=condition=available --timeout=300s  -n metallb-system

tput setaf 5
echo -e "\n*******************************************************************************************************************"
echo -e "Deploying the MetalLB Pool and L2Advertisement Resources"
echo -e "*******************************************************************************************************************"
tput setaf 2
sleep 5
kubectl apply -f metallb-pool-nyc.yaml
kubectl apply -f l2advertisement.yaml

# Show the pods from the metallb-system namespace
tput setaf 3
echo -e "\n*******************************************************************************************************************"
echo -e "MetalLB installation complete"
echo -e "*******************************************************************************************************************\n"
tput setaf 2

kubectl get pods -n metallb-system

echo -e "\n\n"

