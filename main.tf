
locals {
  location            = "australiaeast"
  iothub_tier         = "B1"
  try_number          = "2"
  resource_group_name = "rg-iot-bug-repro-try-${local.try_number}"
}

resource "azurerm_resource_group" "rg_iothub" {
  name     = local.resource_group_name
  location = local.location
}

resource "azurerm_iothub" "iothub" {
  name                = "iot-repro-${local.try_number}"
  location            = local.location
  resource_group_name = azurerm_resource_group.rg_iothub.name

  sku {
    name     = local.iothub_tier
    capacity = 1
  }

  public_network_access_enabled = false
}

resource "azurerm_virtual_network" "vnet" {
  name                = "iot-repro-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = local.location
  resource_group_name = azurerm_resource_group.rg_iothub.name
}


resource "azurerm_subnet" "subnet_upstream" {
  name                                           = "iot-repro-subnet-upstream"
  resource_group_name                            = azurerm_resource_group.rg_iothub.name
  virtual_network_name                           = azurerm_virtual_network.vnet.name
  address_prefixes                               = ["10.0.1.0/24"]
  enforce_private_link_endpoint_network_policies = true
}

resource "azurerm_private_endpoint" "iothub_input_private_endpoint" {
  name                = "pep-in-iot-repro"
  location            = local.location
  resource_group_name = azurerm_resource_group.rg_iothub.name
  subnet_id           = azurerm_subnet.subnet_upstream.id

  private_service_connection {
    name                           = azurerm_iothub.iothub.name
    private_connection_resource_id = azurerm_iothub.iothub.id
    subresource_names              = ["iothub"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.iothub_dns.id]
  }
}

resource "azurerm_subnet" "subnet-downstream" {
  name                                           = "iot-repro-subnet-downstream"
  resource_group_name                            = azurerm_resource_group.rg_iothub.name
  virtual_network_name                           = azurerm_virtual_network.vnet.name
  address_prefixes                               = ["10.0.2.0/24"]
  enforce_private_link_endpoint_network_policies = true
}

resource "azurerm_private_endpoint" "iothub_downstream_private_endpoint" {
  name                = "pep-out-iot-repro"
  location            = local.location
  resource_group_name = azurerm_resource_group.rg_iothub.name
  subnet_id           = azurerm_subnet.subnet-downstream.id

  private_service_connection {
    name                           = azurerm_iothub.iothub.name
    private_connection_resource_id = azurerm_iothub.iothub.id
    subresource_names              = ["iotHub"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.iothub_dns.id]
  }
}

resource "azurerm_private_dns_zone" "iothub_dns" {
  name                = "privatelink.iothub.core.windows.net"
  resource_group_name = azurerm_resource_group.rg_iothub.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "iothub_dns_link" {
  name                  = "iothub_dns"
  resource_group_name   = azurerm_resource_group.rg_iothub.name
  private_dns_zone_name = azurerm_private_dns_zone.iothub_dns.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
}