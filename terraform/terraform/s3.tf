###################################
# S3 bucket
###################################
resource "aws_s3_bucket" "dbt-bucket" {
  bucket = var.dbt_s3_bucket
}
