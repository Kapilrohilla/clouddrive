terraform {
	required_providers {
		aws = {
			source = "hashicorp/aws"
			version = "~> 6.0"
		}
	}
}

provider "aws" {
	region = "ap-south-1"
}

# create a vpc for cloud drive application
resource "aws_vpc" "cloudDrive_vpc" {
	cidr_block = "10.0.0.0/16"

	tags = {
		CreatedBy = "Terraform"
		Environment = "Development"
		Project = "CloudDrive"
	}
}

resource "aws_subnet" "cloudDrive_subnet_pvt1" {
	vpc_id = aws_vpc.cloudDrive_vpc.id
	cidr_block = "10.0.1.0/24"
	availability_zone = "ap-south-1a" // private subnet 1

	tags = {
		CreatedBy = "Terraform"
		Environment = "Development"
		Project = "CloudDrive"
	}
}

resource "aws_subnet" "cloudDrive_subnet_pvt2" {
	vpc_id = aws_vpc.cloudDrive_vpc.id
	cidr_block = "10.0.2.0/24"
	availability_zone = "ap-south-1b" // private subnet 2

	tags = {
		CreatedBy = "Terraform"
		Environment = "Development"
		Project = "CloudDrive"
	}
}


resource "aws_subnet" "cloudDrive_subnet_pub1" {
	vpc_id = aws_vpc.cloudDrive_vpc.id
	cidr_block = "10.0.3.0/24"
	availability_zone = "ap-south-1a" // public subnet 1
	map_public_ip_on_launch = true

	tags = {
		CreatedBy = "Terraform"
		Environment = "Development"
		Project = "CloudDrive"
	}
}

resource "aws_subnet" "cloudDrive_subnet_pub2" {
	vpc_id = aws_vpc.cloudDrive_vpc.id
	cidr_block = "10.0.4.0/24"
	availability_zone = "ap-south-1b" // public subnet 2
	map_public_ip_on_launch = true

	tags = {
		CreatedBy = "Terraform"
		Environment = "Development"
		Project = "CloudDrive"
	}
}

resource "aws_internet_gateway" "cloud-drive-igw" {
	vpc_id = aws_vpc.cloudDrive_vpc.id
	
	tags = {
		CreatedBy = "Terraform"
		Environment = "Development"
		Project = "CloudDrive"
	}
}



resource "aws_route_table" "cloudDrive_route_table" {
	vpc_id = aws_vpc.cloudDrive_vpc.id

	route {
		cidr_block = "0.0.0.0/0"
		gateway_id = aws_internet_gateway.cloud-drive-igw.id
	}

	tags = {
		CreatedBy = "Terraform"
		Environment = "Development"
		Project = "CloudDrive"
	}
}

resource "aws_route_table_association" "cloudDrive_pub1_rta" {
  subnet_id      = aws_subnet.cloudDrive_subnet_pub1.id
  route_table_id = aws_route_table.cloudDrive_route_table.id
}

resource "aws_route_table_association" "cloudDrive_pub2_rta" {
  subnet_id      = aws_subnet.cloudDrive_subnet_pub2.id
  route_table_id = aws_route_table.cloudDrive_route_table.id
}

# create security group for alb
resource "aws_security_group" "cloudDrive_alb_sg" {
	name = "cloudDrive-alb-sg"
	description = "Security group for alb"
	vpc_id = aws_vpc.cloudDrive_vpc.id

	ingress {
		from_port = 0
		to_port = 0
		protocol = "-1"
		cidr_blocks = ["0.0.0.0/0"]
	}

	egress {
		from_port = 0
		to_port = 0
		protocol = "-1"
		cidr_blocks = ["0.0.0.0/0"]
	}
}

# create security group for api

resource "aws_security_group" "cloudDrive_api_sg" {
	name = "cloudDrive-api-sg"
	description = "Security group for api server"
	vpc_id = aws_vpc.cloudDrive_vpc.id
}


resource "aws_instance" "cloudDrive_api" {
	for_each = toset(["api1", "api2"])
	ami = "ami-0f5ee92e2d63afc18" # ubuntu 20.04 LTS
	instance_type = "t2.micro"
	subnet_id = each.value == "api1" ? aws_subnet.cloudDrive_subnet_pub1.id : aws_subnet.cloudDrive_subnet_pub2.id
	security_groups = [aws_security_group.cloudDrive_api_sg.id]
	associate_public_ip_address = true

	tags = {
		CreatedBy = "Terraform"
		Environment = "Development"
		Project = "CloudDrive"
	}
}



resource "aws_instance" "cloudDrive_worker" {
	ami = "ami-0f5ee92e2d63afc18" # ubuntu 20.04 LTS
	instance_type = "t2.micro"
	tags = {
		CreatedBy = "Terraform"
		Environment = "Development"
		Project = "CloudDrive"
	}
}