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

run "read_write_and_read_only_roles" {
  command = plan

  variables {
    roles = {
      app_rw = {
        table_privileges    = ["SELECT", "INSERT", "UPDATE", "DELETE"]
        sequence_privileges = ["USAGE", "SELECT"]
        function_privileges = ["EXECUTE"]
        connection_limit    = 20
      }
      reporting = {
        table_privileges = ["SELECT"]
      }
    }
  }

  assert {
    condition     = toset(keys(postgresql_role.role)) == toset(["app_rw", "reporting"]) && toset(keys(random_password.role)) == toset(["app_rw", "reporting"])
    error_message = "Each login role must have a role and a password."
  }

  assert {
    condition     = alltrue([for r in postgresql_role.role : r.login && !r.superuser && !r.create_database && !r.create_role])
    error_message = "Roles must be non-superuser login roles without createdb or createrole."
  }

  assert {
    condition     = postgresql_role.role["app_rw"].connection_limit == 20 && postgresql_role.role["reporting"].connection_limit == -1
    error_message = "connection_limit must come from the role object."
  }

  assert {
    condition     = alltrue([for r in postgresql_role.role : toset(r.search_path) == toset(postgresql_role.db_user.search_path) && toset(r.search_path) == toset(["app"])])
    error_message = "Role search_path must match the owner's."
  }

  assert {
    condition     = toset(keys(postgresql_grant.role_schema)) == toset(["app_rw.app", "app_rw.audit", "reporting.app", "reporting.audit"])
    error_message = "Schema grants must exist for every role and schema."
  }

  assert {
    condition     = alltrue([for g in postgresql_grant.role_schema : g.object_type == "schema" && toset(g.privileges) == toset(["USAGE"])])
    error_message = "Schema grants must be USAGE only."
  }

  assert {
    condition     = alltrue([for k, g in postgresql_grant.role_schema : g.role == split(".", k)[0] && g.schema == split(".", k)[1]])
    error_message = "Schema grants must target the role and schema in the key."
  }

  assert {
    condition     = toset(keys(postgresql_grant.role_tables)) == toset(["app_rw.app", "app_rw.audit", "reporting.app", "reporting.audit"])
    error_message = "Table grants must exist for every role and schema."
  }

  assert {
    condition     = toset(postgresql_grant.role_tables["app_rw.app"].privileges) == toset(["SELECT", "INSERT", "UPDATE", "DELETE"]) && toset(postgresql_grant.role_tables["reporting.audit"].privileges) == toset(["SELECT"]) && postgresql_grant.role_tables["app_rw.app"].object_type == "table"
    error_message = "Table privileges must match the role definition."
  }

  assert {
    condition     = toset(keys(postgresql_grant.role_sequences)) == toset(["app_rw.app", "app_rw.audit"]) && toset(postgresql_grant.role_sequences["app_rw.app"].privileges) == toset(["USAGE", "SELECT"]) && postgresql_grant.role_sequences["app_rw.app"].object_type == "sequence"
    error_message = "Only the read-write role gets sequence grants."
  }

  assert {
    condition     = toset(keys(postgresql_grant.role_functions)) == toset(["app_rw.app", "app_rw.audit"]) && toset(postgresql_grant.role_functions["app_rw.app"].privileges) == toset(["EXECUTE"]) && postgresql_grant.role_functions["app_rw.app"].object_type == "function"
    error_message = "Only the read-write role gets function grants."
  }

  assert {
    condition = toset(keys(postgresql_default_privileges.role)) == toset([
      "app_rw.app.table", "app_rw.app.sequence", "app_rw.app.function",
      "app_rw.audit.table", "app_rw.audit.sequence", "app_rw.audit.function",
      "reporting.app.table", "reporting.audit.table",
    ])
    error_message = "Default privilege keys must be role.schema.type for non-empty lists only."
  }

  assert {
    condition     = alltrue([for d in postgresql_default_privileges.role : d.owner == "owner_user"]) && postgresql_default_privileges.role["app_rw.app.table"].role == "app_rw" && postgresql_default_privileges.role["app_rw.app.table"].schema == "app" && toset(postgresql_default_privileges.role["app_rw.app.table"].privileges) == toset(["SELECT", "INSERT", "UPDATE", "DELETE"]) && postgresql_default_privileges.role["reporting.app.table"].object_type == "table"
    error_message = "Default privileges must be owned by the owner role and mirror the object privileges."
  }

  assert {
    condition     = postgresql_role.db_user.login && !postgresql_role.db_user.superuser && postgresql_database.db.owner == "owner_user" && postgresql_schema.schema["app"].owner == "owner_user"
    error_message = "Owner resources must be unchanged."
  }
}

