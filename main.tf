terraform {
  required_version = ">= 1.3"

  required_providers {
    postgresql = {
      source  = "cyrilgdn/postgresql"
      version = ">=1.14.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">=3.1.0"
    }
  }
}

resource "random_password" "db_password" {
  length  = var.password_length
  special = false

  keepers = {
    user_name = var.username
  }
}

locals {
  schemas_map = { for sch in var.schemas : sch.name => sch.add_to_search_path }

  role_schemas = {
    for name, r in var.roles : name => distinct(r.schemas == null ? keys(local.schemas_map) : [for sch in r.schemas : sch if contains(keys(local.schemas_map), sch)])
  }

  role_schema_pairs = {
    for pair in flatten([
      for name, schemas in local.role_schemas : [for sch in schemas : { role = name, schema = sch }]
    ]) : "${pair.role}.${pair.schema}" => pair
  }

  role_object_privileges = {
    for name, r in var.roles : name => {
      table    = r.table_privileges
      sequence = r.sequence_privileges
      function = r.function_privileges
    }
  }

  role_object_grants = {
    for object_type in ["table", "sequence", "function"] : object_type => {
      for key, pair in local.role_schema_pairs : key => pair if length(local.role_object_privileges[pair.role][object_type]) > 0
    }
  }

  role_default_privileges = merge([
    for object_type, grants in local.role_object_grants : {
      for key, pair in grants : "${key}.${object_type}" => merge(pair, { object_type = object_type }) if var.roles[pair.role].default_privileges
    }
  ]...)
}

resource "postgresql_role" "db_user" {
  name     = random_password.db_password.keepers.user_name
  password = random_password.db_password.result

  login           = true
  superuser       = false
  create_database = false
  create_role     = false

  search_path = [for name, add_condition in local.schemas_map : name if add_condition == true]
}

resource "postgresql_database" "db" {
  name  = var.db_name
  owner = postgresql_role.db_user.name

  connection_limit  = -1
  allow_connections = true
}

resource "postgresql_schema" "schema" {
  for_each = local.schemas_map

  name     = each.key
  database = postgresql_database.db.name
  owner    = postgresql_role.db_user.name
}

// Removes permissions from the public schema to prevent
// other users in the database instance from being able
// to access it.
resource "postgresql_grant" "revoke_other" {
  database    = postgresql_database.db.name
  role        = postgresql_role.db_user.name
  schema      = "public"
  object_type = "schema"
  privileges  = []
}

// Additional roles own nothing, so they cannot run DDL; the owner role
// keeps the migration rights. Database-level grants are intentionally
// absent because they have no effect when Terraform does not own the database.
resource "random_password" "role" {
  for_each = { for name, r in var.roles : name => r if r.login }

  length  = var.password_length
  special = false

  keepers = {
    user_name = each.key
  }
}

resource "postgresql_role" "role" {
  for_each = var.roles

  name     = each.key
  password = each.value.login ? random_password.role[each.key].result : null

  login            = each.value.login
  superuser        = false
  create_database  = false
  create_role      = false
  connection_limit = each.value.connection_limit

  search_path = [for name, add_condition in local.schemas_map : name if add_condition == true]

  lifecycle {
    precondition {
      condition     = length(var.schemas) > 0
      error_message = "roles requires at least one schema in schemas, because roles are only granted access to the schemas this module creates."
    }

    precondition {
      condition     = each.key != var.username
      error_message = "A role in roles must not have the same name as username."
    }

    precondition {
      condition     = each.value.schemas == null ? true : alltrue([for sch in each.value.schemas : contains(keys(local.schemas_map), sch)])
      error_message = "Every schema listed for a role must exist in schemas."
    }
  }
}

resource "postgresql_grant" "role_schema" {
  for_each = local.role_schema_pairs

  database    = postgresql_database.db.name
  role        = postgresql_role.role[each.value.role].name
  schema      = postgresql_schema.schema[each.value.schema].name
  object_type = "schema"
  privileges  = var.roles[each.value.role].schema_privileges
}

resource "postgresql_grant" "role_tables" {
  for_each = local.role_object_grants.table

  database    = postgresql_database.db.name
  role        = postgresql_role.role[each.value.role].name
  schema      = postgresql_schema.schema[each.value.schema].name
  object_type = "table"
  privileges  = var.roles[each.value.role].table_privileges
}

resource "postgresql_grant" "role_sequences" {
  for_each = local.role_object_grants.sequence

  database    = postgresql_database.db.name
  role        = postgresql_role.role[each.value.role].name
  schema      = postgresql_schema.schema[each.value.schema].name
  object_type = "sequence"
  privileges  = var.roles[each.value.role].sequence_privileges
}

resource "postgresql_grant" "role_functions" {
  for_each = local.role_object_grants.function

  database    = postgresql_database.db.name
  role        = postgresql_role.role[each.value.role].name
  schema      = postgresql_schema.schema[each.value.schema].name
  object_type = "function"
  privileges  = var.roles[each.value.role].function_privileges
}

// Objects the owner role creates later (for example through migrations)
// become usable by the additional roles automatically.
resource "postgresql_default_privileges" "role" {
  for_each = local.role_default_privileges

  database    = postgresql_database.db.name
  owner       = postgresql_role.db_user.name
  role        = postgresql_role.role[each.value.role].name
  schema      = postgresql_schema.schema[each.value.schema].name
  object_type = each.value.object_type
  privileges  = local.role_object_privileges[each.value.role][each.value.object_type]
}
