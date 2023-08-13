clear
tput setaf 6
echo -e "\n \n*******************************************************************************************************************"
echo -e "Deploying K8GB Using the Buffalo Values file"
echo -e "*******************************************************************************************************************"
tput setaf 3

helm repo add k8gb https://www.k8gb.io
helm repo update
helm -n k8gb upgrade -i k8gb k8gb/k8gb --create-namespace -f k8gb-buf-values.yaml

tput setaf 6
echo -e "\n \n*******************************************************************************************************************"
echo -e "Creating gslb record"
echo -e "*******************************************************************************************************************"
tput setaf 3
kubectl create -f k8gb-example-buf.yaml

tput setaf 6
echo -e "\n \n*******************************************************************************************************************"
echo -e "Deploying an example NGINX web server for the Buffalo Cluster"
echo -e "*******************************************************************************************************************"
tput setaf 3
kubectl create -f nginx-fe-buff.yaml

tput setaf 6
echo -e "\n \n*******************************************************************************************************************"
echo -e "Adding service to expose CoreDNS on both TCP/UDP port 53"
echo -e "*******************************************************************************************************************"
tput setaf 3
kubectl create -f coredns-dual-svc.yaml -n k8gb

tput setaf 6
echo -e "\n \n*******************************************************************************************************************"
echo -e "Deploying of K8GB and example application complete for the Buffalo cluster"
echo -e "*******************************************************************************************************************\n\n"
tput setaf 3

