# Install apparmor utilites in the kind cluster nodes
# Special thanks to Rahul Jadhav from Accuknox for the assistance on the requirements to enable Kubearmor on KinD
docker exec -it cluster01-worker bash -c "apt update && apt install apparmor-utils -y && systemctl restart containerd"
docker exec -it cluster01-control-plane bash -c "apt update && apt install apparmor-utils -y && systemctl restart containerd"

# Add calico-typha to Apparmor unconfined mode
kubectl patch deploy -n calico-system calico-typha --type=json -p='[{"op": "add", "path": "/spec/template/metadata/annotations/container.apparmor.security.beta.kubernetes.io~1calico-typha", "value": "unconfined"}]'

# Install Kubearmor using the karmor utility
karmor install

# Add Kubearmor-relay to Apparmor unconfined mode 
kubectl patch deploy -n $(kubectl get deploy -l kubearmor-app=kubearmor-relay -A -o custom-columns=:'{.metadata.namespace}',:'{.metadata.name}') --type=json -p='[{"op": "add", "path": "/spec/template/metadata/annotations/container.apparmor.security.beta.kubernetes.io~1kubearmor-relay-server", "value": "unconfined"}]'
