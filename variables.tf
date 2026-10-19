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

variable "roles" {
  description = "Additional roles to create, keyed by role name. Each role owns nothing and gets the listed privileges on the schemas this module creates."
  type = map(object({
    login               = optional(bool, true)
    connection_limit    = optional(number, -1)
    schemas             = optional(list(string))
    schema_privileges   = optional(list(string), ["USAGE"])
    table_privileges    = optional(list(string), [])
    sequence_privileges = optional(list(string), [])
    function_privileges = optional(list(string), [])
    default_privileges  = optional(bool, true)
  }))
  default  = {}
  nullable = false

  validation {
    condition     = alltrue([for r in var.roles : length(setsubtract(r.schema_privileges, ["USAGE", "CREATE"])) == 0])
    error_message = "schema_privileges may only contain USAGE and CREATE."
  }

  validation {
    condition     = alltrue([for r in var.roles : length(setsubtract(r.table_privileges, ["SELECT", "INSERT", "UPDATE", "DELETE", "TRUNCATE", "REFERENCES", "TRIGGER"])) == 0])
    error_message = "table_privileges may only contain SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES and TRIGGER."
  }

  validation {
    condition     = alltrue([for r in var.roles : length(setsubtract(r.sequence_privileges, ["USAGE", "SELECT", "UPDATE"])) == 0])
    error_message = "sequence_privileges may only contain USAGE, SELECT and UPDATE."
  }

  validation {
    condition     = alltrue([for r in var.roles : length(setsubtract(r.function_privileges, ["EXECUTE"])) == 0])
    error_message = "function_privileges may only contain EXECUTE."
  }
}
