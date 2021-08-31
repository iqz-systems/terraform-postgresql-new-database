# terraform-postgresql-new-database

Terraform module to create a new database using the [postgresql](https://registry.terraform.io/providers/cyrilgdn/postgresql/latest/docs) provider. You can use this module to quickly create a database and an associated user for the db.

## Requirements

You should [configure](https://registry.terraform.io/providers/cyrilgdn/postgresql/latest/docs#usage) the postgresql provider in order to use this module.

## Usage

```hcl
module "cloud_sql" {
  source = "./cloud-sql"

  username          = "app_db_user"
  db_name           = "app_db"
  password_length   = 32
}
```
