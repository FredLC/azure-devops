# Azure Infrastructure Operations Project: Deploying a scalable IaaS web server in Azure

### Introduction
This project serves as a starter to deploy servers on Microsoft Azure. It includes an Ubuntu server template and customizable Terraform infrastructure files.

### Getting Started
Clone this repository. Make sure you have all the following dependencies installed. You may need to run `az login` to log in to the Azure CLI. You can refer to this page for more detailed instructions: https://learn.microsoft.com/en-us/cli/azure/get-started-with-azure-cli?view=azure-cli-latest.

You may also need to run this command to install the Packer Azure plugin: `packer plugins install github.com/hashicorp/azure`

### Dependencies
1. Create an [Azure Account](https://portal.azure.com) 
2. Install the [Azure command line interface](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest)
3. Install [Packer](https://www.packer.io/downloads)
4. Install [Terraform](https://www.terraform.io/downloads.html)

### Instructions
1. FIrst, in Azure, go to Microsoft Entra ID and create an app registration. This is the service principal that will build and create your packer image in your Azure account.
2. Create a secret in your app registration.
3. Take note of the following information:
   - client_id: This is the id of your app registration
   - client_secret: The **value** of your secret
   - subscription_id: The easiest way to find this is by running: `az account show`
4. Make sure your service principal has sufficient permissions by assigning it the contributor role:
   ```
   az role assignment create \
     --assignee <client_id> \
     --role Contributor \
     --subscription <subscription_id>
   ```
5. Run the following command in the project directory:
   ```
   packer build \
     -var "client_id=<your-client-id>" \
     -var "client_secret=<your-client-secret>" \
     -var "subscription_id=<your-subscription-id>" \
     server.json
   ```

### Output
If the infrastructure was built without any errors, Terraform will output a success message. You will also get as an output the public IP address of the load balancer.

