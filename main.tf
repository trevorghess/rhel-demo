terraform {
  required_version = "> 0.11.0"
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  subscription_id = "${var.azure_sub_id}"
  tenant_id       = "${var.azure_tenant_id}"
}

# Create a resource group if it doesn’t exist
resource "azurerm_resource_group" "rg" {
  name     = "${var.application}-th-rg"
  location = "${var.azure_region}"

  tags {
    X-Contact     = "The Example Maintainer <maintainer@example.com>"
    X-Application = "rhel-hardening"
    X-ManagedBy   = "Terraform"
  }
}

# Create virtual network
resource "azurerm_virtual_network" "vnet" {
  name                = "${var.application}-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = "${var.azure_region}"
  resource_group_name = "${azurerm_resource_group.rg.name}"

  tags {
    X-Contact     = "The Example Maintainer <maintainer@example.com>"
    X-Application = "rhel-hardening"
    X-ManagedBy   = "Terraform"
  }
}

# Create subnet
resource "azurerm_subnet" "subnet" {
  name                 = "${var.application}-subnet"
  resource_group_name  = "${azurerm_resource_group.rg.name}"
  virtual_network_name = "${azurerm_virtual_network.vnet.name}"
  address_prefix       = "10.0.10.0/24"
}

resource "azurerm_public_ip" "vmsspip" {
  name                         = "${var.application}-vmsspip"
  location                     = "${var.azure_region}"
  resource_group_name          = "${azurerm_resource_group.rg.name}"
  public_ip_address_allocation = "static"

  tags {
    X-Contact     = "The Example Maintainer <maintainer@example.com>"
    X-Application = "rhel-hardening"
    X-ManagedBy   = "Terraform"
  }
}

resource "azurerm_lb" "vmss" {
  name                = "vmss-lb"
  location            = "${var.azure_region}"
  resource_group_name = "${azurerm_resource_group.rg.name}"

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = "${azurerm_public_ip.vmsspip.id}"
  }

  tags = {
    X-Contact     = "The Example Maintainer <maintainer@example.com>"
    X-Application = "rhel-hardening"
    X-ManagedBy   = "Terraform"
  }
}

resource "azurerm_lb_backend_address_pool" "bpepool" {
  resource_group_name = "${azurerm_resource_group.rg.name}"
  loadbalancer_id     = "${azurerm_lb.vmss.id}"
  name                = "BackEndAddressPool"
}

resource "azurerm_lb_probe" "vmss" {
  resource_group_name = "${azurerm_resource_group.rg.name}"
  loadbalancer_id     = "${azurerm_lb.vmss.id}"
  name                = "ssh-running-probe"
  port                = "${var.application_port}"
}

