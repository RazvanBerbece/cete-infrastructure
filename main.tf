# terraform/main.tf

#
# This file describes the infrastructure of the Cete app
# It builds & maintains different environments (staging & production), as they share the same infrastructure
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

}

#################################### CREATE RESOURCES & BUDGET ####################################
resource "azurerm_resource_group" "cete-rg" {
  name     = "cete-${var.ENVIRONMENT}-rg"
  location = "westus"

  tags = {
    environment = "${var.ENVIRONMENT}"
  }
}

resource "azurerm_consumption_budget_subscription" "azure-budget" {
  name            = "cete-${var.ENVIRONMENT}-budget"
  subscription_id = var.ARM_SUBSCRIPTION_ID

  amount     = 1
  time_grain = "Monthly"

  time_period {
    start_date = "2022-03-01T00:00:00Z"
    end_date   = "2022-12-01T00:00:00Z"
  }

  notification {
    enabled   = true
    threshold = 2.00
    operator  = "GreaterThanOrEqualTo"

    contact_emails = var.BUDGET_ADMIN_EMAILS
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

  sku {
    tier = "Free"
    size = "S1"
  }

  tags = {
    environment = "${var.ENVIRONMENT}"
  }
}

resource "azurerm_log_analytics_workspace" "cete-application-insights" {
  name                = "cete-${var.ENVIRONMENT}-app-insights"
  location            = azurerm_resource_group.cete-rg.location
  resource_group_name = azurerm_resource_group.cete-rg.name
  retention_in_days   = 30

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
  os_type                    = "linux"

  app_settings = {
    "FUNCTIONS_WORKER_RUNTIME"       = "node",
    "APPINSIGHTS_INSTRUMENTATIONKEY" = azurerm_log_analytics_workspace.cete-application-insights.primary_shared_key,
  }

  tags = {
    environment = "${var.ENVIRONMENT}"
  }
}

resource "azurerm_cosmosdb_account" "cosmos-db-account" {
  name                = "cete-db-${var.ENVIRONMENT}-account"
  location            = azurerm_resource_group.cete-rg.location
  resource_group_name = azurerm_resource_group.cete-rg.name
  offer_type          = "Standard"
  enable_free_tier    = true

  consistency_policy {
    consistency_level       = "BoundedStaleness"
    max_interval_in_seconds = 300
    max_staleness_prefix    = 100000
  }

  geo_location {
    location          = azurerm_resource_group.cete-rg.location
    failover_priority = 0
  }

  tags = {
    environment = "${var.ENVIRONMENT}"
  }
}

resource "azurerm_cosmosdb_sql_database" "cete-id-indexing-db" {
  name                = "cete-${var.ENVIRONMENT}-indexing"
  resource_group_name = azurerm_cosmosdb_account.cosmos-db-account.resource_group_name
  account_name        = azurerm_cosmosdb_account.cosmos-db-account.name
  throughput          = 400
}

