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
#  lookups
# ----------------------------------------------------------------------------------------

data "aws_ip_ranges" "s3ip" {
  regions  = ["${var.aws_region}"]
  services = ["s3"]
}

data "aws_ip_ranges" "s3ip-useast1" {
  regions  = ["us-east-1"]
  services = ["s3"]
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

# allow AWS requests
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

resource "aws_security_group" "allow_yum_out" {
  vpc_id      = "${aws_vpc.test_vpc.id}"
  name_prefix = "s3ec2test"
  description = "Allow output http for yum"

  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["52.95.0.0/16"]
  }

  tags = "${merge(map("Name","s3ec2test-yum-out"), var.tags)}"
}

resource "aws_security_group" "allow_s3_out" {
  vpc_id      = "${aws_vpc.test_vpc.id}"
  name_prefix = "s3ec2test"
  description = "Allow output https for AWS  S3 access"

  # eu-west-2 prefix list
  egress {
    from_port = 443
    to_port   = 443
    protocol  = "tcp"

    cidr_blocks = ["${data.aws_ip_ranges.s3ip.cidr_blocks}"]
  }

  # us-east-1 prefix list - this allows S3 from the cli to work, but not other things.
  egress {
    from_port = 443
    to_port   = 443
    protocol  = "tcp"

    cidr_blocks = ["${data.aws_ip_ranges.s3ip-useast1.cidr_blocks}"]
  }

  tags = "${merge(map("Name","s3ec2test-s3-out"), var.tags)}"
}

resource "aws_security_group" "eu_west_1_part_1" {
  vpc_id      = "${aws_vpc.test_vpc.id}"
  name_prefix = "s3ec2test"
  description = "Allow access to AWS services"

  egress {
    from_port = 443
    to_port   = 443
    protocol  = "tcp"

    cidr_blocks = ["172.96.98.0/24", "176.32.104.0/21", "176.34.128.0/17", "176.34.159.192/26",
      "176.34.64.0/18", "178.236.0.0/20", "18.200.0.0/16", "18.201.0.0/16", "18.202.0.0/15",
      "185.143.16.0/24", "185.48.120.0/22", "34.240.0.0/13", "34.245.205.0/27", "34.245.205.64/27",
      "34.248.0.0/13", "34.250.63.248/29", "46.137.0.0/17", "46.137.128.0/18", "46.51.128.0/18",
      "46.51.192.0/20", "52.119.192.0/22", "52.119.240.0/21", "52.144.208.128/26", "52.144.208.192/26",
      "52.144.208.64/26", "52.144.210.0/26", "52.144.210.128/26", "52.16.0.0/15", "52.18.0.0/15",
      "52.208.0.0/13", "52.212.248.0/26", "52.218.0.0/17", "52.30.0.0/15", "52.46.240.0/22",
      "52.48.0.0/14", "52.92.40.0/21", "52.93.0.0/24", "52.93.112.34/32", "52.93.112.35/32",
      "52.93.16.0/24", "52.93.17.16/32", "52.93.17.17/32", "52.93.18.178/32", "52.93.18.179/32",
      "52.93.2.0/24", "52.93.21.14/32", "52.93.21.15/32", "52.94.196.0/24", "52.94.216.0/21",
      "52.94.24.0/23",
    ]
  }
}

resource "aws_security_group" "eu_west_1_part_2" {
  vpc_id      = "${aws_vpc.test_vpc.id}"
  name_prefix = "s3ec2test"
  description = "Allow access to AWS services"

  egress {
    from_port = 443
    to_port   = 443
    protocol  = "tcp"

    cidr_blocks = ["52.94.248.16/28", "52.94.26.0/23", "52.94.5.0/24", "52.95.104.0/22",
      "52.95.112.0/20", "52.95.244.0/24", "52.95.255.64/28", "52.95.60.0/24", "52.95.61.0/24",
      "54.154.0.0/16", "54.155.0.0/16", "54.170.0.0/15", "54.194.0.0/15", "54.216.0.0/15",
      "54.220.0.0/16", "54.228.0.0/16", "54.228.16.0/26", "54.229.0.0/16", "54.231.128.0/19",
      "54.239.0.48/28", "54.239.32.0/21", "54.239.99.0/24", "54.240.197.0/24", "54.240.220.0/22",
      "54.246.0.0/16", "54.247.0.0/16", "54.72.0.0/15", "54.74.0.0/15", "54.76.0.0/15",
      "54.78.0.0/16", "63.32.0.0/14", "79.125.0.0/17", "87.238.80.0/21", "99.80.0.0/15",
    ]
  }
}

