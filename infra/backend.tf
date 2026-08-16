terraform {
  backend "s3" {
	bucket = "kapil-terraform-state-bucket-022499000177"
	key = "cloudDrive/terraform.tfstate"
	region = "ap-south-1"
	dynamodb_table = "terraform-state-lock"
  }
}