terraform {
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
  role        = "public"
  schema      = "public"
  object_type = "schema"
  privileges  = []
}
