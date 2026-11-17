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

# ─────────────────────────────────────────────────────────────
# INTENTIONAL VULNERABILITY: left in for the Checkov security scan.
# public_network_access_enabled = true is a deliberate flaw.
# The pipeline should flag it, then it gets fixed.
# ─────────────────────────────────────────────────────────────
resource "azurerm_storage_account" "lab" {
  name                     = "${var.prefix}${random_id.suffix.hex}"
  resource_group_name      = azurerm_resource_group.lab.name
  location                 = azurerm_resource_group.lab.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"

  # SECURITY FLAW: public access enabled. Checkov will flag this.
  public_network_access_enabled = true

  tags = var.tags
}
