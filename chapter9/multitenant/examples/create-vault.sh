#!/bin/bash

export hostip=$(hostname  -I | cut -f1 -d' ' | sed 's/[.]/-/g')
sed "s/IPADDR/$hostip/g" < ./volume-vault-watch.yaml  > /tmp/volume-vault-watch.yaml
kubectl create -f /tmp/volume-vault-watch.yaml