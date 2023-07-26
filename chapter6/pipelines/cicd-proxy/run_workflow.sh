#!/bin/bash

export hostip=$(hostname  -I | cut -f1 -d' ' | sed 's/[.]/-/g')

sed "s/IPADDR/$hostip/g" < ./run_workflow.yaml > /tmp/run_workflow.yaml

kubectl create -f /tmp/run_workflow.yaml