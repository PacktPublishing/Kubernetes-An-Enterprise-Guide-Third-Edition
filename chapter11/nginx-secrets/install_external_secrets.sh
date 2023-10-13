#!/bin/bash

helm repo add external-secrets https://charts.external-secrets.io
helm repo update

helm install external-secrets \
   external-secrets/external-secrets \
    -n external-secrets \
    --create-namespace

while [[ $(kubectl get pods -l app.kubernetes.io/name=external-secrets-webhook -n external-secrets -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do echo "waiting for external-secrets webhook" && sleep 1; done
while [[ $(kubectl get pods -l app.kubernetes.io/name=external-secrets -n external-secrets -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do echo "waiting for external-secrets controller" && sleep 1; done
while [[ $(kubectl get pods -l app.kubernetes.io/name=external-secrets-cert-controller -n external-secrets -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do echo "waiting for external-secrets certbot" && sleep 1; done


kubectl create ns my-ext-secret
kubectl create sa ext-secret-vault -n my-ext-secret


kubectl create secret generic secret-to-be-created  -n my-ext-secret

mkdir /tmp/cabundle
kubectl get secret root-ca -n cert-manager -o json | jq -r '.data["tls.crt"]' | base64 -d > /tmp/cabundle/tls.crt
kubectl create configmap cacerts --from-file=/tmp/cabundle -n my-ext-secret



. ../vault/vault_cli.sh

vault kv put secret/data/extsecret/config some-password=mysupersecretp@ssw0rd

vault policy write extsecret - <<EOF
path "secret/data/extsecret/config" {
  capabilities = ["read"]
}

path "secret/data/extsecret/config/*" {
  capabilities = ["read"]
}
EOF


vault write auth/kubernetes/role/extsecret \
     bound_service_account_names=ext-secret-vault \
     bound_service_account_namespaces=my-ext-secret \
     policies=extsecret \
     ttl=24h





export hostip=$(hostname  -I | cut -f1 -d' ' | sed 's/[.]/-/g')
sed "s/IPADDR/$hostip/g" < ./ext-secret-template.yaml  > /tmp/ext-secret-template.yaml
kubectl create -f /tmp/ext-secret-template.yaml
