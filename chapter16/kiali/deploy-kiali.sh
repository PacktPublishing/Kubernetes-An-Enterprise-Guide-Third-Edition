#!/bin/bash
clear

tput setaf 6
echo -e "\n \n*******************************************************************************************************************"
echo -e "Deploying Kiali and the Istio objects to expose the UI"
echo -e "*******************************************************************************************************************"

tput setaf 6
echo -e "\n \n*******************************************************************************************************************"
echo -e "Getting the Host IP address to create the nip.ip name"
echo -e "*******************************************************************************************************************"
export hostip=$(hostname  -I | cut -f1 -d' ')

tput setaf 6
echo -e "\n \n*******************************************************************************************************************"
echo -e "Deploying Kiali using Helm and custom values"
echo -e "*******************************************************************************************************************"
helm install --namespace istio-system --set auth.strategy="anonymous" --repo https://kiali.org/helm-charts kiali-server kiali-server --set external_services.prometheus.in_cluster_url=http://Prometheus:9090 --set external_services.prometheus.url=http://prom.$hostip.nip.io --set external_services.tracing.use_grpc=false --set external_services.tracing.in_cluster_url="http://tracing:80/jaeger" --set external_services.tracing.url="http://jaeger.$hostip.nip.io" --set external_services.grafana.in_cluster_url="http://grafana:3000" --set external_services.grafana.url="http://grafana.$hostip.nip.io"

tput setaf 6
echo -e "\n \n*******************************************************************************************************************"
echo -e "Deploying the Gateway and VirtualService for Kiali"
echo -e "*******************************************************************************************************************"

tput setaf 6
echo -e "\n \n*******************************************************************************************************************"
echo -e "Creating Gateway for Kiali"
echo -e "*******************************************************************************************************************"
envsubst < gw.yaml | kubectl apply -f - 

tput setaf 6
echo -e "\n \n*******************************************************************************************************************"
echo -e "Creating VirtualService for Kiali"
echo -e "*******************************************************************************************************************"
envsubst < vs.yaml | kubectl apply -f - 

tput setaf 5
echo -e "The Kiali Istio objects have been created, you can open the UI using http://kiali.$hostip.nip.io/"

echo -e "\n\n"
tput setaf 9