resource "aws_security_group" "us_east_1_part_1" {
  vpc_id      = "${aws_vpc.test_vpc.id}"
  name_prefix = "s3ec2test"
  description = "Allow access to AWS services"

  egress {
    from_port = 443
    to_port   = 443
    protocol  = "tcp"

    cidr_blocks = ["100.24.0.0/13", "107.20.0.0/14", "107.23.255.0/26", "172.96.97.0/24",
      "174.129.0.0/16", "176.32.120.0/22", "176.32.96.0/21", "18.204.0.0/14", "18.208.0.0/13",
      "18.232.0.0/14", "18.233.213.128/25", "184.72.128.0/17", "184.72.64.0/18", "184.73.0.0/16",
      "204.236.192.0/18", "205.251.224.0/22", "205.251.240.0/22", "205.251.244.0/23", "205.251.246.0/24",
      "205.251.247.0/24", "205.251.248.0/24", "207.171.160.0/20", "207.171.176.0/20", "216.182.224.0/21",
      "216.182.232.0/22", "216.182.238.0/23", "23.20.0.0/14", "34.192.0.0/12", "34.195.252.0/24",
      "34.224.0.0/12", "34.226.14.0/24", "34.228.4.208/28", "34.232.163.208/29", "35.153.0.0/16",
      "35.168.0.0/13", "35.172.155.192/27", "35.172.155.96/27", "50.16.0.0/15", "50.19.0.0/16",
      "52.0.0.0/15", "52.119.196.0/22", "52.119.206.0/23", "52.119.212.0/23", "52.119.214.0/23",
      "52.119.224.0/21", "52.119.232.0/21", "52.144.192.0/26", "52.144.192.128/26", "52.144.192.192/26",
      "52.144.192.64/26",
    ]
  }
}

resource "aws_security_group" "us_east_1_part_2" {
  vpc_id      = "${aws_vpc.test_vpc.id}"
  name_prefix = "s3ec2test"
  description = "Allow access to AWS services"

  egress {
    from_port = 443
    to_port   = 443
    protocol  = "tcp"

    cidr_blocks = ["52.144.193.0/26", "52.144.193.128/26", "52.144.193.64/26", "52.144.194.0/26",
      "52.144.195.0/26", "52.2.0.0/15", "52.20.0.0/14", "52.200.0.0/13", "52.216.0.0/15",
      "52.4.0.0/14", "52.44.0.0/15", "52.46.128.0/19", "52.46.164.0/23", "52.46.168.0/23",
      "52.46.170.0/23", "52.54.0.0/15", "52.55.191.224/27", "52.70.0.0/15", "52.72.0.0/15",
      "52.86.0.0/15", "52.90.0.0/15", "52.92.16.0/20", "52.93.1.0/24", "52.93.249.0/24",
      "52.93.3.0/24", "52.93.4.0/24", "52.93.51.28/32", "52.93.51.29/32", "52.94.0.0/22",
      "52.94.124.0/22", "52.94.192.0/22", "52.94.224.0/20", "52.94.240.0/22", "52.94.244.0/22",
      "52.94.248.0/28", "52.94.252.0/23", "52.94.254.0/23", "52.94.68.0/24", "52.95.108.0/23",
      "52.95.245.0/24", "52.95.255.80/28", "52.95.48.0/22", "52.95.62.0/24", "52.95.63.0/24",
      "54.144.0.0/14", "54.152.0.0/16", "54.156.0.0/14", "54.160.0.0/13", "54.172.0.0/15",
      "54.174.0.0/15",
    ]
  }
}

resource "aws_security_group" "us_east_1_part_3" {
  vpc_id      = "${aws_vpc.test_vpc.id}"
  name_prefix = "s3ec2test"
  description = "Allow access to AWS services"

  egress {
    from_port = 443
    to_port   = 443
    protocol  = "tcp"

    cidr_blocks = ["54.196.0.0/15", "54.198.0.0/16", "54.204.0.0/15", "54.208.0.0/15", "54.210.0.0/15",
      "54.221.0.0/16", "54.224.0.0/15", "54.226.0.0/15", "54.231.0.0/17", "54.231.244.0/22",
      "54.234.0.0/15", "54.236.0.0/15", "54.239.0.0/28", "54.239.104.0/23", "54.239.108.0/22",
      "54.239.16.0/20", "54.239.8.0/21", "54.239.98.0/24", "54.240.196.0/24", "54.240.202.0/24",
      "54.240.208.0/22", "54.240.216.0/22", "54.240.228.0/23", "54.240.232.0/22", "54.242.0.0/15",
      "54.243.31.192/26", "54.80.0.0/13", "54.88.0.0/14", "54.92.128.0/17", "67.202.0.0/18",
      "72.21.192.0/19", "72.44.32.0/19", "75.101.128.0/17", "76.223.191.0/25", "76.223.191.128/25",
    ]
  }
}
