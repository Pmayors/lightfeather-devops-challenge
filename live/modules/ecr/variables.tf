variable "project" {
  description = "Name prefix for repository names."
  type        = string
}

variable "repositories" {
  description = "Application names. Each one becomes its own repository."
  type        = set(string)
}
