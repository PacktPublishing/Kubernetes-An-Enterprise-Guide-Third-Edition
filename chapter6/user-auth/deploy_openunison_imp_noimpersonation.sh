#!/bin/bash

if [[ -z "${TS_REPO_NAME}" ]]; then
	REPO_NAME="tremolo"
else
	REPO_NAME=$TS_REPO_NAME
fi

echo "Helm Repo Name $REPO_NAME"

if [[ -z "${TS_REPO_URL}" ]]; then
	REPO_URL="https://nexus.tremolo.io/repository/helm"
else
	REPO_URL=$TS_REPO_URL
fi

echo "Helm Repo URL $REPO_URL"





echo "Deploying the Kubernetes Dashboard"

kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml

echo "Deploying ActiveDirectory (ApacheDS)"

kubectl apply -f ./apacheds.yaml

while [[ $(kubectl get pods -l app=apacheds -n activedirectory -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do echo "waiting for apacheds to be running" && sleep 1; done

echo "Adding helm repo"

helm repo add $REPO_NAME $REPO_URL
helm repo update


echo "Creating openunison namespace"

kubectl create ns openunison


echo "Pre-configuring OpenUnison LDAP"

kubectl create -f ./myvd-book.yaml


echo "Downloading the ouctl utility to /tmp/ouctl"

wget https://nexus.tremolo.io/repository/ouctl/ouctl-0.0.11-linux -O /tmp/ouctl
chmod +x /tmp/ouctl


echo "Generating helm chart values to /tmp/openunison-values.yaml"

export hostip=$(hostname  -I | cut -f1 -d' ' | sed 's/[.]/-/g')


sed "s/IPADDR/$hostip/g" < ./openunison-values-noimpersonation.yaml  > /tmp/openunison-values.yaml

echo "Deploying Orchestra"
echo -n 'start123' > /tmp/ldaps
/tmp/ouctl install-auth-portal -s /tmp/ldaps  -o $REPO_NAME/openunison-operator -c $REPO_NAME/orchestra -l $REPO_NAME/orchestra-login-portal /tmp/openunison-values.yaml




echo "OpenUnison is deployed!"


