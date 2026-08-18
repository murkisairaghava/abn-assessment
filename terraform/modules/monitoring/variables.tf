variable "resource_group_name" {
  description = "Name of the resource group where monitoring resources will be deployed."
  type        = string
}

variable "location" {
  description = "Azure region where monitoring resources will be deployed."
  type        = string
}

variable "tags" {
  description = "Tags applied consistently to monitoring resources."
  type        = map(string)
  default     = {}
}

variable "environment" {
  description = "Environment short name used in resource naming (for example, sbx, dev, prod)."
  type        = string
}

variable "project_name" {
  description = "Project name used in monitoring resource naming."
  type        = string
}
