# Cilium Cluster Creation  
This directory contains the files required to deploy a KinD cluster running Cilium as the cluster CNI.  
  
Please do not use this for the book exercises since they were created and tested against Calico.  We have added a Cilium deployment for any readers that want to create clusters quickly using Cilium instead of Cailco for development testing.  
  
While most of the srcipts should work with Cilium, we cannot offer any support if a script doesn't function as expected when using Cilium as your CNI.  

To create a Cilium Cluster, make sure that there are no other KinD clusters on the host and execute the ./create-cilium-cluster.sh script.  This will create a new cluster called cilium-cluster
