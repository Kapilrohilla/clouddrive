

terraform {
	required_providers {
	  aws = {
		source= "hashicorp/aws",
		version= "~> 6.0"
	  }
	}
}

provider "aws" {
	region = "ap-south-1"
	# access_key = var.aws_api_key
	# secret_key = var.aws_secret_key
}

# resource "example_vpc" "example" {
#   cidr_block = "10.0.0.0/16"
# }

resource "aws_instance" "example" {
	ami = "ami-0f5ee92e2d63afc18" # ubuntu 20.04 LTS
	instance_type = "t2.micro"
	
	tags = {
		Name = "terraform-example"
	}
}
resource "aws_s3_bucket" "example" {
  bucket = format(
    "my-tf-test-%s-an",
    data.aws_caller_identity.current.account_id
  )

  tags = {
    Name        = "terraform-example"
    Environment = "Development"
  }
}