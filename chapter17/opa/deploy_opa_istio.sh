#!/bin/bash

clear

tput setaf 5
echo -e "\n \n*******************************************************************************************************************"
echo -e "Install yq for handling yaml"
echo -e "*******************************************************************************************************************"
tput setaf 3

# Install prerequisites
sudo apt update
sudo apt install -y curl

# Download latest yq (v4.x, Linux AMD64 example)
sudo curl -L https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 \
    -o /usr/local/bin/yq

# Make it executable
sudo chmod +x /usr/local/bin/yq

# Test it
yq --version

tput setaf 5
echo -e "\n \n*******************************************************************************************************************"
echo -e "Update the istiod mesh configuration to support OPA"
echo -e "*******************************************************************************************************************"
tput setaf 3

mkdir /tmp/istio-config


tput setaf 5
echo -e "\n \n*******************************************************************************************************************"
echo -e "Deploy the OPA webhook and policies"
echo -e "*******************************************************************************************************************"
tput setaf 3

kubectl apply -f ./opa-istio.yaml

kubectl get cm istio -n istio-system -o yaml > /tmp/istio-config-$(date +"%Y-%m-%d-%H:%M:%S").yaml
kubectl get cm istio -n istio-system -o json | jq -r '.data.mesh' > /tmp/istio-config-mesh-$(date +"%Y-%m-%d-%H:%M:%S").yaml
kubectl get cm istio -n istio-system -o json | jq -r '.data.mesh' > /tmp/istio-config/mesh.yaml
yq -o json /tmp/istio-config/mesh.yaml > /tmp/istio-config/mesh.json
jq '.extensionProviders[.|length] |= . + {"name":"opa-ext-authz-grpc","envoyExtAuthzGrpc": {"service": "opa-ext-authz-grpc.local","port": 9191}}'  < /tmp/istio-config/mesh.json > /tmp/istio-config/mesh-patched.json
yq -o yaml /tmp/istio-config/mesh-patched.json | grep -v null > /tmp/istio-config/mesh
rm -rf /tmp/istio-system
mkdir /tmp/istio-system
cp /tmp/istio-config/mesh /tmp/istio-system/mesh
kubectl delete cm istio -n istio-system
kubectl create cm istio -n istio-system --from-file=/tmp/istio-system


tput setaf 5
echo -e "\n \n*******************************************************************************************************************"
echo -e "Label the services namespace to inject the OPA pod along with envoy"
echo -e "*******************************************************************************************************************"
tput setaf 3

kubectl label namespace istio-hello-world opa-istio-injection=enabled

tput setaf 5
echo -e "\n \n*******************************************************************************************************************"
echo -e "Redeploy our service"
echo -e "*******************************************************************************************************************"
tput setaf 3

kubectl delete pods --all -n istio-hello-world

