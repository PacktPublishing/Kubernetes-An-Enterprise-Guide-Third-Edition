#!/bin/bash
clear

# We need to increase the inotify resources for the host or the deployment of 6 nodes may fail.
# This is a temporary adjustment, if you want it to be permanent, add the same two lines to your /etc/sysctl.conf
tput setaf 5
echo -e "\n*******************************************************************************************************************"
echo -e "Increasing inotify resources"
echo -e "*******************************************************************************************************************"
tput setaf 2

sudo sysctl fs.inotify.max_user_watches=524288
sudo sysctl fs.inotify.max_user_instances=512

# This will find the IP address for each of the worker nodes.  Note that the worker nodes must be names cluster01-worker and
# a number.  This should be done by default if you followed the directions to create the multi-node cluster in the book.
tput setaf 5
echo -e "\n*******************************************************************************************************************"
echo -e "Collecting the IP addresses for the worker nodes"
echo -e "*******************************************************************************************************************"
tput setaf 2

worker1=$(docker inspect --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$@" cluster01-worker)
worker2=$(docker inspect --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$@" cluster01-worker2)
worker3=$(docker inspect --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$@" cluster01-worker3)

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
 option httpchk GET /healthz
 mode tcp
 server worker $worker1:443 check port 80
 server worker2 $worker2:443 check port 80
 server worker3 $worker3:443 check port 80

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
docker run --name HAProxy-workers-lb --network $KIND_NETWORK -d -p 80:80 -p 443:443 -v ~/HAProxy:/usr/local/etc/HAProxy:ro haproxy -f /usr/local/etc/HAProxy/HAProxy.cfg
