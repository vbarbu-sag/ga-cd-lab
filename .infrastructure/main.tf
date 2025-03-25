terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.24.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.2.0"
    }
  }
  required_version = ">= 1.1.0"
}

provider "azurerm" {
  features {}
}

provider "azuread" {
}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "rg" {
  name     = "ga-cd-lab"
  location = "westeurope"
}

resource "azurerm_service_plan" "asp" {
  name                = "ga-cd-lab-asp"
  location            = azurerm_resource_group.rg.location
  os_type             = "Linux"
  sku_name            = "F1"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_linux_web_app" "api" {
  name                = "ga-cd-lab-api"
  location            = azurerm_resource_group.rg.location
  service_plan_id     = azurerm_service_plan.asp.id
  https_only          = true
  resource_group_name = azurerm_resource_group.rg.name
  app_settings = {
    "ASPNETCORE_ENVIRONMENT" = "Production"
  }
  site_config {
    minimum_tls_version = "1.2"
    always_on           = false
    application_stack {
      dotnet_version = "9.0"
    }
  }
}

resource "azuread_application" "github_actions" {
  display_name = "GithubActions-DeployApp"
}

resource "azuread_service_principal" "github_actions" {
  client_id = azuread_application.github_actions.client_id
}

resource "azuread_service_principal_password" "github_actions" {
  service_principal_id = azuread_service_principal.github_actions.id
}

resource "azurerm_role_assignment" "github_actions" {
  scope                = azurerm_resource_group.rg.id
  role_definition_name = "Contributor"
  principal_id         = azuread_service_principal.github_actions.id
}

output "client_id" {
  value     = azuread_application.github_actions.client_id
  sensitive = true
}

output "client_secret" {
  value     = azuread_service_principal_password.github_actions.value
  sensitive = true
}

output "tenant_id" {
  value     = data.azurerm_client_config.current.tenant_id
  sensitive = true
}

output "subscription_id" {
  value     = data.azurerm_client_config.current.subscription_id
  sensitive = true
}
