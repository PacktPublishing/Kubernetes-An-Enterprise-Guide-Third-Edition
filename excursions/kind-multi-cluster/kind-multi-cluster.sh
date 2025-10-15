#!/bin/bash

# Added as an Excursion for the book, Kubernetes: An Enterprise Guide, 3rd Edition - by Marc Boorshtein and Scott Surovich

# Define Colors to be Used for Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

clear

echo -e "${CYAN}"
cat << "EOF"
##########################################################################
#                                                                        #
#               Kind MultiCluster, Single Host Deployment                #
#                       One Host - Many Clusters!                        #
#                                                                        #
#                   Kubernetes Cluster Version 1.32.2                    #
#                                                                        #
##########################################################################
EOF
echo -e "${NC}"

echo -e "${YELLOW}Starting setup for multi-cluster KinD deployment...${NC}"
sleep 1

# Function to list available network interfaces
list_nics() {
    echo -e "${CYAN}Scanning available network interfaces...${NC}"
    sleep 1
    echo -e "\n${GREEN}Available Network Interfaces:${NC}"
    for nic in $(ip -o link show | awk -F': ' '{print $2}' | grep -E '^(eth|ens|eno|enp)'); do
        ip_info=$(ip -4 addr show "$nic" | grep -oP '(?<=inet\s)\d+\.\d+\.\d+\.\d+/\d+' || echo "No IP assigned")
        echo -e "${YELLOW}  → ${nic}${NC} - ${ip_info}"
    done
    echo ""
}

# List NICs and ask the user to select one
list_nics
read -p "Enter the NIC to use: " SELECTED_NIC

# Confirm NIC selection
if ! ip link show "$SELECTED_NIC" &>/dev/null; then
    echo -e "${RED}Invalid NIC selected. Exiting.${NC}"
    exit 1
fi

# Get virtual IP addresses for the clusters
echo -e "\n${CYAN}Configuring virtual IP addresses for clusters...${NC}"
read -p "Enter the first virtual IP (for NYC cluster): " NYC_IP
read -p "Enter the second virtual IP (for Buffalo cluster): " BUF_IP

# Confirm settings
echo -e "\n${GREEN}Configuration Summary:${NC}"
echo -e "  → Selected NIC: ${YELLOW}$SELECTED_NIC${NC}"
echo -e "  → NYC Cluster IP: ${YELLOW}$NYC_IP${NC}"
echo -e "  → Buffalo Cluster IP: ${YELLOW}$BUF_IP${NC}"
echo -e ""
read -p "Proceed with these settings? (y/n): " CONFIRM

if [[ "$CONFIRM" != "y" ]]; then
    echo -e "${RED}Exiting setup.${NC}"
    exit 1
fi

# Update Netplan configuration
NETPLAN_FILE="/etc/netplan/01-netcfg.yaml"
echo -e "\n${CYAN}Updating network configuration in $NETPLAN_FILE...${NC}"
sudo cp "$NETPLAN_FILE" "$NETPLAN_FILE.bak"

cat <<EOF | sudo tee "$NETPLAN_FILE" > /dev/null
network:
  version: 2
  ethernets:
    $SELECTED_NIC:
      dhcp4: no
      addresses:
        - $NYC_IP/24
        - $BUF_IP/24
      routes:
        - to: 0.0.0.0/0
          via: $(ip route | grep default | awk '{print $3}' | head -n 1)
EOF

# Set Permissions to avoid warnings in the output
sudo chmod 600 "$NETPLAN_FILE"

# Apply the new network configuration
echo -e "${YELLOW}Applying network settings...${NC}"
sudo netplan apply
sleep 2
echo -e "${GREEN}Network configuration updated successfully.${NC}\n"

# Install KinD if not installed
if ! command -v kind &> /dev/null; then
    echo -e "${YELLOW}KinD not found. Installing...${NC}"
    curl -Lo ./kind https://kind.sigs.k8s.io/dl/latest/kind-linux-amd64
    chmod +x ./kind
    sudo mv ./kind /usr/local/bin/kind
    echo -e "${GREEN}KinD installed successfully.${NC}\n"
else
    echo -e "${GREEN}KinD is already installed.${NC}\n"
fi

# Create NYC cluster
echo -e "${CYAN}Creating NYC cluster...${NC}"
sleep 1

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

echo -e "${GREEN}NYC cluster created successfully.${NC}\n"

# Create Buffalo cluster
echo -e "${CYAN}Creating Buffalo cluster...${NC}"
sleep 1

cat <<EOF | kind create cluster --name buffalo --image kindest/node:v1.32.2@sha256:f226345927d7e348497136874b6d207e0b32cc52154ad8323129352923a3142f --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  apiServerAddress: "$BUF_IP"
  disableDefaultCNI: true
  apiServerPort: 6443
nodes:
- role: control-plane
- role: worker
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    listenAddress: "$BUF_IP"
  - containerPort: 443
    hostPort: 443
    listenAddress: "$BUF_IP"
  - containerPort: 53
    hostPort: 53
    listenAddress: "$BUF_IP"
EOF

echo -e "${GREEN}Buffalo cluster created successfully.${NC}\n"
echo -e "\n${GREEN}KinD clusters NYC and Buffalo are fully set up!${NC}"
echo -e "${CYAN}Access them using: kubectl cluster-info --context kind-nyc or kind-buffalo${NC}\n\n"

