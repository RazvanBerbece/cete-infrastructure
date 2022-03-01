# terraform/variables.tf

variable "ENVIRONMENT" {
  description = "Environment (stg / prd)"
  type        = string
}

variable "ARM_CLIENT_ID" {
  description = "Client ID obtained from the Azure SP"
  type        = string
  sensitive   = true
}

variable "ARM_CLIENT_SECRET" {
  description = "Client secret obtained from the Azure SP"
  type        = string
  sensitive   = true
}

variable "ARM_SUBSCRIPTION_ID" {
  description = "Subscription ID obtained from the Azure SP"
  type        = string
  sensitive   = true
}

variable "ARM_TENANT_ID" {
  description = "Tenant ID obtained from the Azure SP"
  type        = string
  sensitive   = true
}

variable "BUDGET_ADMIN_EMAILS" {
  description = "Budget admin email address list for cost notifications"
}