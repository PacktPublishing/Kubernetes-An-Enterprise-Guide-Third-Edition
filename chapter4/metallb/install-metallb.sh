#!/bin/bash
clear

# Deploy MetalLB using the downloaded manifest from the MetalLB repository.
tput setaf 5
echo -e "\n*******************************************************************************************************************"
echo -e "Installing MetalLB - Version v0.13.10"
echo -e "*******************************************************************************************************************"
tput setaf 2
kubectl create -f metallb-deploy.yaml

# Apply the MetalLB Configuration - This will set up MetalLB in Layer 2 mode, with an IP range that will be used
# to assign IP addresses to services that require a LoadBalancer type.
tput setaf 5
echo -e "\n*******************************************************************************************************************"
echo -e "Configuring the MetalLB Pool and L2Advertisement Resources"
echo -e "*******************************************************************************************************************"
tput setaf 2
sleep 5
kubectl apply -f metallb-pool.yaml
kubectl apply -f l2advertisement.yaml

# Show the pods from the metallb-system namespace
tput setaf 3
echo -e "\n*******************************************************************************************************************"
echo -e "MetalLB installation complete"
echo -e "*******************************************************************************************************************\n"
tput setaf 2

kubectl get pods -n metallb-system

echo -e "\n\n"

# Deploy a NGINX pod that we will expose as a LoadBalancer service
tput setaf 3
echo -e "\n*******************************************************************************************************************"
echo -e "Deploying a NGINX pod and LoadBalancer service in the default namespace"
echo -e "*******************************************************************************************************************\n"
tput setaf 2
kubectl run nginx-lb --image bitnami/nginx
kubectl create -f nginx-lb.yaml
