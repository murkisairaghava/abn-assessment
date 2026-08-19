# Read the pre-existing resource group used for this assessment environment.
# The name is provided via terraform.tfvars.
data "azurerm_resource_group" "existing" {
  name = var.resource_group_name
}
