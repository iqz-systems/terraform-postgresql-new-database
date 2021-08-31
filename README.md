# terraform-postgresql-new-database

Terraform module to create a new database using the [postgresql](https://registry.terraform.io/providers/cyrilgdn/postgresql/latest/docs) provider. You can use this module to quickly create a database and an associated user for the db.

This module makes use of Hashicorp's [random](https://registry.terraform.io/providers/hashicorp/random/latest/docs) provider to generate passwords.

## Requirements

You should [configure](https://registry.terraform.io/providers/cyrilgdn/postgresql/latest/docs#usage) the postgresql provider in order to use this module.

## Usage

```hcl
module "app_db" {
  source            = "iqz-systems/new-database/postgresql"
  version           = "1.0.1"
  username          = "app_db_user"
  db_name           = "app_db"
  password_length   = 32
}
```

## Variables

- `db_name` string
  - The name of the database to be created.
- `username` string
  - The database username to be created.
- `password_length` number
  - The length of the password to be created.
  - Default: `64`

## Outputs

- `db_name` string
  - The name of the database.
- `db_username` string
  - The username using which the database can be accessed.
- `db_password` string
  - The password associated with the user for the database.

## Links

- [Terraform registry](https://registry.terraform.io/modules/iqz-systems/new-database/postgresql/latest)
