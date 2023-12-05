#!/bin/bash

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
kubectl create ns monitoring
helm install prometheus prometheus-community/kube-prometheus-stack -n monitoring

export hostip=$(hostname  -I | cut -f1 -d' ' | sed 's/[.]/-/g')
sed "s/IPADDR/$hostip/g" < ./prometheus-ingress.yaml  > /tmp/prometheus-ingress.yaml
kubectl create -f /tmp/prometheus-ingress.yaml

sed "s/IPADDR/$hostip/g" < ./grafana-ingress.yaml  > /tmp/grafana-ingress.yaml
kubectl create -f /tmp/grafana-ingress.yaml

sed "s/IPADDR/$hostip/g" < ./alertmanager-ingress.yaml  > /tmp/alertmanager-ingress.yaml
kubectl create -f /tmp/alertmanager-ingress.yaml