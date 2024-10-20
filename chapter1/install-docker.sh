#!/bin/bash
clear

tput setaf 6
echo -e "\n \n*******************************************************************************************************************"
echo -e "Kubernetes: An Enterprise Guide - 3rd Edition Scripts"
echo -e "Chapter 1: Installing Docker"
echo -e "\n \nThis script will add passwordless SUDO to the currently logged in user, add all requirements to install Docker"
echo -e "\nIt will deploy VIM and Docker to the local machine and restart all services"
echo -e "*******************************************************************************************************************"

tput setaf 6
echo -e "\n \n*******************************************************************************************************************"
echo -e "Install jq"
echo -e "*******************************************************************************************************************"
sudo apt install jq -y

tput setaf 6
echo -e "\n \n*******************************************************************************************************************"
echo -e "To make this and future exercises easier, we will grant the currently logged on user, $USER, passwordless sudo"
echo -e "You will need to provide your password for the update, but after that, sudo commands will not require a password."
echo -e "*******************************************************************************************************************"
sudo echo "$USER ALL=(ALL:ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/kubernetes-book-nopwd-root-for-$USER

tput setaf 6
echo -e "\n \n*******************************************************************************************************************"
echo -e "Installing VIM"
echo -e "*******************************************************************************************************************"
tput setaf 2
sudo apt install vim -y

tput setaf 6
echo -e "\n \n*******************************************************************************************************************"
echo -e "Changing how Daemon restarts are handled by Ubuntu 22.04 by Default"
echo -e "*******************************************************************************************************************"
tput setaf 2
sed -i "/#\$nrconf{restart} = 'i';/s/.*/\$nrconf{restart} = 'a';/" /etc/needrestart/needrestart.conf

tput setaf 6
echo -e "\n \n*******************************************************************************************************************"
echo -e "Updating Repo and adding Docker repo apt-key"
echo -e "*******************************************************************************************************************"
tput setaf 2

sudo apt-get update -y
sudo apt-get install ca-certificates curl gnupg -y
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

tput setaf 6
echo -e "\n \n*******************************************************************************************************************"
echo -e "Adding Docker repo"
echo -e "*******************************************************************************************************************"
tput setaf 2
echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  "$(. /etc/os-release && if [ -n "$UBUNTU_CODENAME" ]; then echo "$UBUNTU_CODENAME"; else echo "$VERSION_CODENAME"; fi;)" stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update -y

tput setaf 6
echo -e "\n \n*******************************************************************************************************************"
echo -e "Installing Docker"
echo -e "*******************************************************************************************************************"
tput setaf 2
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y

tput setaf 6
echo -e "\n \n*******************************************************************************************************************"
echo -e "Enabling and Starting Docker"
echo -e "*******************************************************************************************************************"
tput setaf 2
sudo systemctl enable docker
sudo systemctl start docker

tput setaf 6
echo -e "\n \n*******************************************************************************************************************"
echo -e "Adding current user to Docker group"
echo -e "*******************************************************************************************************************"
tput setaf 2
sudo usermod -aG docker $USER

exec su -p $USER

