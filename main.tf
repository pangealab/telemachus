# Create Unique Resource Group Name
resource "random_pet" "rg-name" {
  length = 1
}

# Create Resource Group
resource "azurerm_resource_group" "rg" {
  name = "telemachus-${random_pet.rg-name.id}-rg"
  location  = var.resource_group_location
}

# Create virtual network
resource "azurerm_virtual_network" "telemachus-vnet" {
  name                = "telemachus-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Create subnet
resource "azurerm_subnet" "telemachus-subnet" {
  name                 = "telemachus-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.telemachus-vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Create public IPs
resource "azurerm_public_ip" "telemachus-pip" {
  name                = "telemachus-pip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Dynamic"
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "telemachus-nsg" {
  name                = "telemachus-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefixes    = ["165.225.0.0/17","137.83.128.0/18","165.225.192.0/18","104.129.192.0/20","185.46.212.0/22","199.168.148.0/22","209.51.184.0/26","213.152.228.0/24","216.218.133.192/26","216.52.207.64/26","27.251.211.238/32","64.74.126.64/26","70.39.159.0/24","72.52.96.0/26","8.25.203.0/24","89.167.131.0/24","136.226.0.0/16","147.161.128.0/17"]
    destination_address_prefix = "*"
  }
}

# Create network interface
resource "azurerm_network_interface" "telemachus-nic" {
  name                = "telemachus-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  ip_configuration {
    name                          = "telemachus-nic-config"
    subnet_id                     = azurerm_subnet.telemachus-subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.telemachus-pip.id
  }
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "example" {
  network_interface_id      = azurerm_network_interface.telemachus-nic.id
  network_security_group_id = azurerm_network_security_group.telemachus-nsg.id
}

# Generate random text for a unique storage account name
resource "random_id" "randomId" {
  keepers = {
    # Generate a new ID only when a new resource group is defined
    resource_group = azurerm_resource_group.rg.name
  }
  byte_length = 8
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "telemachus-storage" {
  name                     = "diag${random_id.randomId.hex}"
  location                 = azurerm_resource_group.rg.location
  resource_group_name      = azurerm_resource_group.rg.name
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# Create (and display) an SSH key
# resource "tls_private_key" "example_ssh" {
#   algorithm = "RSA"
#   rsa_bits  = 4096
# }

# Create virtual machine
resource "azurerm_linux_virtual_machine" "telemachus-vm" {
  name                  = "telemachus-vm"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.telemachus-nic.id]
  size                  = "Standard_DS1_v2"
  os_disk {
    name                 = "telemachus-os"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
  computer_name                   = "telemachus-vm"
  admin_username                  = "azureuser"
  disable_password_authentication = true
  admin_ssh_key {
    username   = "azureuser"
    # public_key = tls_private_key.example_ssh.public_key_openssh
    public_key = file(var.public_key_path)
  }
  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.telemachus-storage.primary_blob_endpoint
  }
}