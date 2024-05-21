#!/bin/bash
clear

tput setaf 6
echo -e "\n \n*******************************************************************************************************************"
echo -e "Deleting ingress-nginx namespace"
echo -e "*******************************************************************************************************************"
tput setaf 2
kubectl delete -f ../chapter2/nginx-ingress/nginx-deploy.yaml

tput setaf 6
echo -e "\n \n*******************************************************************************************************************"
echo -e "Patching istio-ingressgateway"
echo -e "*******************************************************************************************************************"
tput setaf 2
kubectl patch deployments istio-ingressgateway -n istio-system -p '{"spec":{"template":{"spec":{"containers":[{"name":"istio-proxy","ports":[{"containerPort":15021,"protocol":"TCP"},{"containerPort":8080,"hostPort":80,"protocol":"TCP"},{"containerPort":8443,"hostPort":443,"protocol":"TCP"},{"containerPort":31400,"protocol":"TCP"},{"containerPort":15443,"protocol":"TCP"},{"containerPort":15090,"name":"http-envoy-prom","protocol":"TCP"}]}]}}}}'

tput setaf 5 
echo -e "\n\nIstio ingress-gateway has replaced NGINX as the Ingress for KinD\n\n"
