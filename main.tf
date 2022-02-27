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

# LIVE
resource "azurerm_resource_group" "cete-prod-rg" {
  name     = "cete-prod-rg"
  location = "centralus"
  tags = {
    Environment = "Production"
  }
}