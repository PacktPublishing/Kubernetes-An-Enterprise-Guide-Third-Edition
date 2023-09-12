#!/bin/bash

kubectl get secret root-ca -n cert-manager -o json | jq -r '.data["tls.crt"]' | base64 -d > /tmp/root-ca.crt

export hostip=$(hostname  -I | cut -f1 -d' ' | sed 's/[.]/-/g')

export VAULT_ADDR="https://vault.apps.$hostip.nip.io/"
export VAULT_CACERT="/tmp/root-ca.crt"
export VAULT_TOKEN=$(jq -r '.root_token' < ~/unseal-keys.json)