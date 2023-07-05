#!/bin/bash
clear

tput setaf 3
echo -e "*******************************************************************************************************************"
echo -e "Creating Network Policy Example"
echo -e "*******************************************************************************************************************"

kubectl create ns sales

tput setaf 5
echo -e "\n*******************************************************************************************************************"
echo -e "Deploying PostgreSQL to the sales namespace"
echo -e "*******************************************************************************************************************"
tput setaf 2
# Create a MySQL container with the label app=backend-db
# Notice the label that is set, app=backend-db - this matches the network policy selector.
helm install db oci://registry-1.docker.io/bitnamicharts/postgresql -n sales

tput setaf 5
echo -e "\n\n*******************************************************************************************************************"
echo -e "Waiting for PostgeSQL to become ready"
echo -e "*******************************************************************************************************************"
tput setaf 2

# Wait for the mysql pod to become ready before showing how to test the network policy
kubectl wait --for=condition=Ready pod/db-postgresql-0 -n sales

tput setaf 5
echo -e "\n\n*******************************************************************************************************************"
echo -e "Deploying the network policy"
echo -e "*******************************************************************************************************************"
tput setaf 2
# Deploy the network policy
kubectl create -f backend-db-netpol.yaml 

tput setaf 5
echo -e "\n\n*******************************************************************************************************************"
echo -e "Getting information from the deployment to test the network policy"
echo -e "*******************************************************************************************************************"
tput setaf 2

# Tell the reader to run the netshoot pod to test the network policy for both a matching label and non-matching label
echo -e "\nDatabase has been deployed.  To test the network policy, use the netshoot troubleshooting container"
echo -e "and try to telnet to the MySQL port 5432. Use one of the examples below to test the policy with a matching"
echo -e "label or non-matching label.\n"

# Get the IP Address for the pod so we can test it using netshoot
pod_ip=$(kubectl get pod db-postgresql-0 --template '{{.status.podIP}}' -n sales)
tput setaf 3
echo -e "\nPostgreSQL pod IP address: " $pod_ip "\n"
tput setaf 2

# Test with a label that doesnt match the network policy. This will show a denied request.
echo -e "To start up netshoot with a label that does not match the network policy run the following kubectl command:"
tput setaf 3
echo -e "kubectl run tmp-shell --rm -i --tty --image nicolaka/netshoot -n sales --labels app=wrong \n"
tput setaf 2
# Test with a label that doesnt match the network policy. This will show a successful request.
echo -e "To start up netshoot with a label that does match the network policy run the following kubectl command:"
tput setaf 3
echo -e "kubectl run tmp-shell --rm -i --tty --image nicolaka/netshoot -n sales --labels app=frontend\n\n"
tput setaf 2
