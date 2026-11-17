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

output "openai_endpoint" {
  value       = azurerm_cognitive_account.openai.endpoint
  description = "Azure OpenAI endpoint URL."
}

output "openai_deployment_name" {
  value       = azurerm_cognitive_deployment.gpt.name
  description = "Model deployment name, passed to the SDK as the model."
}

output "key_vault_name" {
  value       = azurerm_key_vault.lab.name
  description = "Key Vault holding the OpenAI API key."
}
