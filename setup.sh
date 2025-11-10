#!/bin/bash

RgName="LB-FrontendAccess-Scenario"
Location="australiaeast"

az group create --location $Location --name $RgName

date
# Create a Virtual Network for the VMs
echo '------------------------------------------'
echo 'Creating a Virtual Network for the VMs'
az network vnet create \
    --resource-group $RgName \
    --location $Location \
    --name bePortalVnet \
    --subnet-name bePortalSubnet 

# Create a Network Security Group
echo '------------------------------------------'
echo 'Creating a Network Security Group'
az network nsg create \
    --resource-group $RgName \
    --name bePortalNSG \
    --location $Location

az network nsg rule create -g $RgName --nsg-name bePortalNSG -n AllowAll80 --priority 101 \
                            --source-address-prefixes 'Internet' --source-port-ranges '*' \
                            --destination-address-prefixes '*' --destination-port-ranges 80 --access Allow \
                            --protocol Tcp --description "Allow all port 80 traffic"

az network nsg rule create -g $RgName --nsg-name bePortalNSG -n AllowSSH --priority 100 \
                            --source-address-prefixes 'Internet' --source-port-ranges '*' \
                            --destination-address-prefixes '*' --destination-port-ranges 22 --access Allow \
                            --protocol Tcp --description "Allow SSH"

az network nsg rule create -g $RgName --nsg-name bePortalNSG -n AllowRDP --priority 102 \
                            --source-address-prefixes 'Internet' --source-port-ranges '*' \
                            --destination-address-prefixes '*' --destination-port-ranges 3389 --access Allow \
                            --protocol Tcp --description "Allow RDP"


# Create the NICs with associated public IPs
for i in `seq 1 2`; do
  echo '------------------------------------------'
  echo 'Creating webPublicIP'$i
  az network public-ip create \
    --resource-group $RgName \
    --name webPublicIP$i \
    --location $Location \
    --sku Standard
  echo 'Creating webNic'$i
  az network nic create \
    --resource-group $RgName \
    --name webNic$i \
    --vnet-name bePortalVnet \
    --subnet bePortalSubnet \
    --network-security-group bePortalNSG \
    --public-ip-address webPublicIP$i \
    --location $Location
done

# Create an availability set
echo '------------------------------------------'
echo 'Creating an availability set'
az vm availability-set create \
    --resource-group $RgName \
    --name portalAvailabilitySet

# Create 2 VM's from a template
for i in `seq 1 2`; do
    echo '------------------------------------------'
    echo 'Creating webVM'$i
    az vm create \
        --size Standard_DS1_v2
		--admin-username azureuser \
        --resource-group $RgName \
        --name webVM$i \
        --nics webNic$i \
        --location $Location \
        --image Ubuntu2204 \
        --availability-set portalAvailabilitySet \
        --generate-ssh-keys \
        --custom-data cloud-init.txt
done

# Create TestVM NIC with associated public IP
  echo '------------------------------------------'
  echo 'Creating testVMPublicIP'
  az network public-ip create \
    --resource-group $RgName \
    --name testVMPublicIP \
    --location $Location \
    --sku Standard
  echo 'Creating testVMNic'
  az network nic create \
    --resource-group $RgName \
    --name testVMNic \
    --vnet-name bePortalVnet \
    --subnet bePortalSubnet \
    --network-security-group bePortalNSG \
    --public-ip-address testVMPublicIP \
    --location $Location

    echo 'Creating testVM'
    az vm create \
        --size Standard_DS1_v2
		--admin-username azureuser \
        --resource-group $RgName \
        --name testVM \
        --nics testVMNic \
        --location $Location \
        --image MicrosoftWindowsServer:WindowsServer:2019-Datacenter:latest \
        --availability-set portalAvailabilitySet \
        --generate-ssh-keys


# Done
echo '--------------------------------------------------------'
echo '             VM Setup Completed'
echo '--------------------------------------------------------'

echo '--------------------------------------------------------'
echo '             Starting Load Balancer Deploy'
echo '--------------------------------------------------------'


   az network lb create \
      --resource-group $RgName \
      --name myLoadBalancer \
      --frontend-ip-name myFrontEndPool \
      --backend-pool-name myBackEndPool \
      --sku Standard

  az network lb probe create \
     --resource-group $RgName \
     --lb-name myLoadBalancer \
     --name myHealthProbe \
     --protocol tcp \
     --port 80

  az network lb rule create \
      --resource-group $RgName \
      --lb-name myLoadBalancer \
      --name myHTTPRule \
      --protocol tcp \
      --frontend-port 80 \
      --backend-port 80 \
      --frontend-ip-name myFrontEndPool \
      --backend-pool-name myBackEndPool

  az network nic ip-config update \
      --resource-group $RgName \
      --nic-name webNic1 \
      --name ipconfig1 \
      --lb-name myLoadBalancer \
      --lb-address-pools myBackEndPool

  az network nic ip-config update \
      --resource-group $RgName \
      --nic-name webNic2 \
      --name ipconfig1 \
      --lb-name myLoadBalancer \
      --lb-address-pools myBackEndPool

  # az network public-ip show \
      # --resource-group $RgName \
      # --name myPublicIP \
      # --query [ipAddress] \
      # --output tsv

# echo '--------------------------------------------------------'
# echo '  Load balancer deployed to the IP Address shown above'
# echo '--------------------------------------------------------'










