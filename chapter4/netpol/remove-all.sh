#!/bin/bash
clear

tput setaf 3
echo -e "*******************************************************************************************************************"
echo -e "Deleting Network Policy"
echo -e "******************************************************************************************************************"
kubectl delete -f ./backend-db-netpol.yaml -n sales 

tput setaf 5
echo -e "\n*******************************************************************************************************************"
echo -e "Deleting DB StateFulSet"
echo -e "*******************************************************************************************************************"
tput setaf 2
kubectl delete statefulset.apps/db-postgresql -n sales

tput setaf 5
echo -e "\n*******************************************************************************************************************"
echo -e "Deleting Sales Namespace"
echo -e "*******************************************************************************************************************"
tput setaf 2
kubectl delete ns sales

