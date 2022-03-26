# terraform/variables.tf

variable "ENVIRONMENT" {
  description = "Environment (stg / prd)"
  type        = string
}

variable "ARM_CLIENT_ID" {
  description = "Client ID obtained from the Azure SP"
  type        = string
  sensitive   = true
  default     = ""
}

variable "ARM_CLIENT_SECRET" {
  description = "Client secret obtained from the Azure SP"
  type        = string
  sensitive   = true
  default     = ""
}

variable "ARM_SUBSCRIPTION_ID" {
  description = "Subscription ID obtained from the Azure SP"
  type        = string
  sensitive   = true
  default     = ""
}

variable "ARM_TENANT_ID" {
  description = "Tenant ID obtained from the Azure SP"
  type        = string
  sensitive   = true
  default     = ""
}

variable "BUDGET_ADMIN_EMAILS" {
  description = "Budget admin email address list for cost notifications"
  type        = list(string)
  sensitive   = true
  default     = []
}

variable "DEV_IP_LIST" {
  description = "IP List of allowed IPs to access / use infrastructure"
  type        = list(string)
  sensitive   = true
  default     = []
}