run "group_role_without_login" {
  command = plan

  variables {
    roles = {
      readers = {
        login            = false
        table_privileges = ["SELECT"]
      }
    }
  }

  assert {
    condition     = length(random_password.role) == 0
    error_message = "A role without login must not get a password."
  }

  assert {
    condition     = !postgresql_role.role["readers"].login
    error_message = "The group role must not be able to log in."
  }

  assert {
    condition     = output.roles["readers"].name == "readers" && output.roles["readers"].password == null
    error_message = "The group role output must have a null password."
  }
}

run "role_restricted_to_one_schema" {
  command = plan

  variables {
    roles = {
      app_rw = {
        schemas             = ["app"]
        table_privileges    = ["SELECT"]
        sequence_privileges = ["USAGE"]
        function_privileges = ["EXECUTE"]
      }
    }
  }

  assert {
    condition     = toset(keys(postgresql_grant.role_schema)) == toset(["app_rw.app"]) && toset(keys(postgresql_grant.role_tables)) == toset(["app_rw.app"]) && toset(keys(postgresql_grant.role_sequences)) == toset(["app_rw.app"]) && toset(keys(postgresql_grant.role_functions)) == toset(["app_rw.app"])
    error_message = "Grants must exist only for the listed schema."
  }

  assert {
    condition     = toset(keys(postgresql_default_privileges.role)) == toset(["app_rw.app.table", "app_rw.app.sequence", "app_rw.app.function"])
    error_message = "Default privileges must exist only for the listed schema."
  }
}

run "default_privileges_disabled" {
  command = plan

  variables {
    roles = {
      app_rw = {
        default_privileges  = false
        table_privileges    = ["SELECT"]
        sequence_privileges = ["USAGE"]
      }
      other = {
        table_privileges = ["SELECT"]
      }
    }
  }

  assert {
    condition     = length(postgresql_grant.role_tables) == 4 && length(postgresql_grant.role_sequences) == 2
    error_message = "Existing-object grants must remain when default_privileges is false."
  }

  assert {
    condition     = toset(keys(postgresql_default_privileges.role)) == toset(["other.app.table", "other.audit.table"])
    error_message = "Only the role with default_privileges enabled may get default privileges."
  }
}

run "invalid_table_privilege" {
  command = plan

  variables {
    roles = { r = { table_privileges = ["SELECT", "DROP"] } }
  }

  expect_failures = [var.roles]
}

run "invalid_schema_privilege" {
  command = plan

  variables {
    roles = { r = { schema_privileges = ["USAGE", "ALL"] } }
  }

  expect_failures = [var.roles]
}

run "invalid_sequence_privilege" {
  command = plan

  variables {
    roles = { r = { sequence_privileges = ["INSERT"] } }
  }

  expect_failures = [var.roles]
}

run "invalid_function_privilege" {
  command = plan

  variables {
    roles = { r = { function_privileges = ["SELECT"] } }
  }

  expect_failures = [var.roles]
}

run "unknown_schema" {
  command = plan

  variables {
    roles = { r = { schemas = ["missing"] } }
  }

  expect_failures = [postgresql_role.role["r"]]
}

run "role_named_like_owner" {
  command = plan

  variables {
    roles = { owner_user = { table_privileges = ["SELECT"] } }
  }

  expect_failures = [postgresql_role.role["owner_user"]]
}

run "roles_without_schemas" {
  command = plan

  variables {
    schemas = []
    roles   = { r = { table_privileges = ["SELECT"] } }
  }

  expect_failures = [postgresql_role.role["r"]]
}
