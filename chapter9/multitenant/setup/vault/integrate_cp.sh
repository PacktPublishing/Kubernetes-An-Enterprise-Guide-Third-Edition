#!/bin/bash

# first, configure our control plane to be able to authenticate pods
export hostip=$(hostname  -I | cut -f1 -d' ' | sed 's/[.]/-/g')

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


export TOKEN_REVIEW_JWT=$(kubectl create token vault-client -n vault-integration --duration=8670h)

export KUBE_CA_CERT=$(kubectl get secret root-ca -n cert-manager -o json | jq -r '.data["tls.crt"]' | base64 -d)
export KUBE_HOST="https://kube-api.$hostip.nip.io"

. ./vault_cli.sh

# enable kv engine to the secret root
vault secrets enable --path=secret kv


# enable vault authentication to our cluster
vault auth enable kubernetes
vault write auth/kubernetes/config \
     token_reviewer_jwt="$TOKEN_REVIEW_JWT" \
     kubernetes_host="$KUBE_HOST" \
     kubernetes_ca_cert="$KUBE_CA_CERT" \
     issuer="https://kubernetes.default.svc.cluster.local"


# allow openunison:orchestra SA to configure vault
vault policy write openunison-admin ./vault-admin.hcl
vault write auth/kubernetes/role/openunison-admin \
     bound_service_account_names=openunison-orchestra \
     bound_service_account_namespaces=openunison \
     policies=openunison-admin \
     ttl=24h