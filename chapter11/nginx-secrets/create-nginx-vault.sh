#!/bin/bash

export hostip=$(hostname  -I | cut -f1 -d' ' | sed 's/[.]/-/g')
sed "s/IPADDR/$hostip/g" < ./nginx-secrets.yaml  > /tmp/nginx-secrets.yaml
kubectl create -f /tmp/nginx-secrets.yaml
