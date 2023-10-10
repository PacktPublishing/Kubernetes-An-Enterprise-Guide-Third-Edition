#!/bin/bash


KEYS=$(jq -r '@sh "\(.unseal_keys_hex)\n"'< $1)
echo $KEYS

for KEY in $KEYS
do
  echo $KEY
  KEY2=$(echo -n $KEY | cut -d "'" -f 2)
  kubectl exec -i vault-0 -n vault - -- vault operator unseal $KEY2
done
