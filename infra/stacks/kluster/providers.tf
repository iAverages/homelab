terraform {
  required_version = ">= 1.7.0"

  required_providers {
    external = {
      source  = "hashicorp/external"
      version = "~> 2.3"
    }

    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}
