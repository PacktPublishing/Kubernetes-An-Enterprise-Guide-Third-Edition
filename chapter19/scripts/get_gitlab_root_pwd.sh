#!/bin/bash

kubectl get secret $(k get secrets -n gitlab | grep root | awk '{print $1}') -n gitlab -o json | jq -r '.data.password' | base64 -d