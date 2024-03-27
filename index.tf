terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.41.0"
    }
  }
}


# Configure the AWS Provider
provider "aws" {
  region = "ap-southeast-1"
}

# Public Bucket

resource "aws_s3_bucket" "guna_bucket" {
  bucket = "vpcbucketgun1"
}

resource "aws_s3_bucket_ownership_controls" "owner" {
  bucket = aws_s3_bucket.guna_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_public_access_block" "access" {
  bucket = aws_s3_bucket.guna_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_acl" "acl_access" {
  depends_on = [
    aws_s3_bucket_ownership_controls.owner,
    aws_s3_bucket_public_access_block.access,
  ]

  bucket = aws_s3_bucket.guna_bucket.id
  acl    = "public-read"
}


#Backup

/*#terraform {
  backend "s3" {
    bucket = "vpcbucketgun1"
    key    = "path/to/my/key"
    region = "us-east-1"
  }
}*/




#VPC

resource "aws_vpc" "project" {
  cidr_block = "20.0.0.0/16"
  instance_tenancy = "default"
  tags = {
    Name = "Guna VPC"
  }
}


#private subnet
resource "aws_subnet" "private_subnet" {
  vpc_id     = aws_vpc.project.id
  cidr_block = "20.0.0.0/24"
tags = {
    Name = "Private Subnet"
  }
}
#public subnet
resource "aws_subnet" "public_subnet" {
  vpc_id     = aws_vpc.project.id
  cidr_block = "20.0.1.0/24"
tags = {
    Name = "public subnet"
  }
}
#public security group

resource "aws_security_group" "public_securitygroup" {
  name        = "public_securitygroup"
  description = "Allow TLS inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.project.id
tags = {
    Name = "public security group"
  }
  
  
}

#public security group rules

resource "aws_vpc_security_group_ingress_rule" "public_securitygrouprule" {
  security_group_id = aws_security_group.public_securitygroup.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 0
  ip_protocol       = "tcp"

  to_port           = 65535
}
resource "aws_vpc_security_group_egress_rule" "public_securitygrouprule1" {
  security_group_id = aws_security_group.public_securitygroup.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

#private security group

resource "aws_security_group" "private_securitygroup" {
  name        = "private_securitygroup"
  
  vpc_id      = aws_vpc.project.id
    tags = {
    Name = "Private security group"
  }
  
  
}

#private security group rules

resource "aws_vpc_security_group_ingress_rule" "private_securitygrouprule" {
  security_group_id = aws_security_group.private_securitygroup.id
  cidr_ipv4         = aws_subnet.public_subnet.cidr_block
  from_port         = 22
  ip_protocol       = "TCP"
  to_port           = 22
  
}
resource "aws_vpc_security_group_ingress_rule" "private_securitygrouprule1" {
  security_group_id = aws_security_group.private_securitygroup.id
  cidr_ipv4         = aws_subnet.public_subnet.cidr_block
  from_port         = 3389
  ip_protocol       = "TCP"
  to_port           = 3389
  
}


resource "aws_vpc_security_group_egress_rule" "private_securitygrouprule2" {
  security_group_id = aws_security_group.private_securitygroup.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

#internet gateway

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.project.id
    tags = {
    Name = "IGW"
  }
  
}



#public route table

resource "aws_route_table" "route" {
  vpc_id = aws_vpc.project.id
  route{
    cidr_block = "0.0.0.0/0"
   gateway_id = aws_internet_gateway.gw.id
}
    tags = {
    Name = "public route table"
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.route.id
}


#private route table

resource "aws_route_table" "route1" {
  vpc_id = aws_vpc.project.id
  tags = {
    Name = "Private Route table"
  }
  route{
    cidr_block = "0.0.0.0/0"
   nat_gateway_id = aws_nat_gateway.nat.id
}
}

resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.route1.id
}

# public nstances

resource "aws_key_pair" "keey" {
  key_name   = "keey"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCbbtH89A2cUq2lRbBTHZoi4Y6poLA7cIOzyKpQ/OALRqZypIAkh8VL9crAPZrNawJu7Iw8HNmEQboOpERSfOvY3N27WnX5yUHCMqa6wkMqwIRyxidAgN+WA3l5Kk7aT7Qys0/hZt6l8M43xnb/ip99hHzGLd/be/4VvGuRmDNPqI3DW+nwyHXg6Kt4Q5kyF9MvB/7hUnY+uq9lJQtjmf0BJa7LZGNW05qPRnIvZjWjir8IU5Bf9LPgIIuqjb1mnRXoJA+6bY9VHrMvyXNTIfbMFW0JBgt7SkZVHvtCRngzQFeJGgtz3yccM1bF0hCyJsHWvKTvU5H8/oUiUJLNwZTZ"
}

resource "aws_instance" "Pub_inst" {
  ami           = "ami-0516715c2acda76a8"
  instance_type = "t2.micro"
  key_name      = "keey"
  

 
   
    subnet_id     = aws_subnet.public_subnet.id
    associate_public_ip_address = true
 
  
 
    vpc_security_group_ids = [aws_security_group.public_securitygroup.id]
 


  tags = {
    Name = "public instance"
  }
}

#private instances


resource "aws_instance" "Priv_inst" {
  ami           = "ami-0516715c2acda76a8"
  instance_type = "t2.micro"
  key_name      = "keey"
 
   
    subnet_id     = aws_subnet.private_subnet.id
    associate_public_ip_address = false
 
  
 
    vpc_security_group_ids = [aws_security_group.private_securitygroup.id]
 


  tags = {
    Name = "private  instance"
  }
}


#NAT

resource "aws_eip" "eipalloc" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.eipalloc.id
  subnet_id     = aws_subnet.public_subnet.id

}



