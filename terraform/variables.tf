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

variable "openai_sku" {
  description = "Azure OpenAI pricing tier."
  type        = string
  default     = "S0"
}

variable "model_name" {
  description = "OpenAI model to deploy."
  type        = string
  default     = "gpt-5.4-mini"
}

variable "model_version" {
  description = "Model version. Confirm regional availability before changing."
  type        = string
  default     = "2026-03-17"
}

variable "model_capacity" {
  description = "Capacity in thousands of tokens per minute. Kept low to stay within quota."
  type        = number
  default     = 10
}
