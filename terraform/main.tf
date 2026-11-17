# Random suffix makes the storage account name globally unique
resource "random_id" "suffix" {
  byte_length = 4
}

# Resource Group
resource "azurerm_resource_group" "lab" {
  name     = "rg-${var.prefix}-${var.environment}"
  location = var.location
  tags     = var.tags
}

resource "azurerm_storage_account" "lab" {
  #checkov:skip=CKV2_AZURE_1:Microsoft-managed keys are sufficient for a lab; CMK adds Key Vault cost and complexity
  #checkov:skip=CKV2_AZURE_33:Private endpoint requires a VNet; out of scope for this environment
  #checkov:skip=CKV_AZURE_206:LRS is acceptable for non-critical lab data; GRS doubles cost
  #checkov:skip=CKV_AZURE_33:No queues are used in this storage account
  #checkov:skip=CKV2_AZURE_40:Shared Key is still required by the Terraform provider for data-plane reads

  name                     = "${var.prefix}${random_id.suffix.hex}"
  resource_group_name      = azurerm_resource_group.lab.name
  location                 = azurerm_resource_group.lab.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"

  # Fixed: block public network access and anonymous blob access
  public_network_access_enabled   = false
  allow_nested_items_to_be_public = false

  # Fixed: soft delete for blobs and containers
  blob_properties {
    delete_retention_policy {
      days = 7
    }
    container_delete_retention_policy {
      days = 7
    }
  }

  # Fixed: SAS tokens expire after one day
  sas_policy {
    expiration_period = "01.00:00:00"
  }

  tags = var.tags
}
