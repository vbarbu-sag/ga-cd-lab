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

locals {
  app_name = "ga-cd-lab-app"
  api_name = "ga-cd-lab-api"
  app_hostname = "${local.app_name}.azurewebsites.net"
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
  name                = local.api_name
  location            = azurerm_resource_group.rg.location
  service_plan_id     = azurerm_service_plan.asp.id
  https_only          = true
  resource_group_name = azurerm_resource_group.rg.name
  app_settings = {
    "ASPNETCORE_ENVIRONMENT" = "Production"
    "ConnectionStrings__DefaultConnection" = "Server=tcp:${azurerm_mssql_server.sql.fully_qualified_domain_name},1433;Initial Catalog=${azurerm_mssql_database.db.name};Persist Security Info=False;User ID=${azurerm_mssql_server.sql.administrator_login};Password=${azurerm_mssql_server.sql.administrator_login_password};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
  }
  site_config {
    minimum_tls_version = "1.2"
    always_on           = false
    application_stack {
      dotnet_version = "9.0"
    }
    cors {
      allowed_origins = ["https://${local.app_hostname}"]
    }
  }
}

resource "azurerm_linux_web_app" "app" {
  name                = local.app_name
  location            = azurerm_resource_group.rg.location
  service_plan_id     = azurerm_service_plan.asp.id
  https_only          = true
  resource_group_name = azurerm_resource_group.rg.name
  app_settings = {
    "API_URL"                             = "https://${azurerm_linux_web_app.api.default_hostname}"
  }
  site_config {
    minimum_tls_version = "1.2"
    always_on           = false
    application_stack {
      node_version = "22-lts"
    }
    app_command_line = "pm2 serve /home/site/wwwroot --no-daemon --spa"
  }
}

resource "azurerm_mssql_server" "sql" {
  name                         = "ga-cd-lab-sql"
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = azurerm_resource_group.rg.location
  version                      = "12.0"
  administrator_login          = "sqladmin"
  administrator_login_password = "P@ssw0rd1234!"

  public_network_access_enabled    = true
  minimum_tls_version              = "1.2"
}

resource "azurerm_mssql_database" "db" {
  name                = "ga-cd-lab-db"
  server_id           = azurerm_mssql_server.sql.id
  collation           = "SQL_Latin1_General_CP1_CI_AS"
  license_type        = "LicenseIncluded"
  max_size_gb         = 2
  read_scale          = false
  sku_name            = "Basic"
  zone_redundant      = false
}

resource "azurerm_mssql_firewall_rule" "allow_azure_services" {
  name                = "AllowAzureServices"
  server_id           = azurerm_mssql_server.sql.id
  start_ip_address    = "0.0.0.0"
  end_ip_address      = "0.0.0.0"
}