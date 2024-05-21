#!/bin/bash
clear

tput setaf 6
echo -e "\n \n*******************************************************************************************************************"
echo -e "Downloading Istio binary and adding it to the working path"
echo -e "*******************************************************************************************************************"
tput setaf 2
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.20.3 TARGET_ARCH=x86_64 sh -
export PATH="$PATH:$PWD/istio-1.20.3/bin"

tput setaf 6
echo -e "\n \n*******************************************************************************************************************"
echo -e "Installing Istio using the DEMO profile"
echo -e "*******************************************************************************************************************"
tput setaf 2
istioctl manifest install --set profile=demo -y

tput setaf 6
echo -e "\n \n*******************************************************************************************************************"
echo -e "Generating a manifest to verify the installation"
echo -e "*******************************************************************************************************************"
tput setaf 2
istioctl manifest generate --set profile=demo > istio-kind.yaml

tput setaf 6
echo -e "\n \n*******************************************************************************************************************"
echo -e "Verifying the Istio installation"
echo -e "*******************************************************************************************************************"
tput setaf 2
istioctl verify-install -f istio-kind.yaml

tput setaf 7
echo -e "\nIstio has been deployed and verified - Wait 10 seconds to expose istio-ingressgateway to provide external access to the service mesh"
sleep 10

tput setaf 6
echo -e "\n \n*******************************************************************************************************************"
echo -e "Removing NGINX Ingress and exposing Istio ingressgateway"
echo -e "*******************************************************************************************************************i\n\n"
tput setaf 2
./expose_istio.sh
