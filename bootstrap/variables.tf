variable "aws_region" {
  description = "Region for the state bucket and lock table."
  type        = string
  default     = "us-east-1"
}

variable "state_bucket_name" {
  description = "Globally unique bucket name for Terraform state."
  type        = string
}

variable "lock_table_name" {
  description = "DynamoDB table used as the Terraform lock."
  type        = string
  default     = "lightfeather-tf-locks"
}
