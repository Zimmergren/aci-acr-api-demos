# Scripts from blog post
Blog article: https://zimmergren.net/azure-container-instances-dotnet-core-api-application-gateway-https/

The following scripts are used in the blog post, in the correct order top-down.

## Azure CLI

### Login to your azure subscription

```
az login
```

### Select the correct subscription

```
az account list
az account set --subscription <GUID>
```

### Create Resource Group

```
az group create -n aci-demo -l westeurope
```

### Create ACR

```
az acr create --resource-group aci-demo --name acrdemo2019 --sku Basic --location westeurope
```

### Publish to ACR

```
az acr login --name acrdemo2019
```

### Tag and Push docker image to ACR

```
docker tag tenantidlookupapi acrdemo2019.azurecr.io/tenantidlookupapi
docker push acrdemo2019.azurecr.io/tenantidlookupapi
```

### Show image in repository

```
az acr repository show --name acrdemo2019 --image tenantidlookupapi
```

### Provision VNET

```
az network vnet create --name aci-demo-vnet --resource-group aci-demo --address-prefix 10.0.0.0/16  --subnet-name container-subnet --subnet-prefix 10.0.0.0/24
```

### Provision Key Vault

```
az keyvault create --resource-group aci-demo --name aciakvdemo
```

## Bash/Azure Shell commands

### Create service principal and secret for Key Vault

```sh
AKV_NAME=aciakvdemo
ACR_NAME=acrdemo2019 

az keyvault secret set \
  --vault-name $AKV_NAME \
  --name $ACR_NAME-pull-pwd \
  --value $(az ad sp create-for-rbac \
                --name http://$ACR_NAME-pull \
                --scopes $(az acr show --name $ACR_NAME --query id --output tsv) \
                --role acrpull \
                --query password \
                --output tsv)

```

### Store App Id (Client Id) in Key Vault

```sh
az keyvault secret set \
    --vault-name $AKV_NAME \
    --name $ACR_NAME-pull-usr \
    --value $(az ad sp show --id http://$ACR_NAME-pull --query appId --output tsv)
```

### Provision ACI

```sh
RES_GROUP=aci-demo
ACR_NAME=acrdemo2019
ACR_LOGIN_SERVER=$(az acr show --name $ACR_NAME --resource-group $RES_GROUP --query "loginServer" --output tsv)

az container create \
    --name aci-api-demo \
    --resource-group $RES_GROUP \
    --image $ACR_LOGIN_SERVER/tenantidlookupapi:latest \
    --registry-login-server $ACR_LOGIN_SERVER \
    --registry-username $(az keyvault secret show --vault-name $AKV_NAME -n $ACR_NAME-pull-usr --query value -o tsv) \
    --registry-password $(az keyvault secret show --vault-name $AKV_NAME -n $ACR_NAME-pull-pwd --query value -o tsv) \
    --vnet aci-demo-vnet \
    --vnet-address-prefix 10.0.0.0/16 \
    --subnet container-subnet \
    --subnet-address-prefix 10.0.0.0/24
```

### Show ACI

```
az container show --resource-group aci-demo --name aci-api-demo --output table
```

### Provision Public IP Address

```
az network public-ip create --resource-group aci-demo --name TenantIDLookupIPAddress
```

### Create and Export PFX

Create:
```
openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 -keyout privateKey.key -out aciappgwcert.crt
```

Export:
```
openssl pkcs12 -export -out aciappgwcert.pfx -inkey privateKey.key -in aciappgwcert.crt
```

### Create Application Gateway

```
az network application-gateway create \
    --name aci-app-gw \
    --location westeurope \
    --resource-group aci-demo \
    --capacity 2 \
    --public-ip-address TenantIDLookupIPAddress \
    --vnet-name aci-demo-vnet \
    --subnet appgw-subnet \
    --servers 10.0.0.4 \
    --sku Standard_Small \
    --http-settings-cookie-based-affinity Disabled \
    --frontend-port 443 \
    --http-settings-port 80 \
    --http-settings-protocol Http \
    --cert-file c:\OpenSSL\aciappgwcert.pfx \
    --cert-password "Password1"
```