mock_provider "postgresql" {}
mock_provider "random" {}

variables {
  username = "owner_user"
  db_name  = "app_db"
  schemas = [
    { name = "app", add_to_search_path = true },
    { name = "audit", add_to_search_path = false },
  ]
}

run "defaults_plan_only_existing_resources" {
  command = plan

  assert {
    condition     = postgresql_role.db_user.login && !postgresql_role.db_user.superuser
    error_message = "Owner role must be a non-superuser login role."
  }

  assert {
    condition     = postgresql_database.db.owner == "owner_user"
    error_message = "Database must be owned by the owner role."
  }

  assert {
    condition     = length(postgresql_schema.schema) == 2 && postgresql_schema.schema["app"].owner == "owner_user"
    error_message = "Schemas must be owned by the owner role."
  }

  assert {
    condition     = postgresql_grant.revoke_other.object_type == "schema" && length(postgresql_grant.revoke_other.privileges) == 0
    error_message = "The public schema revoke must be unchanged."
  }

  assert {
    condition = alltrue([
      length(random_password.role) == 0,
      length(postgresql_role.role) == 0,
      length(postgresql_grant.role_schema) == 0,
      length(postgresql_grant.role_tables) == 0,
      length(postgresql_grant.role_sequences) == 0,
      length(postgresql_grant.role_functions) == 0,
      length(postgresql_default_privileges.role) == 0,
    ])
    error_message = "No additional role resources by default."
  }

  assert {
    condition     = length(output.roles) == 0
    error_message = "The roles output must be empty by default."
  }
}
