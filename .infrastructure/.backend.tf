terraform {
  backend "local" {}
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
  default     = "dev"
}

locals {
  resource_prefix = "ga-cd-lab-${var.environment}"
}