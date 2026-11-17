output "resource_group_name" {
  value       = azurerm_resource_group.lab.name
  description = "Name of the resource group."
}

output "storage_account_name" {
  value       = azurerm_storage_account.lab.name
  description = "Storage account name, globally unique."
}

output "storage_account_id" {
  value       = azurerm_storage_account.lab.id
  description = "Storage account resource ID."
}
