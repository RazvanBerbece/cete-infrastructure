# terraform/outputs.tf

output "function_app_name" {
  value       = azurerm_linux_function_app.cete-function-app.name
  description = "Deployed function app name"
}

output "function_app_default_hostname" {
  value       = azurerm_linux_function_app.cete-function-app.default_hostname
  description = "Deployed function app hostname"
}