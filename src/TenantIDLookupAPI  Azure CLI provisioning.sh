RES_GROUP=aci-demo 
ACR=acrdemo2019
LOCATION=westeurope
DOCKERIMAGE=tenantidlookupapi
VNET=aci-demo-vnet
CONTAINERSUBNET=container-subnet
APPGWSUBNET=appgw-subnet
AKV=aciakvdemo
ACINAME=aci-api-demo
PUBLICIP=TenantIDLookupIPAddress
APPGW=aci-app-gw

# Create resource group: aci-demo  
az group create --name $RES_GROUP --location $LOCATION

# Create Azure Container Registry
az acr create --resource-group $RES_GROUP --name $ACR --sku Basic --location $LOCATION

# Enable admin access to ACR
az acr update --name $ACR --admin-enabled true

# Login to ACR
az acr login --name $ACR

# Tag local Docker image
docker tag $DOCKERIMAGE $ACR.azurecr.io/$DOCKERIMAGE

# Upload Docker image to ACR
docker push $ACR.azurecr.io/$DOCKERIMAGE

# Verify upload finished successfully
az acr repository show --name $ACR --image $DOCKERIMAGE

# Provision new VNET with an address range of 10.0.0.0/16 and one subnet for /24
az network vnet create 
    --name $VNET \
    --resource-group $RES_GROUP \
    --address-prefix 10.0.0.0/16 \
    --subnet-name $CONTAINERSUBNET \
    --subnet-prefix 10.0.0.0/24

# Provision another subnet in the same VNET for Application Gateway
az network vnet subnet create \
    --resource-group $RES_GROUP \
    --name $APPGWSUBNET \
    --vnet-name $VNET \
    --address-prefix 10.0.1.0/24

# Provision Azure Key Vault: aciakvdemo
az keyvault create --resource-group $RES_GROUP --name $AKV

# Provision service principal in Key Vault
az keyvault secret set \
  --vault-name $AKV \
  --name $ACR-pull-pwd \
  --value $(az ad sp create-for-rbac \
                --name http://$ACR-pull \
                --scopes $(az acr show --name $ACR --query id --output tsv) \
                --role acrpull \
                --query password \
                --output tsv)

# Provision appId for the service principal
az keyvault secret set \
    --vault-name $AKV \
    --name $ACR-pull-usr \
    --value $(az ad sp show --id http://$ACR-pull --query appId --output tsv)

# Provision container in ACI using our image, while binding it to our VNET and using the service principal for auth
ACR_LOGIN=$(az acr show --name $ACR --resource-group $RES_GROUP --query "loginServer" --output tsv)

az container create \
    --name $ACINAME \
    --resource-group $RES_GROUP \
    --image $ACR_LOGIN/$DOCKERIMAGE:latest \
    --registry-login-server $ACR_LOGIN \
    --registry-username $(az keyvault secret show --vault-name $AKV -n $ACR-pull-usr --query value -o tsv) \
    --registry-password $(az keyvault secret show --vault-name $AKV -n $ACR-pull-pwd --query value -o tsv) \
    --vnet $VNET \
    --vnet-address-prefix 10.0.0.0/16 \
    --subnet $CONTAINERSUBNET \
    --subnet-address-prefix 10.0.0.0/24

# Retrieve the private IP from the container once provisioned
CONTAINERIP=$(az container show --resource-group $RES_GROUP --name $ACINAME --output table)

# Provision Application Gateway's public IP
az network public-ip create --resource-group $RES_GROUP --name $PUBLICIP

# Provision Application Gateway
az network application-gateway create \
    --name $APPGW
    --location $LOCATION
    --resource-group $RES_GROUP 
    --capacity 2 
    --public-ip-address $PUBLICIP 
    --vnet-name $VNET 
    --subnet $APPGWSUBNET 
    --servers $CONTAINERIP 
    --sku Standard_Small