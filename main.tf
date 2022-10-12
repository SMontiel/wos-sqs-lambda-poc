terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.33.0"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region  = "us-west-1"
}

locals {
  tags = {
    Project = "WOS-SQS-Lambda-PoC"
    Kind = "PoC"
    Environment = "dev"
    Creator = "smontiel"
  }
}
