#!/bin/bash

export hostip=$(hostname  -I | cut -f1 -d' ' | sed 's/[.]/-/g')
sed "s/IPADDR/$hostip/g" < ./vault-volume-watch.yaml  > /tmp/vault-volume-watch.yaml
kubectl create -f /tmp//tmp/vault-volume-watch.yaml