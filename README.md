# terraform-postgresql-new-database

Terraform module to create a new database using the [postgresql](https://registry.terraform.io/providers/cyrilgdn/postgresql/latest/docs) provider. You can use this module to quickly create a database, an owner role for it and, optionally, any number of additional roles with explicitly listed privileges.

This module makes use of Hashicorp's [random](https://registry.terraform.io/providers/hashicorp/random/latest/docs) provider to generate passwords.

## Requirements

The caller must [configure](https://registry.terraform.io/providers/cyrilgdn/postgresql/latest/docs#usage) the postgresql provider in order to use this module. The module does not configure the connection. This includes connections to Cloud SQL, which are configured by the caller, for example with `scheme = "gcppostgres"` in the provider block.

## Usage

```hcl
module "app_db" {
  source          = "iqz-systems/new-database/postgresql"
  version         = "5.1.0"
  username        = "app_db_user"
  db_name         = "app_db"
  password_length = 32
}
```

### Owner and additional roles

Database-level privileges are left at the PostgreSQL defaults (PUBLIC keeps `CONNECT` and `TEMPORARY`, and the additional roles connect through that), because the provider cannot change them when Terraform connects as a non-superuser that does not own the database, such as the default user of Cloud SQL.

The owner role (`username`) owns the database and the schemas and is intended for migrations. Each role in `roles` owns nothing and only receives the privileges listed for it on the schemas created by this module. Objects created later by the owner role are made available to those roles through default privileges, unless `default_privileges` is `false`.

A read-write application role and a read-only reporting role:

```hcl
module "app_db" {
  source   = "iqz-systems/new-database/postgresql"
  version  = "5.1.0"
  username = "app_db_owner"
  db_name  = "app_db"

  schemas = [
    { name = "app", add_to_search_path = true },
  ]

  roles = {
    app_db_user = {
      table_privileges    = ["SELECT", "INSERT", "UPDATE", "DELETE"]
      sequence_privileges = ["USAGE", "SELECT"]
      function_privileges = ["EXECUTE"]
    }
    app_db_reporting = {
      table_privileges = ["SELECT"]
    }
  }
}
```

A group role that cannot log in, to which other roles can be added as members outside this module:

```hcl
module "app_db" {
  source   = "iqz-systems/new-database/postgresql"
  version  = "5.1.0"
  username = "app_db_owner"
  db_name  = "app_db"

  schemas = [
    { name = "app", add_to_search_path = true },
    { name = "audit", add_to_search_path = false },
  ]

  roles = {
    app_readers = {
      login            = false
      schemas          = ["app"]
      table_privileges = ["SELECT"]
    }
  }
}
```

## Variables

- `db_name` string
  - The name of the database to be created.
- `username` string
  - The database username to be created. This role owns the database and the schemas.
- `password_length` number
  - The length of the passwords to be created.
  - Default: `64`
- `schemas` list of objects
  - A list of schemas to create in the database. Each object has `name` (string) and `add_to_search_path` (bool). Schemas with `add_to_search_path = true` are added to the search path of the created roles.
  - Default: `[]`
- `roles` map of objects
  - Additional roles to create, keyed by role name. Each role owns nothing and gets the listed privileges on the schemas this module creates. At least one schema is required when `roles` is not empty, and a role must not have the same name as `username`.
  - Default: `{}`
  - Attributes of each role:
    - `login` bool: whether the role can log in. A password is generated only for roles with login. Default: `true`
    - `connection_limit` number: the maximum number of concurrent connections, `-1` for no limit. Default: `-1`
    - `schemas` list of strings: the schemas to grant on, each of which must exist in `schemas`. Default: `null`, which means every schema in `schemas`
    - `schema_privileges` list of strings: privileges on each schema. Default: `["USAGE"]`
    - `table_privileges` list of strings: privileges on all tables in each schema. Default: `[]`
    - `sequence_privileges` list of strings: privileges on all sequences in each schema. Default: `[]`
    - `function_privileges` list of strings: privileges on all functions in each schema. Default: `[]`
    - `default_privileges` bool: whether the table, sequence and function privileges are also applied to objects the owner role creates later. Default: `true`

Allowed privileges per object type:

| Attribute | Allowed values |
|---|---|
| `schema_privileges` | `USAGE`, `CREATE` |
| `table_privileges` | `SELECT`, `INSERT`, `UPDATE`, `DELETE`, `TRUNCATE`, `REFERENCES`, `TRIGGER` |
| `sequence_privileges` | `USAGE`, `SELECT`, `UPDATE` |
| `function_privileges` | `EXECUTE` |

An empty list for tables, sequences or functions creates no grant and no default privileges for that object type.

## Outputs

- `db_name` string
  - The name of the database.
- `db_username` string
  - The username using which the database can be accessed.
- `db_password` string, sensitive
  - The password associated with the user for the database.
- `schemas` map of objects
  - The created schema objects, keyed by schema name.
- `roles` map of objects, sensitive
  - The additional roles, keyed by role name. Each object has `name` and `password`. `password` is `null` for roles without login.

## Tests

Run `terraform init -backend=false` and then `terraform test`. The tests use mocked providers and do not need a database.

## Links

- [Terraform registry](https://registry.terraform.io/modules/iqz-systems/new-database/postgresql/latest)
