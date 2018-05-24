variable "aws_region" {}
variable "aws_profile" {}
variable "ssh_key_name" {}
variable "inbound_cidr" {}

variable "tags" {
  default = {
    "project" = "terraform-s3-ec2"
    "client"  = "Internal"
  }
}

variable "test_vpc_cidr" {
  default = "172.40.0.0/16"
}

variable "ami_name" {
  default = "amzn2-ami-hvm-2017.12.0.20180509-x86_64-gp2"
}

variable "root_vol_size" {
  default = 8
}

variable "instance_type" {
  default = "t2.micro"
}

variable "open_bucket_prefix" {
  default = "s3ec2test-open-"
}

variable "closed_bucket_prefix" {
  default = "s3ec2test-closed-"
}
