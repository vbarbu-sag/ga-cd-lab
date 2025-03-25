terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.24.0"
    }
  }
  required_version = ">= 1.1.0"
}

provider "azurerm" {
  features {}
}

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

resource "azurerm_linux_web_app" "app" {
  name                = "ga-cd-lab-app"
  location            = azurerm_resource_group.rg.location
  service_plan_id     = azurerm_service_plan.asp.id
  https_only          = true
  resource_group_name = azurerm_resource_group.rg.name

  app_settings = {
    "WEBSITES_ENABLE_APP_SERVICE_STORAGE" = "true"
    "API_URL"                             = "https://${azurerm_linux_web_app.api.default_hostname}"
  }

  site_config {
    minimum_tls_version = "1.2"
    always_on           = false

    application_stack {
      node_version = "22-lts"
    }

    cors {
      allowed_origins = ["https://${azurerm_linux_web_app.api.default_hostname}"]
    }
  }
}
