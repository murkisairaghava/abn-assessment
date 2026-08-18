locals {
  # Microsoft Entra Workload Identity subject format for Kubernetes service accounts.
  federated_subject = "system:serviceaccount:${var.kubernetes_namespace}:${var.kubernetes_service_account_name}"
}

resource "azurerm_user_assigned_identity" "this" {
  name                = var.managed_identity_name
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

resource "azurerm_federated_identity_credential" "this" {
  name                = "fic-${var.managed_identity_name}"
  resource_group_name = var.resource_group_name
  parent_id           = azurerm_user_assigned_identity.this.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = var.aks_oidc_issuer_url
  subject             = local.federated_subject
}

resource "azurerm_role_assignment" "keyvault_secrets_user" {
  scope                = var.keyvault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.this.principal_id
}
