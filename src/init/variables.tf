variable "aws_region" {
  type        = string
  description = "AWS region (default is Ireland)"
  default     = "eu-south-1"
}

variable "environment" {
  type        = string
  description = "Environment. Possible values are: dev, uat, prod"
  default     = "dev"
}

variable "github_repository" {
  type        = string
  description = "This github repository"
}

variable "tags" {
  type = map(any)
  default = {
    "CreatedBy" : "Terraform",
    "Environment" : "Dev"
  }
}