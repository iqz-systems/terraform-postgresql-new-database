output "db_name" {
  value       = postgresql_database.db.name
  sensitive   = false
  description = "The names of the database."
}

output "db_username" {
  value       = postgresql_role.db_user.name
  sensitive   = false
  description = "The username using which the database can be accessed."
}

output "db_password" {
  value       = postgresql_role.db_user.password
  sensitive   = true
  description = "The password associated with the user for the database."
}
