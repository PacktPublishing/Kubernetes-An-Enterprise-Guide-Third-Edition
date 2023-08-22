#!/bin/bash
clear

tput setaf 5
echo -e "\n*******************************************************************************************************************"
echo -e "Installing ExternalDNS"
echo -e "*******************************************************************************************************************"
tput setaf 2

# Create a new namespace called external-dns
tput setaf 5
echo -e "\n*******************************************************************************************************************"
echo -e "Creating new external-dns namespace"
echo -e "*******************************************************************************************************************"
tput setaf 2
kubectl create ns external-dns

# Find the IP address for the ETCD service and store it in the ETCD_URL variable
tput setaf 5
echo -e "\n*******************************************************************************************************************"
echo -e "Looking up the service IP for ETCD"
echo -e "*******************************************************************************************************************"
tput setaf 2
ETCD_URL=$(kubectl -n etcd-dns get svc etcd-dns -o go-template='{{ .spec.clusterIP }}')

# Create a temporary file that will be merged with the ConfigMap manifest that contains the ETCD service IP address
tput setaf 5
echo -e "\n*******************************************************************************************************************"
echo -e "Updating the CoreDNS ConfigMap with the new zone"
echo -e "*******************************************************************************************************************"
tput setaf 2
cat coredns-add-template.txt | sed -E "s/<ETCD_URL>/${ETCD_URL}/" > coredns-add.txt
sed  '17r coredns-add.txt' coredns-cm-template.txt > coredns-cm.yaml
kubectl apply -f coredns-cm.yaml -n kube-system

# Inject the ETCD service IP into the deployment-template.yaml to Create a manifest called deployment-externaldns.yaml
tput setaf 5
echo -e "\n*******************************************************************************************************************"
echo -e "Injecting ETCD service IP into a temp manifest and creating final ExternalDNS manifest"
echo -e "*******************************************************************************************************************"
tput setaf 2
cat deployment-template.yaml | sed -E "s/<ETCD_URL>/${ETCD_URL}/" > deployment-externaldns.yaml

# Deploy ExternalDNS using the newly created deployment-externaldns.yaml
tput setaf 5
echo -e "\n*******************************************************************************************************************"
echo -e "Deploying ExternalDNS to the cluster"
echo -e "*******************************************************************************************************************"
tput setaf 2
kubectl apply -f deployment-externaldns.yaml -n external-dns

tput setaf 5
echo -e "\n\n*******************************************************************************************************************"
echo -e "ExternalDNS has been deployed to the cluster"
echo -e "*******************************************************************************************************************\n\n"
tput setaf 2

