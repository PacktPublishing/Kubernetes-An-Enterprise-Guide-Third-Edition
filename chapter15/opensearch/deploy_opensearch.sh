#!/bin/bash

clear

tput setaf 5
echo -e "\n \n*******************************************************************************************************************"
echo -e "Increasing the number of files that can be open and tracked"
echo -e "*******************************************************************************************************************"
tput setaf 3

sudo sysctl -w fs.inotify.max_user_instances=1024
sudo sysctl -w fs.inotify.max_user_watches=12288


tput setaf 5
echo -e "\n \n*******************************************************************************************************************"
echo -e "Creating the opensearch oidc client secret"
echo -e "*******************************************************************************************************************"
tput setaf 3

kubectl patch secret orchestra-secrets-source -n openunison --patch '{"data":{"opensearch-oidc-client-secret":"Qkx4dmw3b01TeDhteHBTR3BPVjBVdFJpS0FyRkxNbTRuMzY4bnpUNGN1OWNYdVZjM0FacTY5dmNQY1EyemV0ag=="}}'


tput setaf 5
echo -e "\n \n*******************************************************************************************************************"
echo -e "Adding an Identity Provider to OpenUnison"
echo -e "*******************************************************************************************************************"
tput setaf 3


export hostip=$(hostname  -I | cut -f1 -d' ' | sed 's/[.]/-/g')

sed "s/IPADDR/$hostip/g" < ./opensearch-sso.yaml  > /tmp/opensearch-sso.yaml
kubectl apply -f /tmp/opensearch-sso.yaml
