#!/bin/bash
clear

tput setaf 5
echo -e "\n \n*******************************************************************************************************************"
echo -e "Getting Host IP to create nip.io Ingress rules"
echo -e "*******************************************************************************************************************"
tput setaf 3

export hostip=$(hostname  -I | cut -f1 -d' ' | sed 's/[.]/-/g')

tput setaf 5
echo -e "\n \n*******************************************************************************************************************"
echo -e "Creating required namepaces, RBAC and ServiceAccount"
echo -e "*******************************************************************************************************************"
tput setaf 3

kubectl create ns vault-integration
kubectl create sa vault-client -n vault-integration

kubectl create -f - <<EOF
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: role-tokenreview-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:auth-delegator
subjects:
- kind: ServiceAccount
  name: vault-client
  namespace: vault-integration
EOF

tput setaf 5
echo -e "\n \n*******************************************************************************************************************"
echo -e "Exporting JWT for Token Review"
echo -e "*******************************************************************************************************************"
tput setaf 3

export TOKEN_REVIEW_JWT=$(kubectl create token vault-client -n vault-integration --duration=8670h)

tput setaf 5
echo -e "\n \n*******************************************************************************************************************"
echo -e "Configuring Vault communication to API server"
echo -e "*******************************************************************************************************************"
tput setaf 3

# configure vault to talk to our api server ingress
export KUBE_CA_CERT=$(kubectl get secret root-ca -n cert-manager -o json | jq -r '.data["tls.crt"]' | base64 -d)
export KUBE_HOST="https://kube-api.$hostip.nip.io"

tput setaf 5
echo -e "\n \n*******************************************************************************************************************"
echo -e "Creating Vault connection using the Vault CLI"
echo -e "*******************************************************************************************************************"
tput setaf 3

# connect to vault
. ./vault_cli.sh

tput setaf 5
echo -e "\n \n*******************************************************************************************************************"
echo -e "Enabling Vault KV"
echo -e "*******************************************************************************************************************"
tput setaf 3

# enable kv engine to the secret root
vault secrets enable --path=secret kv

tput setaf 5
echo -e "\n \n*******************************************************************************************************************"
echo -e "Enabling Vault authentication to the cluster"
echo -e "*******************************************************************************************************************"
tput setaf 3

# enable vault authentication to our cluster
vault auth enable kubernetes
vault write auth/kubernetes/config \
     token_reviewer_jwt="$TOKEN_REVIEW_JWT" \
     kubernetes_host="$KUBE_HOST" \
     kubernetes_ca_cert="$KUBE_CA_CERT" \
     issuer="https://kubernetes.default.svc.cluster.local"

tput setaf 7
echo -e "\n \n*******************************************************************************************************************"
echo -e "Vault Integration is complete"
echo -e "*******************************************************************************************************************\n\n"
tput setaf 2

