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

variable "schemas" {
  type = list(object({
    name               = string
    add_to_search_path = bool
  }))
  description = "A list of schemas to create in the database with the option to add to search path for the user."
  default     = []
  sensitive   = false
}
