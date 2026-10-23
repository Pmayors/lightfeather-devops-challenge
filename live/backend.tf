# I left remote state commented out. The bucket has to exist before this stack can use it.
# I create that bucket and the DynamoDB lock table from ../bootstrap.
#
# After I apply bootstrap, I uncomment the block, put my bucket name in, and run:
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
