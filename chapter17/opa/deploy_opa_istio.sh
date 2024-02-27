#!/bin/bash

clear

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
kubectl get cm istio -n istio-system -o json | jq -r '.data.mesh' > /tmp/istio-config/mesh.yaml
jq '.extensionProviders[.|length] |= . + {"name":"opa-ext-authz-grpc","envoyExtAuthzGrpc": {"service": "opa-ext-authz-grpc.local","port": "9191"}}'  < /tmp/istio-config/mesh.json > /tmp/istio-config/mesh-patched.json
yq -o yaml /tmp/istio-config/mesh-patched.json | grep -v null > /tmp/istio-config/mesh
rm -rf /tmp/istio-system/mesh.*
kubectl delete cm istio -n istio-system
kubectl create cm istio -n istio-system --from-file=/tmp/istio-config


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

