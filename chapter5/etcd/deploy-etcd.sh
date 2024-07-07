#!/bin/bash
clear

tput setaf 6
echo -e "\n \n*******************************************************************************************************************"
echo -e "Deploying ETCD into your cluster"
echo -e "*******************************************************************************************************************"

# Create a new namespace called etcd-dns
# You can have Helm create the namespace as well using the --create-namespace option.  We are creating the namespace using
# kubectl as an example only.  There are advantages to creating a namespace using kubectl over Helm in most Enterprise
# clusters.   When you use the --create-namespace option in Helml, you can only create a namespace - you cannot set any options.
# Mny enterprises will create labels on namespaces, at a minimum.  Also, if the namespace exists before running Helm with 
# --create-namespace, the Helm deployment will fail and you need to delete the namespace before running the Helm command.
tput setaf 6
echo -e "\n \n*******************************************************************************************************************"
echo -e "Creating the etcd-dns namespace"
echo -e "*******************************************************************************************************************"
tput setaf 2
kubectl create ns etcd-dns

# This section will deploy the ETCD chart in our cluster using a values.yaml file.
tput setaf 6
echo -e "\n \n*******************************************************************************************************************"
echo -e "Deploying Bitnami's ETCD Helm Chart"
echo -e "*******************************************************************************************************************"
tput setaf 2
helm install etcd-dns oci://registry-1.docker.io/bitnamicharts/etcd -f values.yaml -n etcd-dns

tput setaf 6
echo -e "\n\nETCD has been deployed in the etcd-dns namespace"
tput setaf 2

