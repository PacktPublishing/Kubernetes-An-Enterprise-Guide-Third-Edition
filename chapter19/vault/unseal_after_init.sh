#!/bin/bash
pod_name=$(kubectl get pods -lapp.kubernetes.io/name=vault -n vault -o json | jq -r '.items[0].metadata.name')

# wait for vault to be running
while [[ $(kubectl get pod $pod_name -n vault -o 'jsonpath={..status.containerStatuses[0].started}') != "true" ]]; do echo "waiting for vault pod" && sleep 1; done

# get the seal secrets
path_to_secrets=$(mktemp)
echo $path_to_secrets

pulumi config --show-secrets -j | jq -r '.["kube-enterprise-3-idp:vault.tokens"].value' > $path_to_secrets

# unseal the vault pod
KEYS=$(jq -r '@sh "\(.unseal_keys_hex)\n"'< $path_to_secrets)
echo $KEYS

for KEY in $KEYS
do
  echo $KEY
  KEY2=$(echo -n $KEY | cut -d "'" -f 2)
  kubectl exec -i $pod_name -n vault - -- vault operator unseal $KEY2
done

