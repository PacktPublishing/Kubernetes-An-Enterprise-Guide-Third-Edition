# Single Node, Muliple KinD Cluster Configuration  
This excursion will create two KinD clusters on your host.  
  
To deploy multiple KinD clusters on a single host, you require multilpe IP addresses since you will need to open the same ports for each cluster, and one one IP address you can only assign a port once (so, you cannot have two containers running that want to listen to port 443).  Each port requires a unique socket, which is the IP address and the port, for example - 10.2.1.10:443.  
  
To automate this, we had to make some requirements (These will be explained in detail in the next sections):  
  
- Only supports Ubuntu 24.04 (Should also work on 22.04, havent had a chance to test).  
- (2) IP addresses that you can use to assign to the KinD clusters.  These should be on the same subnet as the main NIC in your host.  
- Enough drive space for the clusters and any workloads you will deploy to the clusters.  (Tough to estimate, but we suggest at least 100GB of free space)  
  
# Why Would you Want Mulitple Clusters?  
Having multiple clusters allow you to test more complex scenarios like K8GB, multi-cluster service mesh, back and restore testing, and more.  
The included script will expose ports 80, 443 and 53 on each cluster.  Since each has its own IP address, nip.io can be used for Ingress rules that will be unique to each cluster.  
Opening ports 80 and 443 allows Ingress to each cluster and port 53 is opened to test tools like K8GB using CoreDNS.  
  
# What if I want to add Extra Ports?  
If you have a requirement to open additional ports to either, or both, clusters, you can edit the portion of the script that create the KinD clusters.  
Each cluster has its own section in the script, the nyc cluster section is shown below.  
  
```
cat <<EOF | kind create cluster --name nyc --image kindest/node:v1.32.2@sha256:f226345927d7e348497136874b6d207e0b32cc52154ad8323129352923a3142f --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  apiServerAddress: "$NYC_IP"
  disableDefaultCNI: true
  apiServerPort: 6443
nodes:
- role: control-plane
- role: worker
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    listenAddress: "$NYC_IP"
  - containerPort: 443
    hostPort: 443
    listenAddress: "$NYC_IP"
  - containerPort: 53
    hostPort: 53
    listenAddress: "$NYC_IP"
EOF
```
  
If you want to add additinal ports to the worker node, you can add the port(s) you need using the same syntax already in the script.  Just add the additional containerPort, hostPort, and listenAddress before you execute the script.  
  
# Cluster Automation Process  
In the excursions/kind-multi-cluster directory, you will see the script that will automate the deployment of the two clusters.  We call the clusters nyc and buffalo - you can change the cluster names if you want to by editing the names in the script.  
  
## Execution Overview  
Execute the script with sudo:  
```
sudo ./kind-multi-cluster.sh
```
  
## Network Information and Entering the IP addresses for the Clusters  
  
The script will start and it will list all of the active NIC's in the host along with any assigned IP addresses.  In the example below, we have two NIC's, ens33 and ens37.  
  
```
Starting setup for multi-cluster KinD deployment...
Scanning available network interfaces...

Available Network Interfaces:
  → ens33 - 192.168.37.137/24
  → ens37 - No IP assigned

Enter the NIC to use: 
```
    
We want to add two virtual IP's to the ens33 NIC, so in the 'Enter the NIC to use:' prompt, we type ens33 and press enter.  You will need the IP addresses you want to use for this section - we are using 192.168.37.10 and 192.168.37.15  
  
You will then be asked to supply the IP address for the first cluster (nyc) and then the second cluster (buffao).  
  
```
Configuring virtual IP addresses for clusters...
Enter the first virtual IP (for NYC cluster): 192.168.37.10
Enter the second virtual IP (for Buffalo cluster): 192.168.37.15
```
    
After entering the second IP address and pressing enter, you will be asked to confirm the entries.  
  
```
Configuration Summary:
  → Selected NIC: ens33
  → NYC Cluster IP: 192.168.37.10
  → Buffalo Cluster IP: 192.168.37.15

Proceed with these settings? (y/n): y
```
  
If you're happy with the information, press y to continue to build the clusters, or press n to exit and start over.  
  
## Deployment of the New KinD Clusters  
With the IP's entered, the script will go create the two KinD clusters, each bound to a new virtual IP address on the NIC you selected.  
  
The first step is to create a new netpln configuration with the new virtual IP's.  You will see this information in the output, as shown below. 
   
```
Updating network configuration in /etc/netplan/01-netcfg.yaml...
Applying network settings...
Network configuration updated successfully.
```
    
The script will then apply the new netplan configuration so the IP address will be added to the NIC.  
   
