#!/bin/bash




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

vcluster connect myvcluster -n tenant1

echo "Deploying the Kubernetes Dashboard"

kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml

wget https://nexus.tremolo.io/repository/ouctl/ouctl-0.0.11-linux -O /tmp/ouctl
chmod +x /tmp/ouctl


echo "Generating helm chart values to /tmp/openunison-vcluster-values.yaml"

export hostip=$(hostname  -I | cut -f1 -d' ' | sed 's/[.]/-/g')


sed "s/IPADDR/$hostip/g" < ./openunison-values-vcluster.yaml  > /tmp/openunison-vcluster-values.yaml

echo "Deploying Orchestra"
/tmp/ouctl install-satelite -o $REPO_NAME/openunison-operator -c $REPO_NAME/orchestra -l $REPO_NAME/orchestra-login-portal /tmp/openunison-vcluster-values.yaml kind-cluster01 vcluster_myvcluster_tenant1_kind-cluster01

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



echo "OpenUnison is deployed to your vcluster!"