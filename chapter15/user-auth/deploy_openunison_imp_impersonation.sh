#!/bin/bash
clear

tput setaf 5
echo -e "\n \n*******************************************************************************************************************"
echo -e "Cleaning up kube-prometheus"
echo -e "*******************************************************************************************************************"
tput setaf 3

kubectl delete ingress -n monitoring --all

helm upgrade prometheus prometheus-community/kube-prometheus-stack -n monitoring -f ./prom-openunison-values.yaml


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
echo -e "Deploying cert-manager"
echo -e "*******************************************************************************************************************"
tput setaf 3

# deploy cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.12.0/cert-manager.yaml


# wait for the cert-manager to be running
while [[ $(kubectl get pods -l app=webhook -n cert-manager -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do echo "waiting for cert-manager pod" && sleep 1; done

kubectl create -f - <<EOF
apiVersion: v1
data:
  tls.crt: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSURFVENDQWZtZ0F3SUJBZ0lVYmtiS2ZRN29ldXJuVHpyeWdIL0dDS0kzNkUwd0RRWUpLb1pJaHZjTkFRRUwKQlFBd0dERVdNQlFHQTFVRUF3d05aVzUwWlhKd2NtbHpaUzFqWVRBZUZ3MHlNakV4TURjeE5EUTFNakphRncwegpNakV4TURReE5EUTFNakphTUJneEZqQVVCZ05WQkFNTURXVnVkR1Z5Y0hKcGMyVXRZMkV3Z2dFaU1BMEdDU3FHClNJYjNEUUVCQVFVQUE0SUJEd0F3Z2dFS0FvSUJBUUNucVZ3eVFvMjJyRzZuVVpjU2UvR21WZnI5MEt6Z3V4MDkKNDY4cFNTUWRwRHE5UlRRVU92ZkFUUEJXODF3QlJmUDEvcnlFaHNocnVBS2E5LzVoKzVCL3g4bmN4VFhwbThCNwp2RDdldHY4V3VyeUtQc0lMdWlkT0QwR1FTRVRvNzdBWE03RmZpUk9yMDFqN3c2UVB3dVB2QkpTcDNpa2lDL0RjCnZFNjZsdklFWE43ZFNnRGRkdnV2R1FORFdPWWxHWmhmNUZIVy81ZHJQSHVPOXp1eVVHK01NaTFpUCtSQk1QUmcKSWU2djhCcE9ncnNnZHRtWExhNFZNc1BNKzBYZkQwSDhjU2YvMkg2V1M0LzdEOEF1bG5QSW9LY1krRkxKUEFtMwpJVFI3L2w2UTBJUXVNU3c2QkxLYWZCRm5CVmNUUVNIN3lKZEFKNWdINFZZRHIyamtVWkwzQWdNQkFBR2pVekJSCk1CMEdBMVVkRGdRV0JCU2Y5RDVGS3dISUY3eFdxRi80OG4rci9SVFEzakFmQmdOVkhTTUVHREFXZ0JTZjlENUYKS3dISUY3eFdxRi80OG4rci9SVFEzakFQQmdOVkhSTUJBZjhFQlRBREFRSC9NQTBHQ1NxR1NJYjNEUUVCQ3dVQQpBNElCQVFCN1BsMjkrclJ2eHArVHhLT3RCZGRLeEhhRTJVRUxuYmlkaFUvMTZRbW51VmlCQVhidUVSSEF2Y0phCm5hb1plY0JVQVJ0aUxYT2poOTFBNkFvNVpET2RETllOUkNnTGI2czdDVVhSKzNLenZWRmNJVFRSdGtTTkxKMTUKZzRoallyQUtEWTFIM09zd1EvU3JoTG9GQndneGJJQ1F5eFNLaXQ0OURrK2V4c3puMUJFNzE2aWlJVmdZT0daTwp5SWF5ekJZdW1Gc3M0MGprbWhsbms1ZW5hYjhJTDRUcXBDZS9xYnZtNXdOaktaVVozamJsM2QxVWVtcVlOdVlWCmNFY1o0UXltQUJZS3k0VkUzVFJZUmJJZGV0NFY2dVlIRjVZUHlFRWlZMFRVZStYVVJaVkFtaU9jcmtqblVIT3gKMWJqelJxSlpMNVR3b0ZDZzVlZUR6dVk0WlRjYwotLS0tLUVORCBDRVJUSUZJQ0FURS0tLS0tCg==
  tls.key: LS0tLS1CRUdJTiBQUklWQVRFIEtFWS0tLS0tCk1JSUV2Z0lCQURBTkJna3Foa2lHOXcwQkFRRUZBQVNDQktnd2dnU2tBZ0VBQW9JQkFRQ25xVnd5UW8yMnJHNm4KVVpjU2UvR21WZnI5MEt6Z3V4MDk0NjhwU1NRZHBEcTlSVFFVT3ZmQVRQQlc4MXdCUmZQMS9yeUVoc2hydUFLYQo5LzVoKzVCL3g4bmN4VFhwbThCN3ZEN2V0djhXdXJ5S1BzSUx1aWRPRDBHUVNFVG83N0FYTTdGZmlST3IwMWo3Cnc2UVB3dVB2QkpTcDNpa2lDL0RjdkU2Nmx2SUVYTjdkU2dEZGR2dXZHUU5EV09ZbEdaaGY1RkhXLzVkclBIdU8KOXp1eVVHK01NaTFpUCtSQk1QUmdJZTZ2OEJwT2dyc2dkdG1YTGE0Vk1zUE0rMFhmRDBIOGNTZi8ySDZXUzQvNwpEOEF1bG5QSW9LY1krRkxKUEFtM0lUUjcvbDZRMElRdU1TdzZCTEthZkJGbkJWY1RRU0g3eUpkQUo1Z0g0VllECnIyamtVWkwzQWdNQkFBRUNnZ0VBRlcwb0RTYnRqcm9tbDFkdW83d1hPOEgzMjRGVU5wRnpGbyt4dU9oUi9KVWEKWDBuU3lBQnBNbUxOYkM5RVEzSzV6MmJkN0xSL2lkU2E4S0cweEF6WmdKcjdDZGhpSUJmNWdnRk5WT1VLQ3lZKwpKZzlkem1YY2ZyWDdFNnllQnk2LzBFSHVSRjZlUVowMjNWQ09vajBEMHNOQkdjYjhkcm9UN3F4YUJnVWkvMlRjClkvL1o1WGl3ZDFIb0pmaWxrMXI0SEZnNmJlQ3NtWnJDREJQcGdqK29vbGdFYzdxdkY4T3ErNDlZUjlJc1FLTTAKUGx5ZVdkdjlPZkg0MHRwVVZXQi8zd01kd3JFT0E2Z1MrZ3BCWEcrblQyUXNjTkZrSnRueWM0SFB5SlBQSkJtcQpYeXVhQjlIelJZQmI4d2w2cTFxUllKNVFDZVhibDhoTGZ2TCtHRzkwd1FLQmdRQzZaQXFMelRLMWs4c1c1TU5XCmYzQWthd3Ryd21LbERQY1JSUkRsTXFTTkwwY0tUelh4YVBMcXRZMDRZbmNiK2tvS3dJeXpXaTVrdzRJR1dnQXMKUXdVZ2Q5RnFFRnBEZHV6UDBxU2UvM3RBTWR6UEY2Q3dTeDk1UnpGNnBwQ01aV2ZKQ2dvWU5PZGppMU1tTS9rRwpyMFFDczJNZ0YrNzdzSW80NXBCN0FmTm9FUUtCZ1FEbVJyUnRHS29rVWlEWU9GVUZDbWs0T3kzbzJUMmJiaCs2ClUxWHZ4WmRMNnRPVHIrT1N5dlFXQ2VBaUpQZ1ZuYWhQS3Zmc1NuODQvN2QySDY4WTRvbzVxT0xDZHhRL1Z0clUKT2QxU2FqQ1Z4b3VSR2tvTjM2SmlBNXBKQTFuN2FuNHh1MStXcC9odTdQcGZsN1dFQllYRk9EbnJZZjV5OTBQSApBSVE3emR5U2h3S0JnUUNxZlZ1UUtPL2JXd2FIT0ZUY3g5Q2gzekFoTHpyZjBnNGtROUtDYzJKRXFod0crQkZWCmNqUFFNS1N1RUpMMmltZ3prWkNoZFRtK2ZYNXZwTjlIblQ0UlJzZk1ob3lwN1J3THRKZFR3RWpTblVsbVBDeUYKVlJIQzh6WDFCR3B2b1VuZmdFbGZmdlN2L3Y3ZGtPaVdEcmJjNlkwZ0RBUlRRRllPV2dlS0hHeXlvUUtCZ1FDZgozWkpBOHhDYnFwQzJ5MVRxN1BGalltSmE5d1o0TTVtL1J6K3YrQ016UjFHZmhFcWZqRnFzT2lycVNYUVp2Wnd0CmFnMDRjL2VpNEpURFl2ZXlkUU8xUi9RMVFXcERGczlRNnVNbDVpYll0RUFNZW8zUzErRHAzc3ByeWZIY1EzQmMKb2xLWVN3Q0VNZTBZRkVDbDZSZVhkWk53UUZYZ0JwMTlPSFNVK0RRYlhRS0JnRmRsZHFWcmJ5N1crVEF4dGdMZApQZzJTemo3NHUyMjlmTkZldktRZ0RXUHIzMUJOSitrTEFFRzVKRXlncXJSWDF0OHdCajhMUlh3ZnBPSXhUa2RnCmxEMkd2a3BFM0V0cDJKSDlKbEQ3OVVQc1htN0hDT2E0bjRrWmtINW1qWUY5YzhMSjh1MFJRdDNEQVRoaXJQaVkKWlZpMEhtWWNuVmp5L0RxNWRwc0tHU0FoCi0tLS0tRU5EIFBSSVZBVEUgS0VZLS0tLS0K
kind: Secret
metadata:
  name: root-ca
  namespace: cert-manager
type: kubernetes.io/tls
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  annotations:
    force: update
  name: enterprise-ca
spec:
  ca:
    secretName: root-ca
EOF

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


kubectl create -f ./grafana-result-group.yaml


tput setaf 7
echo -e "\n\n*******************************************************************************************************************"
echo -e "Enable OpenUnison Monitoring"
echo -e "*******************************************************************************************************************\n\n"
tput setaf 2

kubectl apply -f ./monitor-openunison.yaml

tput setaf 7
echo -e "\n\n*******************************************************************************************************************"
echo -e "Openunison has been deployed"
echo -e "*******************************************************************************************************************\n\n"
tput setaf 2



