variable "username" {
  type        = string
  description = "The database username to be created."
}

variable "db_name" {
  type        = string
  description = "The name of the database to be created."
}

variable "password_length" {
  type        = number
  description = "The length of the password to be created."
  default     = 64
}
