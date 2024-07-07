#!/bin/bash

pulumi config set harbor:password $(kubectl get secret harbor-admin -n harbor  -o json | jq -r '.data["harbor-admin"]' | base64 -d) --secret
pulumi config set harbor.configured true