The output you will see next will be the new KinD clusters being created.  
  
```
Creating NYC cluster...
Creating cluster "nyc" ...
 ✓ Ensuring node image (kindest/node:v1.30.0) 🖼
 ✓ Preparing nodes 📦 📦
 ✓ Writing configuration 📜
 ✓ Starting control-plane 🕹️
 ✓ Installing StorageClass 💾
 ✓ Joining worker nodes 🚜
Set kubectl context to "kind-nyc"
You can now use your cluster with:

kubectl cluster-info --context kind-nyc

Thanks for using kind! 😊
NYC cluster created successfully.

Creating Buffalo cluster...
Creating cluster "buffalo" ...
 ✓ Ensuring node image (kindest/node:v1.30.0) 🖼
 ✓ Preparing nodes 📦 📦
 ✓ Writing configuration 📜
 ✓ Starting control-plane 🕹️
 ✓ Installing StorageClass 💾
 ✓ Joining worker nodes 🚜
Set kubectl context to "kind-buffalo"
You can now use your cluster with:

kubectl cluster-info --context kind-buffalo

Not sure what to do next? 😅  Check out https://kind.sigs.k8s.io/docs/user/quick-start/
Buffalo cluster created successfully.

Exposing ports on both clusters...

KinD clusters NYC and Buffalo are fully set up!
Access them using: kubectl cluster-info --context kind-nyc or kind-buffalo
```
  
That's it, you should have two clusters running on the Host now.  
  
# Verify the Clusters have Been Created  
You can do this a few ways, the quick simple method would be to execute a docker ps
```
docker ps
```
  
Which will output something similar to what you se below:  
```
CONTAINER ID   IMAGE                  COMMAND                  CREATED          STATUS          PORTS                                                                            NAMES
836b2ed41793   kindest/node:v1.29.2   "/usr/local/bin/entr…"   23 minutes ago   Up 23 minutes   192.168.37.15:53->53/tcp, 192.168.37.15:80->80/tcp, 192.168.37.15:443->443/tcp   buffalo-worker
deb2b5b98f71   kindest/node:v1.29.2   "/usr/local/bin/entr…"   23 minutes ago   Up 23 minutes   192.168.37.15:6443->6443/tcp                                                     buffalo-control-plane
105f34aeee16   kindest/node:v1.29.2   "/usr/local/bin/entr…"   23 minutes ago   Up 23 minutes   192.168.37.10:53->53/tcp, 192.168.37.10:80->80/tcp, 192.168.37.10:443->443/tcp   nyc-worker
41f070bbaa74   kindest/node:v1.29.2   "/usr/local/bin/entr…"   23 minutes ago   Up 23 minutes   192.168.37.10:6443->6443/tcp                                                     nyc-control-plane
```
  
You will see that each clusters control plane node and worker node are bound to the matching virtual IP's that were entered.  
  
# Check the Kubernetes Config file for Contexts  
Now that you have two clusters on a single host, you will need to change contexts between the clusters as you deploy workloads to each.  
To verify the contexts have been created, execute a kubectl config get-contexts command.  
```
kubectl config get-contexts
```
  
The output should look something the example below.  
```
CURRENT   NAME           CLUSTER        AUTHINFO       NAMESPACE
*         kind-buffalo   kind-buffalo   kind-buffalo
          kind-nyc       kind-nyc       kind-nyc
```
The * shows the active context.  Using K8s contexts is out of scope from the book - it's covered in depth on the Kubernetes.io site.  However, to show our example, we will execute a few commands that you may find useful.  
  
## Verifying the Active Cluster and Changing the Context  
The buffalo cluster is our active cluster, so if we execite a kubectl get nodes, we should see Buffalo nodes.  
```
kubectl get nodes
```
  
Will show the nodes in the cluster.
  
```
NAME                    STATUS     ROLES           AGE   VERSION
buffalo-control-plane   NotReady   control-plane   29m   v1.29.2
buffalo-worker          NotReady   <none>          28m   v1.29.2
```
  
Now, we will use the Context to the nyc cluster using kubectl config use-context kind-nyc  
```
It will verify that the context has been changed.  
```
Switched to context "kind-nyc".
```
  
And finally, to verify the active cluster is the nyc cluster, we will look at the nodes using kubectl get nodes  
```
kubectl get nodes  
```
NAME                STATUS     ROLES           AGE   VERSION
nyc-control-plane   NotReady   control-plane   31m   v1.29.2
nyc-worker          NotReady   <none>          31m   v1.29.2
```
  
You now have two KinD Clusters running on your single host!   
