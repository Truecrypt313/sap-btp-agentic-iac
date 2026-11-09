# YAML-managed SAP BTP role collections

The module creates dedicated role collections, without creating users or role
assignments. YAML keys define stable Terraform instance addresses. Collection
names must be unique within the subaccount, and each collection needs at least
one unique role with its exact name, role template and application ID.

`btp_subaccount_roles` reads the actual subaccount catalog during plan. Every
configured role triple must match exactly once. Required role attributes must
already have values. Applications must be subscribed before their roles can be
referenced; missing roles fail the plan instead of being guessed or skipped.
`role-catalog-rules` tests these rules with full catalog fixtures independently
of Terraform's restrictions on mocks for computed nested collections.

The canonical TEST configuration creates only:

- `TEST_FeatureFlags_Administrator`, with its verified dashboard administrator role.
- `TEST_FeatureFlags_Auditor`, with its verified dashboard auditor role.

Existing collections are not adopted automatically. Import and review them
before declaring ownership if a collection with the chosen name already exists.
Do not simultaneously manage a collection with another Terraform resource or state.

## Future assignments

Use `role_collection_key` for managed collections. Pass `collection_names`
directly to the assignment module's `managed_collections`; reconstructing the map
from YAML would lose the creation dependency. `role_collection_name` remains
available for external, pre-existing collections, whose lookups retain their
original `available[assignment_key]` addresses.

Example for a later, explicitly authorized assignment to an existing user:

```yaml
role_assignments:
  feature_flags_reader:
    role_collection_key: feature_flags_auditor
    user_name: reader@example.invalid
    origin: sap.default
```

Do not copy the example user into deployment configuration. The current YAML
keeps assignments empty. Managed bindings require an explicit identity-provider
origin; creating a collection grants no user access by itself. Existing legacy
administrator assignments and the null/`ldap` duplicate-detection behavior remain
unchanged.
