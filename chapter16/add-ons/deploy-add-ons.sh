#!/bin/bash
clear

tput setaf 6
echo -e "\n \n*******************************************************************************************************************"
echo -e "Deploying Stateful Istio Add-Ons: Prometheus, Grafana and Jeager"
echo -e "*******************************************************************************************************************"
tput setaf 2
kubectl apply -f prometheus-deployment.yaml -n istio-system
kubectl apply -f grafana-deployment.yaml -n istio-system
kubectl apply -f jaeger-deployment.yaml -n istio-system

tput setaf 6
echo -e "\n \n*******************************************************************************************************************"
echo -e "Getting the Host IP address to create the nip.ip name and deploying new Gateway for Add-Ons"
echo -e "*******************************************************************************************************************"
tput setaf 2
export hostip=$(hostname  -I | cut -f1 -d' ')
envsubst < gw.yaml | kubectl apply -f -

tput setaf 6
echo -e "\n \n*******************************************************************************************************************"
echo -e "Creating VirtualServices for Each Add-On"
echo -e "*******************************************************************************************************************"
tput setaf 2
envsubst < grafana-vs.yaml | kubectl apply -f -
envsubst < prometheus-vs.yaml | kubectl apply -f -
envsubst < jaeger-vs.yaml | kubectl apply -f -

tput setaf 5
echo -e "\n\nThe Istio objects have been created for Grafana, Prometheus and Jaeger, you can open the UI using the following URL's\n"
tput setaf 7
echo -e "Grafana    : http://grafana.$hostip.nip.io/"
echo -e "Prometheus : http://prom.$hostip.nip.io/"
echo -e "Jaeger     : http://jaeger.$hostip.nip.io/"

echo -e "\n\n"
tput setaf 9
