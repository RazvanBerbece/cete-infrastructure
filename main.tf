# terraform/main.tf

#
# This file describes the infrastructure of the Cete app
# It builds & maintains both a staging and a production environment
#

# Configure the Azure provider & Terraform Cloud
terraform {
  # Terraform Cloud block
  cloud {
    organization = "AntonioBerbece"

    workspaces {
      name = "cete-infra"
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

# Pass Azure configs (secret keys, tokens, etc.) to Azure provider
provider "azurerm" {
  features {}

  subscription_id = var.ARM_SUBSCRIPTION_ID
  tenant_id       = var.ARM_TENANT_ID
  client_id       = var.ARM_CLIENT_ID
  client_secret   = var.ARM_CLIENT_SECRET
}

# CREATE RESOURCES #

# STAGING
resource "azurerm_resource_group" "cete-stg-rg" {
  name     = "cete-stg-rg"
  location = "centralus"
  tags = {
    Environment = "Staging"
  }
}

resource "azurerm_storage_account" "cete-stg-storage-account" {
  name                     = "cetestgstorageacc"
  resource_group_name      = azurerm_resource_group.cete-stg-rg.name
  location                 = azurerm_resource_group.cete-stg-rg.location
  account_tier             = "Standard"
  account_replication_type = "GRS"

  tags = {
    environment = "Staging"
  }
}

# LIVE
resource "azurerm_resource_group" "cete-prd-rg" {
  name     = "cete-prd-rg"
  location = "centralus"
  tags = {
    Environment = "Production"
  }
}

resource "azurerm_storage_account" "cete-prd-storage-account" {
  name                     = "ceteprodstorageacc"
  resource_group_name      = azurerm_resource_group.cete-prd-rg.name
  location                 = azurerm_resource_group.cete-prd-rg.location
  account_tier             = "Standard"
  account_replication_type = "GRS"

  tags = {
    environment = "Production"
  }
}