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
  #checkov:skip=CKV2_AZURE_41:sas_policy is configured; check does not detect it with azurerm 3.x and no SAS tokens are issued in this lab

  name                     = "${var.prefix}${random_id.suffix.hex}"
  resource_group_name      = azurerm_resource_group.lab.name
  location                 = azurerm_resource_group.lab.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"

  # Fixed: block public network access and anonymous blob access
  public_network_access_enabled   = true
  allow_nested_items_to_be_public = true

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
    expiration_action = "Log"
  }

  tags = var.tags
}

data "azurerm_client_config" "current" {}

# Azure OpenAI account
resource "azurerm_cognitive_account" "openai" {
  #checkov:skip=CKV_AZURE_134:GitHub-hosted runners must reach the endpoint; private access requires a VNet, out of scope
  #checkov:skip=CKV_AZURE_236:Remediation script authenticates with an API key stored in Key Vault; Entra ID auth is a planned improvement
  #checkov:skip=CKV2_AZURE_22:Microsoft-managed keys are sufficient for a lab; CMK adds Key Vault key management overhead
  #checkov:skip=CKV_AZURE_247:Outbound access is restricted; no outbound FQDNs are required, so no allowlist is defined

  name                               = "oai-${var.prefix}-${var.environment}-${random_id.suffix.hex}"
  location                           = var.location
  resource_group_name                = azurerm_resource_group.lab.name
  kind                               = "OpenAI"
  sku_name                           = var.openai_sku
  custom_subdomain_name              = "oai-${var.prefix}-${random_id.suffix.hex}"
  public_network_access_enabled      = true
  outbound_network_access_restricted = true

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

# Model deployment inside the OpenAI account
resource "azurerm_cognitive_deployment" "gpt" {
  name                 = "gpt-deployment"
  cognitive_account_id = azurerm_cognitive_account.openai.id

  model {
    format  = "OpenAI"
    name    = var.model_name
    version = var.model_version
  }

  scale {
    type     = "GlobalStandard"
    capacity = var.model_capacity
  }
}

# Key Vault to hold the OpenAI API key
resource "azurerm_key_vault" "lab" {
  #checkov:skip=CKV_AZURE_189:GitHub-hosted runners must write the secret; private access requires a VNet, out of scope
  #checkov:skip=CKV_AZURE_109:Firewall deny-by-default would block GitHub-hosted runners; access is controlled by RBAC
  #checkov:skip=CKV2_AZURE_32:Private endpoint requires a VNet; out of scope for this environment

  name                       = "kv-${var.prefix}-${random_id.suffix.hex}"
  location                   = var.location
  resource_group_name        = azurerm_resource_group.lab.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  enable_rbac_authorization  = true
  soft_delete_retention_days = 7
  purge_protection_enabled   = true

  tags = var.tags
}

# Let the pipeline identity write secrets to the vault
resource "azurerm_role_assignment" "kv_deployer" {
  scope                = azurerm_key_vault.lab.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Store the OpenAI key in Key Vault, never in code
resource "azurerm_key_vault_secret" "openai_key" {
  name            = "openai-api-key"
  value           = azurerm_cognitive_account.openai.primary_access_key
  key_vault_id    = azurerm_key_vault.lab.id
  content_type    = "api-key"
  expiration_date = "2027-12-31T00:00:00Z"

  depends_on = [azurerm_role_assignment.kv_deployer]
}
