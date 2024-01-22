#!/bin/bash

clear

tput setaf 5
echo -e "\n \n*******************************************************************************************************************"
echo -e "Increasing the number of files that can be open and tracked"
echo -e "*******************************************************************************************************************"
tput setaf 3

sudo sysctl -w fs.inotify.max_user_instances=1024
sudo sysctl -w fs.inotify.max_user_watches=12288


tput setaf 5
echo -e "\n \n*******************************************************************************************************************"
echo -e "Creating the opensearch oidc client secret"
echo -e "*******************************************************************************************************************"
tput setaf 3

kubectl patch secret orchestra-secrets-source -n openunison --patch '{"data":{"opensearch-oidc-client-secret":"Qkx4dmw3b01TeDhteHBTR3BPVjBVdFJpS0FyRkxNbTRuMzY4bnpUNGN1OWNYdVZjM0FacTY5dmNQY1EyemV0ag=="}}'

tput setaf 5
echo -e "\n \n*******************************************************************************************************************"
echo -e "Pre-deploy OpenSearch"
echo -e "*******************************************************************************************************************"
tput setaf 3

kubectl create ns opensearch-cp
kubectl create ns opensearch-operator
kubectl create ns fluentbit

helm repo add opensearch-operator https://opensearch-project.github.io/opensearch-k8s-operator/
helm repo add fluent https://fluent.github.io/helm-charts
helm repo update
helm install opensearch-operator opensearch-operator/opensearch-operator -n opensearch-operator


tput setaf 5
echo -e "\n \n*******************************************************************************************************************"
echo -e "Adding an Identity Provider to OpenUnison and Deploying OpenSearch"
echo -e "*******************************************************************************************************************"
tput setaf 3


export hostip=$(hostname  -I | cut -f1 -d' ' | sed 's/[.]/-/g')

sed "s/IPADDR/$hostip/g" < ./opensearch-sso.yaml  > /tmp/opensearch-sso.yaml
kubectl apply -f /tmp/opensearch-sso.yaml


tput setaf 5
echo -e "\n \n*******************************************************************************************************************"
echo -e "Deploy FluentBit"
echo -e "*******************************************************************************************************************"
tput setaf 3

helm upgrade --install fluent-bit fluent/fluent-bit -n fluentbit -f ./fluentbit.yaml