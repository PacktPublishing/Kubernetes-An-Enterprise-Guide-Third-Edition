#!/bin/bash
clear

tput setaf 6
echo -e "\n \n*******************************************************************************************************************"
echo -e "Deploying ETCD into your cluster"
echo -e "*******************************************************************************************************************"

# Create a new namespace called etcd-dns
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

