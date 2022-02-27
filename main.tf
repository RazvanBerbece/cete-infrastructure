# terraform/main.tf

#
# This file describes the infrastructure of the Cete app
# It builds & maintains both a staging and a production environment
#

#################################### INIT AZURE PROVIDER & TERRAFORM CLOUD ####################################
terraform {
  # Terraform Cloud block
  cloud {
    organization = "AntonioBerbece"

    workspaces {
      tags = ["cete-api"]
    }
  }

  # Providers to use in generating infrastructure
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 2.65"
    }
  }

  required_version = ">= 1.1.0" # force minimum vers 1.1.0 on the Terraform version
}

#################################### PASS VARS TO AZURE ####################################
provider "azurerm" {
  features {}

  subscription_id = var.ARM_SUBSCRIPTION_ID
  tenant_id       = var.ARM_TENANT_ID
  client_id       = var.ARM_CLIENT_ID
  client_secret   = var.ARM_CLIENT_SECRET
}

#################################### CREATE RESOURCES ####################################
resource "azurerm_resource_group" "cete-rg" {
  name     = "cete-${var.ENVIRONMENT}-rg"
  location = "centralus"

  tags = {
    environment = "${var.ENVIRONMENT}"
  }
}

resource "azurerm_storage_account" "cete-storage-account" {
  name                     = "cete${var.ENVIRONMENT}storageacc"
  location                 = azurerm_resource_group.cete-rg.location
  resource_group_name      = azurerm_resource_group.cete-rg.name
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = {
    environment = "${var.ENVIRONMENT}"
  }
}

resource "azurerm_app_service_plan" "cete-func-service-plan" {
  name                = "cete-func-${var.ENVIRONMENT}-service-plan"
  location            = azurerm_resource_group.cete-rg.location
  resource_group_name = azurerm_resource_group.cete-rg.name
  kind                = "FunctionApp"
  reserved            = false

  sku {
    tier = "Basic"
    size = "S1"
  }

  tags = {
    environment = "${var.ENVIRONMENT}"
  }
}

resource "azurerm_application_insights" "cete-application_insights" {
  name                = "cete-${var.ENVIRONMENT}-application-insights"
  location            = azurerm_resource_group.cete-rg.location
  resource_group_name = azurerm_resource_group.cete-rg.name
  application_type    = "Node.JS"

  tags = {
    environment = "${var.ENVIRONMENT}"
  }
}

resource "azurerm_function_app" "cete-function-app" {
  name                       = "cete-${var.ENVIRONMENT}-api"
  location                   = azurerm_resource_group.cete-rg.location
  resource_group_name        = azurerm_resource_group.cete-rg.name
  app_service_plan_id        = azurerm_app_service_plan.cete-func-service-plan.id
  storage_account_name       = azurerm_storage_account.cete-storage-account.name
  storage_account_access_key = azurerm_storage_account.cete-storage-account.primary_access_key

  app_settings = {
    "FUNCTIONS_WORKER_RUNTIME"       = "node",
    "APPINSIGHTS_INSTRUMENTATIONKEY" = azurerm_application_insights.cete-application_insights.instrumentation_key,
  }

  tags = {
    environment = "${var.ENVIRONMENT}"
  }
}

