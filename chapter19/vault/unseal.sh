#!/bin/bash




pod_name=$(kubectl get pods -lapp.kubernetes.io/name=vault -n vault -o json | jq -r '.items[0].metadata.name')

# wait for vault to be running
while [[ $(kubectl get pod $pod_name -n vault -o 'jsonpath={..status.containerStatuses[0].started}') != "true" ]]; do echo "waiting for vault pod" && sleep 1; done

# get the seal secrets
path_to_secrets=$(mktemp)
echo $path_to_secrets

kubectl exec --stdin=true --tty=true $pod_name -n vault -- vault operator init --format=json > $path_to_secrets

# unseal the vault pod
KEYS=$(jq -r '@sh "\(.unseal_keys_hex)\n"'< $path_to_secrets)
echo $KEYS

for KEY in $KEYS
do
  echo $KEY
  KEY2=$(echo -n $KEY | cut -d "'" -f 2)
  kubectl exec -i $pod_name -n vault - -- vault operator unseal $KEY2
done

# get the root token and set the secret
pulumi config set vault.key $(jq -r '.root_token' < $path_to_secrets) --secret

# save all tokens
pulumi config set vault.tokens  --secret < $path_to_secrets