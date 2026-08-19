variable "resource_group_name" {
  description = "Resource group name where private DNS zones and links are created."
  type        = string
}

variable "tags" {
  description = "Tags applied to private DNS zones and virtual network links."
  type        = map(string)
  default     = {}
}

variable "vnet_ids" {
  description = "Map of virtual network IDs keyed by stable names (for example: hub, spoke)."
  type        = map(string)

  validation {
    condition     = length(var.vnet_ids) > 0
    error_message = "At least one VNet ID must be provided in vnet_ids."
  }
}
