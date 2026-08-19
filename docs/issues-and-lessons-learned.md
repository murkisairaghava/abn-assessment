# Issues and Lessons Learned

## 1. ACR Data-Plane Access Validation Constraint

The Azure Container Registry was deployed with Premium SKU, Private Endpoint, Private DNS, and Public Network Access disabled. Direct image push validation from the workstation could not be completed because the user account lacked registry data-plane permissions.

### Outcome
- ACR configuration and private networking posture were validated successfully.
- Data-plane push testing was deferred to an identity with appropriate permissions.

## 2. Terraform Plan Failure in Private DNS Module

### Issue
- Terraform plan failed with `Invalid for_each argument` in the private DNS VNet link resource.
- Root cause: `for_each` keys were derived from VNet IDs that were unknown until apply.

### Resolution
- Refactored module input from `set(string)` to `map(string)` for VNet IDs.
- Used stable, plan-time keys (`hub`, `spoke`) for `for_each` instance addressing.
- Kept apply-time VNet IDs in map values only.

### Lesson
- In Terraform, `for_each` keys must be deterministic at plan time.
- Use static identifiers for resource addressing and place unknown values only in the mapped attributes.

### Validation Evidence
- `terraform plan` now succeeds with a full resource plan and no `for_each` error.