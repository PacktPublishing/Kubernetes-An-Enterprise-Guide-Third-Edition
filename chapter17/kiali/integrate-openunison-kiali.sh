#!/bin/bash
clear

tput setaf 5
echo -e "\n \n*******************************************************************************************************************"
echo -e "Removing virtual services"
echo -e "*******************************************************************************************************************"
tput setaf 3

kubectl delete virtualservice grafana-vs -n istio-system
kubectl delete virtualservice jaeger-vs -n istio-system
kubectl delete virtualservice kiali-vs -n istio-system
kubectl delete virtualservice prometheus-vs -n istio-system

kubectl delete gateway grafana-gateway -n istio-system
kubectl delete gateway kiali-gateway -n istio-system

tput setaf 5
echo -e "\n \n*******************************************************************************************************************"
echo -e "Update Grafana for reverse proxy authentication"
echo -e "*******************************************************************************************************************"
tput setaf 3

kubectl apply -f grafana-deployment.yaml -n istio-system

kubectl delete pods -l app=grafana -n istio-system

tput setaf 5
echo -e "\n \n*******************************************************************************************************************"
echo -e "Update Kiali for reverse proxy authentication"
echo -e "*******************************************************************************************************************"
tput setaf 3

export hostip=$(hostname  -I | cut -f1 -d' ' | sed 's/[.]/-/g')
helm upgrade --namespace istio-system --set auth.strategy="header" --repo https://kiali.org/helm-charts kiali-server kiali-server --set external_services.prometheus.url=http://Prometheus:9090 --set external_services.tracing.in_cluster_url="http://tracing:80/jaeger" --set external_services.tracing.url="https://jaeger.apps.$hostip.nip.io" --set external_services.tracing.in_cluster_url="http://grafana:3000" --set external_services.grafana.url="https://grafana.apps.$hostip.nip.io"

kubectl delete pods -l app=kiali -n istio-system


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
echo -e "Update OpenUnison for reverse proxy authentication"
echo -e "*******************************************************************************************************************"
tput setaf 3

kubectl create -f - <<EOF
apiVersion: openunison.tremolo.io/v1
kind: ResultGroup
metadata:
  labels:
    app.kubernetes.io/component: openunison-resultgroups
    app.kubernetes.io/instance: openunison-orchestra-login-portal
    app.kubernetes.io/name: openunison
    app.kubernetes.io/part-of: openunison
  name: grafana
  namespace: openunison
spec:
- resultType: header
  source: static
  value: X-WEBAUTH-GROUPS=Admin
- resultType: header
  source: user
  value: X-WEBAUTH-USER=uid
EOF

sed "s/IPADDR/$hostip/g" < ./openunison-values-impersonation.yaml  > /tmp/openunison-values.yaml
/tmp/ouctl install-auth-portal   -o $REPO_NAME/openunison-operator -c $REPO_NAME/orchestra -l $REPO_NAME/orchestra-login-portal /tmp/openunison-values.yaml