variable "location" {
  description = "Azure region for all resources."
  type        = string
  default     = "eastus"
}

variable "prefix" {
  description = "Short prefix for resource names. Lowercase, no spaces."
  type        = string
  default     = "pipeline"
}

variable "environment" {
  description = "Environment label: dev, staging, or prod."
  type        = string
  default     = "dev"
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default = {
    Environment = "dev"
    ManagedBy   = "Terraform"
    Project     = "Azure-Secure-Terraform-Pipeline"
  }
}
