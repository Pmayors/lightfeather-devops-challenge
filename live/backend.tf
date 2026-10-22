# Remote state is intentionally not active in this root module.
# The state bucket has to exist before this configuration can use it, so it is
# created by the separate stack in ../bootstrap (S3 plus a DynamoDB lock table).
#
# After that stack has been applied, uncomment the block below, fill in the
# bucket name, and run:
#   terraform init -migrate-state
#
# terraform {
#   backend "s3" {
#     bucket         = "REPLACE_ME-lightfeather-tfstate"
#     key            = "live/terraform.tfstate"
#     region         = "us-east-1"
#     dynamodb_table = "lightfeather-tf-locks"
#     encrypt        = true
#   }
# }
