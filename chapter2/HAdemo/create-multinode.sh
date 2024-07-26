#!/bin/bash
clear

# We need to increase the inotify resources for the host or the deployment of 6 nodes may fail.
# This is a temporary adjustment, if you want it to be permanent, add the same two lines to your /etc/sysctl.conf
tput setaf 5
echo -e "\n*******************************************************************************************************************"
echo -e "Increasing inotify resources"
echo -e "*******************************************************************************************************************"
tput setaf 3
sudo sysctl fs.inotify.max_user_watches=524288
sudo sysctl fs.inotify.max_user_instances=512

# Create KIND Cluster calle cluster01 using config cluster01-kind.yaml
# KinD will deploy a cluster using the v1.27.1 Image - This has been tested with all of the book exercises and any K8s version
# other than 1.27.1 may not work with all the book scripts due to any changes in K8s.
tput setaf 5
echo -e "\n \n*******************************************************************************************************************"
echo -e "Create KinD Cluster using cluster01-kind.yaml configuration - Using the v1.30 Image"
echo -e "*******************************************************************************************************************"
tput setaf 3
kind create cluster --name multinode --config multinode.yaml --image kindest/node:v1.30.0@sha256:047357ac0cfea04663786a612ba1eaba9702bef25227a794b52890dd8bcd692e

# Add a label to the worker node, ingress-ready=true.  The NGINX deployment will only deploy to nodes that have this label.

tput setaf 5
echo -e "\n \n*******************************************************************************************************************"
echo -e "Adding node labels for Ingress Controller to worker node"
echo -e "*******************************************************************************************************************"
tput setaf 3
kubectl label node multinode-worker ingress-ready=true
kubectl label node multinode-worker2 ingress-ready=true
kubectl label node multinode-worker3 ingress-ready=true

# Install Calico
# The Calico scripts have been downloaded and added to the GIT repo to maintain the best release to use with KinD
# The only changes to the scripts is the POD CIDR range we use which needs to match the range in the custom-resoures.yaml manifest.
#     ipPools:
#    - blockSize: 26
#      cidr: 10.240.0.0/16
# Of this doesnt match the CIDR range of the KinD cluster, Calico will fail to start.

echo -e "\n \n*******************************************************************************************************************"
echo -e "Install Calico from local file, using 10.240.0.0/16 as the pod CIDR"
echo -e "*******************************************************************************************************************"
tput setaf 3
kubectl create -f ../calico/tigera-operator.yaml
kubectl create -f ../calico/custom-resources.yaml

# Deploy NGINX
# This is a standard nginx-deployment manifest that has been downloaded to the book repo to maintain compatibility with the KiND
# version we use for the book.  Newer releases may work, but there is no guarantee.
tput setaf 5
echo -e "\n \n*******************************************************************************************************************"
echo -e "Install NGINX Ingress Controller"
echo -e "*******************************************************************************************************************"
tput setaf 3
kubectl create -f ../nginx-ingress/nginx-deploy.yaml

# This will find the IP address for each of the worker nodes.  Note that the worker nodes must be named multinode-worker and
# a number.
tput setaf 5
echo -e "\n*******************************************************************************************************************"
echo -e "Collecting the IP addresses for the worker nodes"
echo -e "*******************************************************************************************************************"
tput setaf 2

worker1=$(docker inspect --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$@" multinode-worker)
worker2=$(docker inspect --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$@" multinode-worker2)
worker3=$(docker inspect --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$@" multinode-worker3)

# Next, we will create a HAProxy directory to hold our configuration file
tput setaf 5
echo -e "\n*******************************************************************************************************************"
echo -e "Creating the HAProxy directory"
echo -e "*******************************************************************************************************************"
tput setaf 2

mkdir ~/HAProxy

# This will create the configuration file that we will use with the new HAProxy container
# Most of the configuration file is a standard HAProxy configuration.
tput setaf 5
echo -e "\n*******************************************************************************************************************"
echo -e "Creating the HAProxy configuration in the current users home folder in the HAProxy directory"
echo -e "*******************************************************************************************************************"
tput setaf 2

tee ~/HAProxy/HAProxy.cfg <<EOF
global
 log /dev/log local0
 log /dev/log local1 notice
 daemon

defaults
 log global
 mode tcp
 timeout connect 5000
 timeout client 50000
 timeout server 50000
frontend workers_https
 bind *:443
 mode tcp
 use_backend ingress_https
backend ingress_https
 option ssl-hello-chk 
 mode tcp
 server worker $worker1:443 check port 443
 server worker2 $worker2:443 check port 443
 server worker3 $worker3:443 check port 443

frontend stats
  bind *:8404
  mode http
  stats enable
  stats uri /
  stats refresh 10s
frontend workers_http
 bind *:80
 use_backend ingress_http
backend ingress_http
 mode http
 option httpchk GET /healthz
 server worker $worker1:80 check port 80
 server worker2 $worker2:80 check port 80
 server worker3 $worker3:80 check port 80

EOF

# Start the container using the configuration file that was created in the previous step.
tput setaf 5
echo -e "\n*******************************************************************************************************************"
echo -e "Starting HAProxy Docker container"
echo -e "*******************************************************************************************************************"
tput setaf 2

echo -e "Worker 1: " $worker1
echo -e "Worker 2: " $worker2
echo -e "Worker 3: " $worker3
tput setaf 2

echo -e "\n\n"


# get the kind network so we can run HAProxy on the same Docker network
KIND_NETWORK=$(docker network ls | grep kind | awk '{print $1}')

# Start the HAProxy Container for the Worker Nodes
docker run --name HAProxy-workers-lb --network $KIND_NETWORK -d -p 8404:8404 -p 80:80 -p 443:443 -v ~/HAProxy:/usr/local/etc/HAProxy:ro haproxy -f /usr/local/etc/HAProxy/HAProxy.cfg

