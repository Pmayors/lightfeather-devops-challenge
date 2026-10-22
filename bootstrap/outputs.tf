output "state_bucket_name" {
  description = "Bucket to put in the live backend block."
  value       = aws_s3_bucket.state.bucket
}

output "lock_table_name" {
  description = "DynamoDB table to put in the live backend block."
  value       = aws_dynamodb_table.lock.name
}
