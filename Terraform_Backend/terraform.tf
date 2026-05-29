terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.92"
    }
  }

  required_version = ">= 1.14.5"
}

provider "aws" {
  region = "us-east-1"
}