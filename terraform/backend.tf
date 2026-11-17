terraform {
  backend "azurerm" {
    resource_group_name  = "rg-tfstate-pipeline"
    storage_account_name = "tfstatejbtech01"
    container_name       = "tfstate"
    key                  = "terraform.tfstate"
  }
}
