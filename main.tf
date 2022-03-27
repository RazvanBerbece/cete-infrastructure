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
    azuread = {
      source  = "hashicorp/azuread"
      version = ">=2.19.1"
    }
  }

  required_version = ">= 1.1.6" # force minimum vers 1.1.0 on the Terraform version
}

##### INIT PROVIDERS
provider "azurerm" {
  features {}
}
provider "azuread" {}

##### ALIASES 
data "azurerm_subscription" "current" {}
data "azuread_client_config" "currentADClient" {}

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

##### REGISTER APP ON AZURE AD
##### IDs for scopes & roles are arbitrarily generated and kept
resource "azuread_application" "cete-ad-app" {
  display_name     = "cete-${var.ENVIRONMENT}-api-app"
  identifier_uris  = ["https://cete-${var.ENVIRONMENT}-api.azurewebsites.net"]
  owners           = [data.azuread_client_config.currentADClient.object_id]
  sign_in_audience = "AzureADMyOrg"

  api {
    oauth2_permission_scope {
      admin_consent_description  = "Allow the application to access example on behalf of the signed-in user."
      admin_consent_display_name = "Access cete-${var.ENVIRONMENT}-api"
      user_consent_description   = "Allow the application to access example on behalf of the signed-in user."
      user_consent_display_name  = "Access cete-${var.ENVIRONMENT}-api"
      enabled                    = true
      id                         = "96183846-204b-4b43-82e1-5d2222eb4b9b"
      type                       = "User"
      value                      = "user_impersonation"
    }
  }

  app_role {
    allowed_member_types = ["User", "Application"]
    description          = "Admins can manage roles and perform all task actions"
    display_name         = "Admin"
    enabled              = true
    id                   = "1b19509b-32b1-4e9f-b71d-4992aa991967"
    value                = "admin"
  }

  app_role {
    allowed_member_types = ["User"]
    description          = "ReadOnly roles have limited query access"
    display_name         = "ReadOnly"
    enabled              = true
    id                   = "497406e4-012a-4267-bf18-45a1cb148a01"
    value                = "User"
  }

  required_resource_access {
    resource_app_id = "00000003-0000-0000-c000-000000000000" # Microsoft Graph

    resource_access {
      id   = "df021288-bdef-4463-88db-98f22de89214" # User.Read.All
      type = "Role"
    }

    resource_access {
      id   = "b4e74841-8e56-480b-be8b-910348b18b4c" # User.ReadWrite
      type = "Scope"
    }
  }

  web {
    redirect_uris = ["https://cete-${var.ENVIRONMENT}-api.azurewebsites.net/.auth/login/aad/callback"]

    implicit_grant {
      access_token_issuance_enabled = true
      id_token_issuance_enabled     = true
    }
  }
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

  // Auth
  auth_settings {
    enabled = true
    microsoft {
      client_id = azuread_application.cete-ad-app.application_id
    }
  }

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

  depends_on = [
    azuread_application.cete-ad-app,
  ]
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
  ip_range_filter = element(var.DEV_IP_LIST, 0)

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
  partition_key_path    = "/id"
  partition_key_version = 1
  throughput            = 400
}

resource "azurerm_storage_container" "cete-storage-container" {
  name                  = "cetes"
  storage_account_name  = azurerm_storage_account.cete-storage-account.name
  container_access_type = "private"
}