resource "azurerm_lb_rule" "lbnatrule" {
  resource_group_name            = "${azurerm_resource_group.rg.name}"
  loadbalancer_id                = "${azurerm_lb.vmss.id}"
  name                           = "http"
  protocol                       = "Tcp"
  frontend_port                  = "${var.lb_application_port}"
  backend_port                   = "${var.application_port}"
  backend_address_pool_id        = "${azurerm_lb_backend_address_pool.bpepool.id}"
  frontend_ip_configuration_name = "PublicIPAddress"
  probe_id                       = "${azurerm_lb_probe.vmss.id}"
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "sg" {
  name                = "${var.application}-sg"
  location            = "${var.azure_region}"
  resource_group_name = "${azurerm_resource_group.rg.name}"

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "8080"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8080"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "9631"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "9631"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "9638"
    priority                   = 1004
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "9638"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "27017"
    priority                   = 1005
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "27017"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "28017"
    priority                   = 1006
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "28017"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags {
    X-Contact     = "The Example Maintainer <maintainer@example.com>"
    X-Application = "rhel-hardening"
    X-ManagedBy   = "Terraform"
  }
}


# Generate random text for a unique storage account name
resource "random_id" "randomId" {
  keepers = {
    # Generate a new ID only when a new resource group is defined
    resource_group = "${azurerm_resource_group.rg.name}"
  }

  byte_length = 8
}


# Create web application instance scale set 
resource "azurerm_virtual_machine_scale_set" "vmss" {
  name                = "vmscaleset"
  location            = "${var.azure_region}"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  upgrade_policy_mode = "Manual"

  sku {
    name     = "Standard_DS1_v2"
    tier     = "Standard"
    capacity = "${var.vmss_capacity}"
  }

  storage_profile_image_reference {
    publisher = "RedHat"
    offer     = "RHEL"
    sku       = "7.3"
    version   = "latest"
  }

  storage_profile_os_disk {
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  storage_profile_data_disk {
    lun           = 0
    caching       = "ReadWrite"
    create_option = "Empty"
    disk_size_gb  = 10
  }

  os_profile {
    computer_name_prefix = "vmlab"
    admin_username       = "${var.azure_image_user}"
    admin_password       = "${var.azure_image_password}"
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }

  network_profile {
    name                      = "terraformnetworkprofile"
    primary                   = true
    network_security_group_id = "${azurerm_network_security_group.sg.id}"

    ip_configuration {
      name                                   = "IPConfiguration"
      subnet_id                              = "${azurerm_subnet.subnet.id}"
      load_balancer_backend_address_pool_ids = ["${azurerm_lb_backend_address_pool.bpepool.id}"]
    }
  }

  extension {
    name                 = "chef-extension"
    publisher            = "Chef.Bootstrap.WindowsAzure"
    type                 = "LinuxChefClient"
    type_handler_version = "1210.12"

    settings = <<SETTINGS
    {
      "bootstrap_options": {
        "chef_server_url": "https://thess-chef-d2t3.eastus.cloudapp.azure.com/organizations/hessco",
        "validation_client_name": "hessco-validator"
      },
      "runlist": "recipe[cis-rhel::default],recipe[rhel-audit::default]",
      "client_rb": "ssl_verify_mode :verify_none\n",  
      "validation_key_format": "plaintext",
      "chef_daemon_interval": "5",
      "daemon" : "service"
    }
  SETTINGS

    protected_settings = <<PROTECTEDSETTINGS
    {
      "validation_key": "-----BEGIN RSA PRIVATE KEY-----\nMIIEowIBAAKCAQEAy6Mp1BY73QSKjxS0lE8NCOciC7giROocOXF64xd5+ep1N6FH\nnt7zYFLBCAHidm62EqtxMZyeTzwzL1bxs64a+0UYPb8F9K2npo3TqT/5o/KGn+cC\naczy7ZpVm2ZY19lUOPsNWFf8xmehfEe73UEVFXYJ3NrrzlUX8gt/pcvYA6DJl3TM\n2S2IdYEoLH16qStiieQIERka5+mHb/2IiQ515C78ElgDxpkHbu5YLw3Gwf1vql0l\nvOgA0bo1uyKj5+3pCkquMZWHK+78NW/HZPlMwAZskSOq2M2zLNlUlr2PDHw2Aha2\nAN/+5WrpGSCo+mqFfVkfXGaMyPijvHJYOZQktwIDAQABAoIBAFg4T566IyUVGpHx\n/mlh9duthmpdUztX0PJx3zMSsJ08nZuEG2sQW4+XSlkVt+5m+CoOa/N6Tns1MVeI\n6x1UiAvjWyUk5Iej08WsG85vEM+d+gS8J6d+Sp/1BLFWHZclZ/9ng9iKBdBOhP86\ndIDd+Sxa/trXXOD+rGkH4j0JmoO3Fft6BrePHJ0+uMWLGhkN15QhOMMFy+m+OSpM\nDGVwwpylEYYBh2fVGGI2s/RAYZib23YdjgbUaHCnPkDwcx8A5M8FZ2NtqKaeGhj6\nUwwZmyAw3Ldz83jWG1ZIBda9AaXgUmPFNEDThjmTgaR/RdF5dlP+tFKGYAvtga8W\nM3KSJkECgYEA+eOJjLXQwj0ANtBvEHyiuyIEOdE8u4rG8ydeAuha5B7F6OTTvPUn\nwEGdI+FyGinRbHuSYQ8ZpgZBZjE3mCBrl9aSkiL5rkjT251Dr/U8EW06iu4vEsFW\nCnPNAc5yHbqcKDO4rwjD26J4XZyUHeWc5wWGnpLak1IWSwwWIj1sXmUCgYEA0J4Q\nBMIljg/c265lsusujdpXkw/nx3S0C5ZDa4CORrQ+5MTAh/Ej8xOAd8sCH1ld9sIU\nFxZggLDuCWNEPOgmK0LGaAFvYGLv11DK9ti5DhRwAwgB/AZbj8wiEgSk9MrTEU3C\nANsK1Zm1M+rCjM5DfHG3vSbKWKjACF0MMUoUpusCgYA+9ZUyXpy6U6Q6K0nQXZai\nj2+BIbaricuWd9S35tL/psE2bHDsqtfZGK7+205kSST6sCexTJypt+nCVaQsL/7r\nwqQrLaS6xJ6cNoNXUfJQcbTOTDSQBSYofASq79jQpLOzbVSaxRqTu9uXuluXLMLb\ncgj46wcnFweG4QSym8cyAQKBgFIq/5owMgSLYO0x+qKHGVYL+tRUvnEEGWo67CEq\niF923RLUIBUrOIKkWsRUNGjOlUD83lbdnHLzvT37WEQ5F9eQPH94mTq4nUkMbHTf\nlbvi9t9qxwVSJ7wypfS82ZAFVy8IlnIp1FGfcgyZ2bkGAPTCAaHB5o8XIFPq+kNr\nr0izAoGBAKqEBkKPzWuR+uslOmqXH3uup8Sb+LJtHqw60RgvXLePnvLNiowgaVOn\nEkJignZI16P2LeOuQKDc/hjZCEhHJ/OOaqFtYJjxR3Hc3ROHBenPshAkGrcIm0jd\njnNouUfHBBKXjoYSIfLTkipM1yrjpmzOf13lJTW/8EcJxEEFvk/o\n-----END RSA PRIVATE KEY-----"
    }
  PROTECTEDSETTINGS
  }

  tags = {
    X-Contact     = "The Example Maintainer <maintainer@example.com>"
    X-Application = "rhel-hardening"
    X-ManagedBy   = "Terraform"
  }
}
