=== Additional requirements for Function Apps:
- Attach User-Assigned Managed Identity.
- MANDATORY: Add a {{RoleAssignmentResource}} resource to assign the Storage Blob Data Owner (b7e6dc6d-f1e8-4753-8033-0f276bb0955b) role to the user-assigned managed identity.
- MANDATORY: Add a {{RoleAssignmentResource}} resource to assign the Storage Blob Data Contributor (ba92f5b4-2d11-453d-a403-e96b0029c9fe) role to the user-assigned managed identity.
- MANDATORY: Add a {{RoleAssignmentResource}} resource to assign the Storage Queue Data Contributor (974c5e8b-45b9-4653-ba55-5f855dd0fb88) role to the user-assigned managed identity.
- MANDATORY: Add a {{RoleAssignmentResource}} resource to assign the Storage Table Data Contributor (0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3) role to the user-assigned managed identity.
- MANDATORY: Add a {{RoleAssignmentResource}} resource to assign the Monitoring Metrics Publisher (3913510d-42f4-4e42-8a64-420c390055eb) role to the user-assigned managed identity.
- Create a storage account and connect to the function app.
- Define diagnostic settings to save logs. The resource type is {{DiagnosticSettingsResource}}.
===
