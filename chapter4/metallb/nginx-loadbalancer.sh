#!/bin/bash
clear

# Create a simple NGINX deployment using kubectl and name it nginx-web
tput setaf 5
echo -e "\n*******************************************************************************************************************"
echo -e "Deploying the NGINX pod"
echo -e "*******************************************************************************************************************"
tput setaf 2
kubectl create deployment nginx-web --image bitnami/nginx

# Create a LoadBalancer service that exposes the Deployment on port 8080 called nginx-web
tput setaf 5
echo -e "\n*******************************************************************************************************************"
echo -e "Creating the NGINX LoadBalancer service"
echo -e "*******************************************************************************************************************"
tput setaf 2
kubectl expose deployment nginx-web --port 80 --target-port 8080 --type=LoadBalancer --name nginx-web-lb

tput setaf 5
echo -e "\n*******************************************************************************************************************"
echo -e "Getting the LoadBalancer IP address for the NGINX service"
echo -e "*******************************************************************************************************************"
tput setaf 2
svc_ip=$(kubectl get service nginx-web-lb -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

tput setaf 7
echo -e "\n \n*******************************************************************************************************************"
echo -e "The NGINX server has been exposed on a LoadBalancer service with IP address: $svc_ip  \n"
echo -e "\n\n Due to how networking works with KinD, we can only test the LoadBalancer address from the Docker host itself"
echo -e "You can do this by using a simple curl command:   curl $svc_ip"
echo -e "******************************************************************************************************************* \n\n"
tput setaf 2

