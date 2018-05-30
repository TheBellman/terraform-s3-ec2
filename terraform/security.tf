# seal off the default NACL
resource "aws_default_network_acl" "test_default" {
  default_network_acl_id = "${aws_vpc.test_vpc.default_network_acl_id}"
  tags                   = "${merge(map("Name","s3ec2test-default"), var.tags)}"
}

# seal off the default security group
resource "aws_default_security_group" "test_default" {
  vpc_id = "${aws_vpc.test_vpc.id}"
  tags   = "${merge(map("Name","s3ec2test-default"), var.tags)}"
}

# ----------------------------------------------------------------------------------------
#  NACL for the test subnet
# ----------------------------------------------------------------------------------------

resource "aws_network_acl" "s3ec2test" {
  vpc_id     = "${aws_vpc.test_vpc.id}"
  subnet_ids = ["${aws_subnet.s3ec2test.id}"]
  tags       = "${merge(map("Name","s3ec2test"), var.tags)}"
}

# accept SSH requets
resource "aws_network_acl_rule" "ssh_in" {
  network_acl_id = "${aws_network_acl.s3ec2test.id}"
  rule_number    = 100
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "${var.inbound_cidr}"
  from_port      = 22
  to_port        = 22
}

# accept responses to YUM requets
resource "aws_network_acl_rule" "ephemeral_in" {
  network_acl_id = "${aws_network_acl.s3ec2test.id}"
  rule_number    = 200
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
}

# allow responses to SSH requests
resource "aws_network_acl_rule" "ephemeral_out" {
  network_acl_id = "${aws_network_acl.s3ec2test.id}"
  rule_number    = 100
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "${var.inbound_cidr}"
  from_port      = 1024
  to_port        = 65535
}

# allow YUM requests
resource "aws_network_acl_rule" "http_out" {
  network_acl_id = "${aws_network_acl.s3ec2test.id}"
  rule_number    = 200
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 80
  to_port        = 80
}

# allow pip3 requests
resource "aws_network_acl_rule" "https_out" {
  network_acl_id = "${aws_network_acl.s3ec2test.id}"
  rule_number    = 210
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 443
  to_port        = 443
}

# ----------------------------------------------------------------------------------------
#  security group allowing SSH in
# ----------------------------------------------------------------------------------------
resource "aws_security_group" "allow_ssh" {
  vpc_id      = "${aws_vpc.test_vpc.id}"
  name_prefix = "s3ec2test"
  description = "Allow all inbound ssh"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.inbound_cidr}"]
  }

  tags = "${merge(map("Name","s3ec2test-ssh-in"), var.tags)}"
}

resource "aws_security_group" "allow_http_out" {
  vpc_id      = "${aws_vpc.test_vpc.id}"
  name_prefix = "s3ec2test"
  description = "Allow output http and https"

  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["52.95.0.0/16"]
  }

  tags = "${merge(map("Name","s3ec2test-http-out"), var.tags)}"
}
