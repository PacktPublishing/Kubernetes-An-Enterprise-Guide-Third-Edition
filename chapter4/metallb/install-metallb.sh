#!/bin/bash
clear

# Deploy MetalLB using the downloaded manifest from the MetalLB repository.
tput setaf 5
echo -e "\n*******************************************************************************************************************"
echo -e "Installing MetalLB - Version v0.13.10"
echo -e "*******************************************************************************************************************"
tput setaf 2
kubectl create -f metallb-deploy.yaml

# Wait for MetalLB to deploy before creating custom resource
tput setaf 5
echo -e "\n*******************************************************************************************************************"
echo -e "Waiting for MetalLB to Deploy before continuing - This will take a minute or two"
echo -e "*******************************************************************************************************************"
kubectl wait deployment/controller --for=condition=available --timeout=300s  -n metallb-system

# This section will find the Docker KinD subnet.  We will use the first two octets to create the IP address pool we will
# use in MetalLB - It will get the IP address from the worker node and use the firt two octets for the range, creating a range
# of x.y.200.100 - x.y.200.125.   This will be used to create the IPaddressPool
tput setaf 5
echo -e "\n*******************************************************************************************************************"
echo -e "Finding the Docker KinD Network Information"
echo -e "*******************************************************************************************************************"
tput setaf 2
kind_subnet=$(docker inspect --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$@" cluster01-worker)
first_octets=$(echo $kind_subnet | cut -d '.' -f 1,2)
metallb_pool=$first_octets".200.100-"$first_octets".200.125"
metallb_pool2=$first_octets".201.200-"$first_octets".201.225"

# This section will create the manifest for the IPaddressPool using the metallb_pool variable from the previous step
# It uses a template manifest and replaces the <metallb_pool> with the address pool that was created.
tput setaf 5
echo -e "\n*******************************************************************************************************************"
echo -e "Creating the MetalLB IPaddressPool using an address pool using $metallb_pool"
echo -e "and a second pool using $metallb_pool2"
echo -e "*******************************************************************************************************************"
tput setaf 2
cat metallb-pool-template.yaml | sed -E "s/<metallb_pool>/${metallb_pool}/"  > metallb-pool.yaml
cat metallb-pool-template2.yaml | sed -E "s/<metallb_pool>/${metallb_pool2}/"  > metallb-pool-2.yaml

# Apply the MetalLB Configuration - This will set up MetalLB in Layer 2 mode, with an IP range that will be used
# to assign IP addresses to services that require a LoadBalancer type.
tput setaf 5
echo -e "\n*******************************************************************************************************************"
echo -e "Deploying the MetalLB Pool and L2Advertisement Resources"
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
