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
