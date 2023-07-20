#!/bin/bash
clear

# Deploy a NGINX pod that we will expose as a LoadBalancer service
tput setaf 3
echo -e "\n*******************************************************************************************************************"
echo -e "Deploying a NGINX pod and LoadBalancer service in the default namespace"
echo -e "*******************************************************************************************************************\n"
tput setaf 2
kubectl run nginx-lb --image bitnami/nginx
kubectl create -f nginx-lb.yaml

echo -e "\n\n"
