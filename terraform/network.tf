# ----------------------------------------------------------------------------------------
# setup a VPC containing a single subnet, with an internet gateway, and a route table
# to send traffic to and from the subnet via that gateway.
# ----------------------------------------------------------------------------------------
resource "aws_vpc" "test_vpc" {
  cidr_block           = "${var.test_vpc_cidr}"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = "${merge(map("Name","s3ec2test"), var.tags)}"
}

resource "aws_subnet" "s3ec2test" {
  vpc_id                  = "${aws_vpc.test_vpc.id}"
  cidr_block              = "${cidrsubnet(var.test_vpc_cidr, 8, 1)}"
  map_public_ip_on_launch = true
  tags                    = "${merge(map("Name","s3ec2test"), var.tags)}"
}

resource "aws_internet_gateway" "s3ec2test" {
  vpc_id = "${aws_vpc.test_vpc.id}"
  tags   = "${merge(map("Name","s3ec2test-gateway"), var.tags)}"
}

resource "aws_route_table" "s3ec2test" {
  vpc_id = "${aws_vpc.test_vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.s3ec2test.id}"
  }

  tags = "${merge(map("Name","s3ec2test-rt"), var.tags)}"
}

resource "aws_route_table_association" "s3ec2test" {
  subnet_id      = "${aws_subnet.s3ec2test.id}"
  route_table_id = "${aws_route_table.s3ec2test.id}"
}
