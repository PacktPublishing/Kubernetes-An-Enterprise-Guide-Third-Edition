#!/bin/bash

# Note: The scripts provided in this repo are provided with a best effort to create a single Kubeadm cluster that can be used
#       to test K8GB in your infrastructure.  The decision to use a single node cluster was to limit any resource requirements
#       for readers.  You will need at least two Kubeadm clusters, and a access to your main DNS server to create the K8GB Zone
#       and the edgeDNS servers in the main DNS Zone.
#
#       This script is only meant to be used to test K8GB - since we only have a single node cluster, we need to remove the
#       noSchedule taint from the node to run other workloads like NGINX and K8GB.

clear
tput setaf 6
echo -e "\n \n*******************************************************************************************************************"
echo -e "Creating Kubeadm Cluster"
echo -e "*******************************************************************************************************************"
tput setaf 3

# Enable Bridge
tput setaf 6
echo -e "\n \n*******************************************************************************************************************"
echo -e "Step 1: Enabling Bridging and Enabling Forwarding"
echo -e "*******************************************************************************************************************"
tput setaf 3

cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
br_netfilter
EOF

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sudo sysctl --system
echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward

tput setaf 6
echo -e "\n \n*******************************************************************************************************************"
echo -e "Step 2: Downloading and Deploy ContainerD and Kubeadm - Cluster Version 1.32"
echo -e "*******************************************************************************************************************"
tput setaf 3
sudo apt install -y curl gnupg2 software-properties-common apt-transport-https ca-certificates

sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmour -o /etc/apt/trusted.gpg.d/containerd.gpg
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

sudo apt update && sudo apt install containerd.io -y

containerd config default | sudo tee /etc/containerd/config.toml >/dev/null 2>&1
sudo sed -i -e 's/SystemdCgroup \= false/SystemdCgroup \= true/g' -i -e 's/registry.k8s.io\/pause:3.8/registry.k8s.io\/pause:3.10/g' /etc/containerd/config.toml

sudo systemctl restart containerd

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/k8s.gpg

echo 'deb [signed-by=/etc/apt/keyrings/k8s.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' | sudo tee /etc/apt/sources.list.d/k8s.list

sudo apt update
sudo apt install kubelet kubeadm kubectl -y

sudo systemctl enable kubelet
sudo systemctl start kubelet

tput setaf 3
echo -e "\n \n*******************************************************************************************************************"
echo -e "Step 4: Disabling the Hosts swap file"
echo -e "*******************************************************************************************************************"
tput setaf 3

sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

tput setaf 6
echo -e "\n \n*******************************************************************************************************************"
echo -e "Step 5: Creating Kubeadm Single node cluster using a POD CIDR of 10.240.0.0/16, and Removing noschedule taint"
echo -e "*******************************************************************************************************************"
tput setaf 3

sudo kubeadm init --pod-network-cidr=10.240.0.0/16

# Copy kube config to users home
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
kubectl taint node --all node-role.kubernetes.io/control-plane-

tput setaf 6
echo -e "\n \n*******************************************************************************************************************"
echo -e "Step 6: Downloading and Installing HELM"
echo -e "*******************************************************************************************************************"
tput setaf 3

curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh

tput setaf 6
echo -e "\n \n*******************************************************************************************************************"
echo -e "Step 7: Download the  Cilium Helm Chart and Deploy from Local Charts"
echo -e "*******************************************************************************************************************"
tput setaf 3
curl -LO https://github.com/cilium/cilium/archive/main.tar.gz
tar xzf main.tar.gz
cd cilium-main/install/kubernetes

helm install cilium ./cilium --namespace kube-system
cd ~/Kubernetes-An-Enterprise-Guide-Third-Edition/chapter5/k8gb-example/kubeadm

tput setaf 6
echo -e "\n \n*******************************************************************************************************************"
echo -e "Step 8: Installing NGINX Ingress Controller Using Helm"
echo -e "*******************************************************************************************************************"
tput setaf 3

#kubectl apply -f nginx-deploy.yaml
kubectl create ns ingress-nginx
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm install ingress-nginx ingress-nginx/ingress-nginx --namespace ingress-nginx

tput setaf 6
echo -e "\n \n*******************************************************************************************************************"
echo -e "Kubeadm Cluster creation completed..."
echo -e "*******************************************************************************************************************/n"
tput setaf 3
