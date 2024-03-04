#!/bin/bash
clear

tput setaf 6
echo -e "\n \n*******************************************************************************************************************"
echo -e "Adding HELM Repo and updating"
echo -e "*******************************************************************************************************************"
tput setaf 2
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

tput setaf 6
echo -e "\n \n*******************************************************************************************************************"
echo -e "Creating monitoring namespace and deploying Prometheus"
echo -e "*******************************************************************************************************************"
tput setaf 2
kubectl create ns monitoring
helm install prometheus prometheus-community/kube-prometheus-stack -n monitoring -f values.yaml

tput setaf 6
echo -e "\n \n*******************************************************************************************************************"
echo -e "Getting the IP address of the host to create nip.io Ingress rule"
echo -e "*******************************************************************************************************************"
tput setaf 2
export hostip=$(hostname  -I | cut -f1 -d' ' | sed 's/[.]/-/g')

tput setaf 6
echo -e "\n \n*******************************************************************************************************************"
echo -e "Deploying Ingress rule for Prometheus"
echo -e "*******************************************************************************************************************"
tput setaf 2
sed "s/IPADDR/$hostip/g" < ./prometheus-ingress.yaml  > /tmp/prometheus-ingress.yaml
kubectl create -f /tmp/prometheus-ingress.yaml

sed "s/IPADDR/$hostip/g" < ./grafana-ingress.yaml  > /tmp/grafana-ingress.yaml
kubectl create -f /tmp/grafana-ingress.yaml

sed "s/IPADDR/$hostip/g" < ./alertmanager-ingress.yaml  > /tmp/alertmanager-ingress.yaml
kubectl create -f /tmp/alertmanager-ingress.yaml

tput setaf 6
echo -e "\n \n*******************************************************************************************************************"
echo -e "Deployment complete!"
echo -e "Prometheus URL is live at: https://prometheus.apps.$hostip.nip.io/"
echo -e "*******************************************************************************************************************\n\n"
tput setaf 2

