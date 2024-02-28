#!/bin/bash

export hostip=$(hostname  -I | cut -f1 -d' ' | sed 's/[.]/-/g')

echo "getting oidc config"
export oidc_config=$(curl --insecure https://k8sou.apps.$hostip.nip.io/auth/idp/service-idp/.well-known/openid-configuration 2>/dev/null | jq -r '.jwks_uri')


sed "s/IPADDR/$hostip/g" < ./write_checks.yaml | sed "s/JWKS_FROM_SERVER/$jwks/g" > /tmp/write_checks.yaml

kubectl apply -f /tmp/write_checks.yaml