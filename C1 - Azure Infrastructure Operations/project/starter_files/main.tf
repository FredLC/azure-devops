# Copyright IBM Corp. 2014, 2025
# SPDX-License-Identifier: MPL-2.0

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "main" {
  name     = "${var.prefix}-resources"
  location = var.location

  tags = {
    environment = "Production"
  }
}

resource "azurerm_virtual_network" "main" {
  name                = "${var.prefix}-network"
  address_space       = ["10.0.0.0/22"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  tags = {
    environment = "Production"
  }
}

resource "azurerm_subnet" "internal" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_public_ip" "public_ip" {
  name                    = "public_ip"
  location                = azurerm_resource_group.main.location
  resource_group_name     = azurerm_resource_group.main.name
  allocation_method       = "Static"
  idle_timeout_in_minutes = 30

  tags = {
    environment = "Production"
  }
}

resource "azurerm_network_interface" "main" {
  count               = var.vm_count
  name                = "${var.prefix}-nic-${count.index + 1}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Dynamic"
  }

  tags = {
    environment = "Production"
  }
}

resource "azurerm_availability_set" "vm_set" {
  name                         = "${var.prefix}-vm-set"
  resource_group_name          = azurerm_resource_group.main.name
  location                     = azurerm_resource_group.main.location
  managed                      = true
  
  tags = {
    environment = "Production"
  }
}

data "azurerm_image" "server_image" {
  name                         = "server-image"
  resource_group_name          = azurerm_resource_group.main.name
}

resource "azurerm_linux_virtual_machine" "main" {
  count                           = var.vm_count
  name                            = "${var.prefix}-vm-${count.index + 1}"
  resource_group_name             = azurerm_resource_group.main.name
  location                        = azurerm_resource_group.main.location
  availability_set_id             = azurerm_availability_set.vm_set.id
  size                            = "Standard_D2s_v3"
  admin_username                  = var.admin_username
  admin_password                  = var.admin_password
  disable_password_authentication = false
  network_interface_ids = [
    azurerm_network_interface.main[count.index].id,
  ]

  source_image_id = data.azurerm_image.server_image.id

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }

  tags = {
    environment = "Production"
  }
}

resource "azurerm_network_security_group" "nsg" {
  name                = "nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "allow-http-from-vnet"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-azure-load-balancer-probe"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "deny-all-inbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    environment = "Production"
  }
}

resource "azurerm_subnet_network_security_group_association" "nsg_association" {
  subnet_id                 = azurerm_subnet.internal.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_lb" "load_balancer" {
  name                = "${var.prefix}-lb"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "frontend-public"
    public_ip_address_id = azurerm_public_ip.public_ip.id
  }

  tags = {
    environment = "Production"
  }
}

resource "azurerm_lb_backend_address_pool" "backend_address_pool" {
  loadbalancer_id = azurerm_lb.load_balancer.id
  name            = "${var.prefix}-backend-servers"
}

resource "azurerm_lb_probe" "http" {
  loadbalancer_id     = azurerm_lb.load_balancer.id
  name                = "probe-http"
  protocol            = "Http"
  port                = 80
  request_path        = "/health"
  interval_in_seconds = 15
  number_of_probes    = 2
}

resource "azurerm_lb_rule" "http" {
  loadbalancer_id                = azurerm_lb.load_balancer.id
  name                           = "rule-http"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "frontend-public"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.backend_address_pool.id]
  probe_id                       = azurerm_lb_probe.http.id
}

resource "azurerm_network_interface_backend_address_pool_association" "nic_pool" {
  count                   = var.vm_count
  network_interface_id    = azurerm_network_interface.main[count.index].id
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.backend_address_pool.id
}