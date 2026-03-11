terraform {
  required_version = ">= 1.3.0"

  required_providers {
    volterra = {
      source  = "volterraedge/volterra"
      version = ">= 0.11.42"
    }

    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }

    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.49.0"
    }
  }
}

provider "volterra" {
  api_p12_file = var.f5xc_api_p12_file
  url          = var.f5xc_api_url
}

provider "aws" {
  region  = var.aws_ce != null ? var.aws_ce.aws_region : "us-gov-west-1"
  profile = var.aws_ce != null ? var.aws_ce.aws_profile : null

  skip_credentials_validation = var.aws_ce == null
  skip_requesting_account_id  = var.aws_ce == null
  skip_metadata_api_check     = var.aws_ce == null
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
  environment                     = "usgovernment"
  resource_provider_registrations = var.azure_ce == null ? "none" : "legacy"
}
