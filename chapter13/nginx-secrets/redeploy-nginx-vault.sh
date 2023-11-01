#!/bin/bash
clear

tput setaf 5
echo -e "\n \n*******************************************************************************************************************"
echo -e "Deleting NGINX pod and namespace"
echo -e "*******************************************************************************************************************"
tput setaf 3
kubectl delete pods nginx-secrets -n my-ext-secret
kubectl delete ns my-ext-secret
tput setaf 7
echo -e "\nExecuting script to re-create namespace and NGINX pod"
sleep 5

tput setaf 5
echo -e "\n \n*******************************************************************************************************************"
echo -e "Redeploying new NGINX pod"
echo -e "*******************************************************************************************************************"
tput setaf 3
./create-nginx-vault.sh

tput setaf 5
echo -e "*******************************************************************************************************************"
echo -e "Creating Kubearmor policy to secure Vault secret in pod"
echo -e "*******************************************************************************************************************"
tput setaf 3
kubectl apply -f nginx-secrets-block.yaml

tput setaf 7
echo -e "\n\n*******************************************************************************************************************"
echo -e "Done deploying new NGINX pod and Kubearmor policy to protect the Vault secret"
echo -e "*******************************************************************************************************************\n\n"
tput setaf 2



