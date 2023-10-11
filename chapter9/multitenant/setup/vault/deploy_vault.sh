#!/bin/bash

# deploy vault
kubectl create ns vault
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update

helm install vault hashicorp/vault --namespace vault --set ui.enabled=true --set ui.serviceType=ClusterIP


while [[ $(kubectl get pod vault-0 -n vault -o 'jsonpath={..status.containerStatuses[0].started}') != "true" ]]; do echo "waiting for vault pod" && sleep 1; done

kubectl exec --stdin=true --tty=true vault-0 -n vault -- vault operator init --format=json > ~/unseal-keys.json

./unseal.sh ~/unseal-keys.json

# creating ingress

export hostip=$(hostname  -I | cut -f1 -d' ' | sed 's/[.]/-/g')
sed "s/IPADDR/$hostip/g" < ./vault-ingress.yaml  > /tmp/vault-ingress.yaml
kubectl create -f /tmp/vault-ingress.yaml

# create API Server Ingress

sed "s/IPADDR/$hostip/g" < ./api-server-ingress.yaml  > /tmp/api-server-ingress.yaml
kubectl create -f /tmp/api-server-ingress.yaml

# install CLI
./install_vault.sh





