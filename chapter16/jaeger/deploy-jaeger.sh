

#helm install es ./es -n istio-system -f ./es/values.yaml


#kubectl create -f jaeger-operator.yaml -n istio-system

tput setaf 5
echo -e "\n*******************************************************************************************************************"
echo -e "Installing Certmanager"
echo -e "*******************************************************************************************************************"
tput setaf 2
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.6.3/cert-manager.yaml

while [[ $(kubectl get pods -l app.kubernetes.io/component=webhook -n cert-manager -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do
  echo "Waiting for Cert Manager Webhook to be running...."
  sleep 1
done

tput setaf 5
echo -e "\n*******************************************************************************************************************"
echo -e "Creating namespace observability for the Jaeger Operator"
echo -e "*******************************************************************************************************************"
tput setaf 2
kubectl create namespace observability
kubectl create -f https://github.com/jaegertracing/jaeger-operator/releases/download/v1.53.0/jaeger-operator.yaml -n observability

while [[ $(kubectl get pods -l name=jaeger-operator -n observability -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do 
  echo "Waiting for the Jaeger Operator to be running...."
  sleep 1
done


## Wait for operator to run
kubectl create -f jaeger.yaml -n istio-system

