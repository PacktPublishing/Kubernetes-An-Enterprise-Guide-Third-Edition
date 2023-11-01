#!/bin/bash
clear

tput setaf 5
echo -e "\n \n*******************************************************************************************************************"
echo -e "Setting up Helm repo"
echo -e "*******************************************************************************************************************"
tput setaf 3

if [[ -z "${TS_REPO_NAME}" ]]; then
	REPO_NAME="tremolo"
else
	REPO_NAME=$TS_REPO_NAME
fi

echo "Helm Repo Name $REPO_NAME"

if [[ -z "${TS_REPO_URL}" ]]; then
	REPO_URL="https://nexus.tremolo.io/repository/helm"
else
	REPO_URL=$TS_REPO_URL
fi

echo "Helm Repo URL $REPO_URL"

tput setaf 5
echo -e "\n \n*******************************************************************************************************************"
echo -e "Deploying the Kubernetes Dashboard"
echo -e "*******************************************************************************************************************"
tput setaf 3

kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml

tput setaf 5
echo -e "\n \n*******************************************************************************************************************"
echo -e "Deploying ActiveDirectory (ApacheDS)"
echo -e "*******************************************************************************************************************"
tput setaf 3

kubectl apply -f ./apacheds.yaml

while [[ $(kubectl get pods -l app=apacheds -n activedirectory -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do echo "waiting for apacheds to be running" && sleep 1; done

tput setaf 5
echo -e "\n \n*******************************************************************************************************************"
echo -e "Adding additional Helm repo"
echo -e "*******************************************************************************************************************"
tput setaf 3

helm repo add $REPO_NAME $REPO_URL
helm repo update

tput setaf 5
echo -e "\n \n*******************************************************************************************************************"
echo -e "Creating openunison namespace"
echo -e "*******************************************************************************************************************"
tput setaf 3

kubectl create ns openunison

tput setaf 5
echo -e "\n \n*******************************************************************************************************************"
echo -e "Adding a NetworkPolicy to explicitly allow access from the API server to our OpenUnison pods by IP"
echo -e "*******************************************************************************************************************"
tput setaf 3

kubectl create -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-from-apiserver-by-ip
  namespace: openunison
  
spec:
  ingress:
  - from:
    - ipBlock:
        cidr: $(docker inspect cluster01-control-plane | jq -r '.[0].NetworkSettings.Networks.kind.IPAddress')/32
  podSelector:
    matchLabels:
      application: openunison-orchestra
  policyTypes:
  - Ingress
EOF

tput setaf 5
echo -e "\n \n*******************************************************************************************************************"
echo -e "Adding pre-configured OpenUnison LDAP"
echo -e "*******************************************************************************************************************"
tput setaf 3

kubectl create -f ./myvd-book.yaml

tput setaf 5
echo -e "\n \n*******************************************************************************************************************"
echo -e "Downloading ouctl utility and moving it to /tmp/ouctl"
echo -e "*******************************************************************************************************************"
tput setaf 3

wget https://nexus.tremolo.io/repository/ouctl/ouctl-0.0.11-linux -O /tmp/ouctl
chmod +x /tmp/ouctl

tput setaf 5
echo -e "\n \n*******************************************************************************************************************"
echo -e "Generating Helm chart values in /tmp/openunison-values.yaml"
echo -e "*******************************************************************************************************************"
tput setaf 3

export hostip=$(hostname  -I | cut -f1 -d' ' | sed 's/[.]/-/g')


sed "s/IPADDR/$hostip/g" < ./openunison-values-impersonation.yaml  > /tmp/openunison-values.yaml

tput setaf 5
echo -e "\n \n*******************************************************************************************************************"
echo -e "Deploying Orchestra"
echo -e "*******************************************************************************************************************"
tput setaf 3

echo -n 'start123' > /tmp/ldaps
/tmp/ouctl install-auth-portal -s /tmp/ldaps  -o $REPO_NAME/openunison-operator -c $REPO_NAME/orchestra -l $REPO_NAME/orchestra-login-portal /tmp/openunison-values.yaml

kubectl create -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
   name: ou-cluster-admins
subjects:
- kind: Group
  name: cn=k8s-cluster-admins,ou=Groups,DC=domain,DC=com
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io
EOF

tput setaf 7
echo -e "\n\n*******************************************************************************************************************"
echo -e "Openunison has been deployed"
echo -e "*******************************************************************************************************************\n\n"
tput setaf 2



