#!/bin/bash
clear

tput setaf 5
echo -e "\n*******************************************************************************************************************"
echo -e "Creating the demo namespace and labeling it to enable Istio"
echo -e "*******************************************************************************************************************"
tput setaf 2
kubectl create ns testapp
kubectl label ns testapp istio-injection=enabled

# Create a simple NGINX deployment using kubectl and name it nginx-web
tput setaf 5
echo -e "\n*******************************************************************************************************************"
echo -e "Deploying the NGINX pod"
echo -e "*******************************************************************************************************************"
tput setaf 2
kubectl create deployment nginx-web --image bitnami/nginx -n testapp

kubectl expose deployment nginx-web --port 8080 --target-port 8080 -n testapp

# Find IP address of Docker Host
# We need to know the IP of the Host since we use nip.io for name resolution.  Nip.ip names follow the standard <url>.<host ip>.nip.io
# For example, if you wanted to have two Ingress rules, one for a sales web site and one for an ordering website, and your Host IP is 192.168.1.1
# your nip.io names would be sales.192.168.1.1.nip.io and ordering.192.168.1.1.nip.io
# This does assume that the first IP found is the correct IP address of the Host.  In a multi-homed system you may need to use a different
# IP address, but we have no easy way to know the correct IP to use if there are multiple IP addresses on a Host system.
tput setaf 5
echo -e "\n \n*******************************************************************************************************************"
echo -e "Finding the IP address of the host to create the nip.io Ingress rule"
echo -e "*******************************************************************************************************************"
tput setaf 2
export hostip=$(hostname  -I | cut -f1 -d' ')
echo -e "\nFound the Host IP: $hostip"

tput setaf 6
echo -e "\n \n*******************************************************************************************************************"
echo -e "Deploying the Gateway and VirtualService for the test application"
echo -e "*******************************************************************************************************************"

tput setaf 6
echo -e "\n \n*******************************************************************************************************************"
echo -e "Getting the Host IP address to create the nip.ip name"
echo -e "*******************************************************************************************************************"
export hostip=$(hostname  -I | cut -f1 -d' ')

tput setaf 6
echo -e "\n \n*******************************************************************************************************************"
echo -e "Creating Gateway for the testapp"
echo -e "*******************************************************************************************************************"
envsubst < gw.yaml | kubectl apply -f - --namespace testapp

tput setaf 6
echo -e "\n \n*******************************************************************************************************************"
echo -e "Creating VirtualService"
echo -e "*******************************************************************************************************************"
envsubst < vs.yaml | kubectl apply -f - --namespace testapp

tput setaf 5
echo -e "\n \nIt may take 3-5 minutes for the application pods to become ready"
echo -e "\n \nOnce all pods are running, the Boutique application can be accessed using using http://testapp.$hostip.nip.io/"

echo -e "\n\n"
tput setaf 9


