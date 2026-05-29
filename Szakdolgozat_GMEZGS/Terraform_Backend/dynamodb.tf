resource "aws_dynamodb_table" "image_metadatas_table_gmezgs" {
  name         = "image-metadatas-table-gmezgs"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "FileName"

  attribute {
    name = "FileName"
    type = "S"
  }

  ttl {
    attribute_name = "TimeToExist"
    enabled        = true
  }

  tags = {
    Name        = "dynamodb-table-1"
    Environment = "production"
  }
}