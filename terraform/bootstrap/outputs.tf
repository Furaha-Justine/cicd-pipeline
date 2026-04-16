output "bucket_name" {
  value = aws_s3_bucket.tfstate.bucket
}

output "dynamodb_table" {
  value = aws_dynamodb_table.tfstate_lock.name
}

output "next_step" {
  value = "Update terraform/backend.tf — set bucket = \"${aws_s3_bucket.tfstate.bucket}\""
}
