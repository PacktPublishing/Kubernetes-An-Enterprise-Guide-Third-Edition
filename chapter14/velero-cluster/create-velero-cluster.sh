#!/bin/bash
clear

# Most of the coding segments in the book have been removed to make room for additional technical contact.  Scripts will now
# contain more documentation to help users understand what the scripts are executing.
tput setaf 3
echo -e "*******************************************************************************************************************"
echo -e "Creating Velero Restore KinD Cluster"
echo -e "*******************************************************************************************************************"

tput setaf 5
# Create KIND Cluster calle cluster01 using config cluster01-kind.yaml
# KinD will deploy a cluster using the v1.27.1 Image - This has been tested with all of the book exercises and any K8s version
# other than 1.27.1 may not work with all the book scripts due to any changes in K8s.
echo -e "\n \n*******************************************************************************************************************"
echo -e "Create KinD Cluster for Velero restore - Using the v.1.28.0 Image"
echo -e "*******************************************************************************************************************"
tput setaf 3
kind create cluster --name velero-restore  --config velero-cluster.yaml --image kindest/node:v1.28.0@sha256:b7a4cad12c197af3ba43202d3efe03246b3f0793f162afb40a33c923952d5b31

echo -e "\n \n*******************************************************************************************************************"
echo -e "Install Calico from local file"
echo -e "*******************************************************************************************************************"
tput setaf 3
kubectl create -f calico/tigera-operator.yaml
kubectl create -f calico/custom-resources.yaml

echo -e "\n \n*******************************************************************************************************************"
echo -e "Velero Cluster created"
echo -e "*******************************************************************************************************************\n"
tput setaf 3
echo -e "\nSince we aew only using this cluster for a restoring example, we will not deploy a NGNIX ingress controller\n\n" 

tput setaf 2
