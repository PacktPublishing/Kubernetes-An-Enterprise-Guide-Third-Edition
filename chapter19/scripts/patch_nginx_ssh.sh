#!/bin/bash

helm upgrade --install ingress-nginx ingress-nginx --repo https://kubernetes.github.io/ingress-nginx --namespace ingress-nginx --create-namespace --set tcp.3306=mysql/mysql:3306 --set tcp.22=gitlab/$(kubectl get svc -n gitlab | grep shell | awk '{print $1}'):22