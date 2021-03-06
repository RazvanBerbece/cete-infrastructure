# terraform/main.tf

#
# This file describes the infrastructure of the Cete app
# It builds & maintains different environments (staging & production), as they share the same infrastructure
#

##### INIT AZURE PROVIDER & TERRAFORM CLOUD 
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
      version = "=3.0.1"
    }
  }

  required_version = ">= 1.1.6" # force minimum vers 1.1.0 on the Terraform version
}

#### PASS VARS TO AZURE 
provider "azurerm" {
  features {}

}

##### ALIASES 
data "azurerm_subscription" "current" {}

##### CREATE RESOURCES & BUDGET 
resource "azurerm_resource_group" "cete-rg" {
  name     = "cete-${var.ENVIRONMENT}-rg"
  location = "westus"

  tags = {
    environment = "${var.ENVIRONMENT}"
  }
}

# Azure for Students does not allow access to the Budget scope
# resource "azurerm_consumption_budget_subscription" "azure-budget" {
#   name            = "cete-${var.ENVIRONMENT}-budget"
#   subscription_id = data.azurerm_subscription.current.id

#   amount     = 2.50
#   time_grain = "Monthly"

#   time_period {
#     start_date = "2022-03-01T00:00:00Z"
#     end_date   = "2022-12-01T00:00:00Z"
#   }

#   notification {
#     enabled   = true
#     threshold = 10.00
#     operator  = "GreaterThanOrEqualTo"

#     contact_emails = var.BUDGET_ADMIN_EMAILS
#   }
# }

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

resource "azurerm_service_plan" "cete-func-service-plan" {
  name                = "cete-func-${var.ENVIRONMENT}-service-plan"
  location            = azurerm_resource_group.cete-rg.location
  resource_group_name = azurerm_resource_group.cete-rg.name
  os_type             = "Linux"
  sku_name            = "B1"

  tags = {
    environment = "${var.ENVIRONMENT}"
  }
}

resource "azurerm_log_analytics_workspace" "cete-application-insights" {
  name                = "cete-${var.ENVIRONMENT}-app-insights"
  location            = azurerm_resource_group.cete-rg.location
  resource_group_name = azurerm_resource_group.cete-rg.name
  retention_in_days   = 30 # 7 for free tier
  daily_quota_gb      = 0.5

  tags = {
    environment = "${var.ENVIRONMENT}"
  }

  # Access Rules (Firewall) - disable all access from outside the Azure network
  internet_ingestion_enabled = true
  internet_query_enabled     = true

}

resource "azurerm_linux_function_app" "cete-function-app" {
  name                       = "cete-${var.ENVIRONMENT}-api"
  location                   = azurerm_resource_group.cete-rg.location
  resource_group_name        = azurerm_resource_group.cete-rg.name
  service_plan_id            = azurerm_service_plan.cete-func-service-plan.id
  storage_account_name       = azurerm_storage_account.cete-storage-account.name
  storage_account_access_key = azurerm_storage_account.cete-storage-account.primary_access_key

  app_settings = {
    "APPINSIGHTS_INSTRUMENTATIONKEY" = azurerm_log_analytics_workspace.cete-application-insights.primary_shared_key,
  }

  builtin_logging_enabled = "false"

  site_config {

    # Worker Config
    worker_count = 1
    application_stack {
      node_version = 14
    }

    # Access Rules (Firewall)
    ip_restriction {
      name       = "Antonio@LocalDev"
      action     = "Allow"
      ip_address = element(var.DEV_IP_LIST, 0)
    }
    ip_restriction {
      name       = "Antonio@LocalDevPublic"
      action     = "Allow"
      ip_address = element(var.DEV_IP_LIST, 1)
    }

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

  # Enable 'Free Tier' for staging environment
  enable_free_tier = var.ENVIRONMENT == "stg" ? true : false

  consistency_policy {
    consistency_level       = "BoundedStaleness"
    max_interval_in_seconds = 300
    max_staleness_prefix    = 100000
  }

  geo_location {
    location          = azurerm_resource_group.cete-rg.location
    failover_priority = 0
  }

  # Access Rules (Firewall)
  ip_range_filter = join(",", var.DEV_IP_LIST)

}

resource "azurerm_cosmosdb_sql_database" "cete-id-indexing-db" {
  name                = "cete-${var.ENVIRONMENT}-indexing"
  resource_group_name = azurerm_cosmosdb_account.cosmos-db-account.resource_group_name
  account_name        = azurerm_cosmosdb_account.cosmos-db-account.name
  throughput          = 400
}

resource "azurerm_cosmosdb_sql_container" "cete-sql-container" {
  name                  = "Cetes"
  resource_group_name   = azurerm_cosmosdb_account.cosmos-db-account.resource_group_name
  account_name          = azurerm_cosmosdb_account.cosmos-db-account.name
  database_name         = azurerm_cosmosdb_sql_database.cete-id-indexing-db.name
  partition_key_path    = "/userId"
  partition_key_version = 1
  throughput            = 400
}

resource "azurerm_storage_container" "cete-storage-container" {
  name                  = "cetes"
  storage_account_name  = azurerm_storage_account.cete-storage-account.name
  container_access_type = "private"
}
