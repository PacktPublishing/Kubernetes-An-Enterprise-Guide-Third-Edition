clear
tput setaf 6
echo -e "\n \n*******************************************************************************************************************"
echo -e "Deploying K8GB Using the NYC Values file"
echo -e "*******************************************************************************************************************"
tput setaf 3

kubectl create ns k8gb
helm repo add k8gb https://www.k8gb.io
helm repo update
helm install k8gb k8gb/k8gb -n k8gb -f k8gb-nyc-values.yaml

tput setaf 6
echo -e "\n \n*******************************************************************************************************************"
echo -e "Deploying an example NGINX web server for the NYC Cluster"
echo -e "*******************************************************************************************************************"
tput setaf 3
kubectl create -f nginx-fe-nyc.yaml

tput setaf 6
echo -e "\n \n*******************************************************************************************************************"
echo -e "Creating gslb record"
echo -e "*******************************************************************************************************************"
tput setaf 3
kubectl create -f k8gb-example-nyc.yaml

tput setaf 6
echo -e "\n \n*******************************************************************************************************************"
echo -e "Adding service to expose CoreDNS on both TCP/UDP port 53 and patching the Service to use a static loacBalancerIP"
echo -e "You will need to change the loadBalancerIP to your desired IP address for your own environment"
echo -e "*******************************************************************************************************************"
tput setaf 3
kubectl create -f coredns-dual-svc.yaml -n k8gb
# Change the IP below - this is assigned to the UDP/TCP CoreDNS that has been deployed by K8GB
kubectl patch svc k8gb-coredns-dual -n k8gb --type='merge' -p '{"spec":{"loadBalancerIP":"10.3.1.90"}}'



tput setaf 6
echo -e "\n \n*******************************************************************************************************************"
echo -e "Adding service to expose CoreDNS on both TCP/UDP port 53"
echo -e "*******************************************************************************************************************"
tput setaf 3
kubectl create -f coredns-dual-svc.yaml -n k8gb

tput setaf 6
echo -e "\n \n*******************************************************************************************************************"
echo -e "Deploying of K8GB and example application complete for the NYC cluster"
echo -e "*******************************************************************************************************************\n\n"
tput setaf 3

