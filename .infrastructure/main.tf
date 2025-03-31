terraform {
  backend "local" {}
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

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

locals {
  base_name = "ga-cd-lab"
  resource_group_name = "${local.base_name}-${var.environment}"
  app_name = "${local.base_name}-app-${var.environment}"
  api_name = "${local.base_name}-api-${var.environment}"
  app_hostname = "${local.app_name}.azurewebsites.net"
  sql_server_name = "${local.base_name}-sql-${var.environment}"
  sql_db_name = "${local.base_name}-db-${var.environment}"
  app_service_plan_name = "${local.base_name}-asp-${var.environment}"
}

resource "azurerm_resource_group" "rg" {
  name     = local.resource_group_name
  location = "westeurope"
  tags = {
    Environment = var.environment
  }
}

resource "azurerm_service_plan" "asp" {
  name                = local.app_service_plan_name
  location            = azurerm_resource_group.rg.location
  os_type             = "Linux"
  sku_name            = "F1"
  resource_group_name = azurerm_resource_group.rg.name
  
  tags = {
    Environment = var.environment
  }
}

resource "azurerm_linux_web_app" "api" {
  name                = local.api_name
  location            = azurerm_resource_group.rg.location
  service_plan_id     = azurerm_service_plan.asp.id
  https_only          = true
  resource_group_name = azurerm_resource_group.rg.name
  
  app_settings = {
    "ASPNETCORE_ENVIRONMENT" = var.environment == "prod" ? "Production" : title(var.environment)
    "ConnectionStrings__DefaultConnection" = "Server=tcp:${azurerm_mssql_server.sql.fully_qualified_domain_name},1433;Initial Catalog=${azurerm_mssql_database.db.name};Persist Security Info=False;User ID=${azurerm_mssql_server.sql.administrator_login};Password=${azurerm_mssql_server.sql.administrator_login_password};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
    "ENVIRONMENT" = var.environment
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
  
  tags = {
    Environment = var.environment
  }
}

resource "azurerm_linux_web_app" "app" {
  name                = local.app_name
  location            = azurerm_resource_group.rg.location
  service_plan_id     = azurerm_service_plan.asp.id
  https_only          = true
  resource_group_name = azurerm_resource_group.rg.name
  
  app_settings = {
    "API_URL" = "https://${azurerm_linux_web_app.api.default_hostname}"
    "ENVIRONMENT" = var.environment
  }
  
  site_config {
    minimum_tls_version = "1.2"
    always_on           = false
    application_stack {
      node_version = "22-lts"
    }
    app_command_line = "pm2 serve /home/site/wwwroot --no-daemon --spa"
  }
  
  tags = {
    Environment = var.environment
  }
}

resource "azurerm_mssql_server" "sql" {
  name                         = local.sql_server_name
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = azurerm_resource_group.rg.location
  version                      = "12.0"
  administrator_login          = "sqladmin"
  administrator_login_password = "P@ssw0rd1234!"
  public_network_access_enabled    = true
  minimum_tls_version              = "1.2"
  
  tags = {
    Environment = var.environment
  }
}

resource "azurerm_mssql_database" "db" {
  name                = local.sql_db_name
  server_id           = azurerm_mssql_server.sql.id
  collation           = "SQL_Latin1_General_CP1_CI_AS"
  license_type        = "LicenseIncluded"
  max_size_gb         = 2
  read_scale          = false
  sku_name            = "Basic"
  zone_redundant      = false
  
  tags = {
    Environment = var.environment
  }
}

resource "azurerm_mssql_firewall_rule" "allow_azure_services" {
  name                = "AllowAzureServices"
  server_id           = azurerm_mssql_server.sql.id
  start_ip_address    = "0.0.0.0"
  end_ip_address      = "0.0.0.0"
}