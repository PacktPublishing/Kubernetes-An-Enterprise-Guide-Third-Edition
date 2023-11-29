#!/bin/bash

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
kubectl create ns monitoring
helm install prometheus prometheus-community/kube-prometheus-stack -n monitoring

sed "s/IPADDR/$hostip/g" < ./prometheus-ingress.yaml  > /tmp/prometheus-ingress.yaml
kubectl create -f /tmp/prometheus-ingress.yaml