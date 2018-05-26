# --------------------------------------------------------------------------------------------------------------
# various data lookups
# --------------------------------------------------------------------------------------------------------------

data "aws_ami" "target_ami" {
  most_recent = true

  filter {
    name   = "owner-alias"
    values = ["amazon"]
  }

  filter {
    name   = "name"
    values = ["${var.ami_name}"]
  }
}

# ----------------------------------------------------------------------------------------
# some S3 buckets.
# ----------------------------------------------------------------------------------------
resource "aws_s3_bucket" "s3_open" {
  bucket_prefix = "${var.open_bucket_prefix}"
  acl           = "private"
  region        = "${var.aws_region}"
  tags          = "${merge(map("Name","s3-open"), var.tags)}"
}

resource "aws_s3_bucket" "s3_closed" {
  bucket_prefix = "${var.closed_bucket_prefix}"
  acl           = "private"
  region        = "${var.aws_region}"
  tags          = "${merge(map("Name","s3-closed"), var.tags)}"
}


resource "aws_s3_bucket_policy" "s3_open" {
  bucket = "${aws_s3_bucket.s3_open.id}"
  policy =<<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Deny",
      "Principal": "*",
      "Action":["s3:Get*"],
      "Resource": "${aws_s3_bucket.s3_open.arn}/*",
      "Condition" : {
        "StringNotEquals": {
          "aws:sourceVpce": "${aws_vpc_endpoint.s3endpoint.id}"
        }
      }
    }
  ]
}
POLICY
}

resource "aws_s3_bucket_policy" "s3_closed" {
  bucket = "${aws_s3_bucket.s3_closed.id}"
  policy =<<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
    "Effect": "Deny",
      "Principal": "*",
      "Action":["s3:Get*"],
      "Resource": "${aws_s3_bucket.s3_closed.arn}/*",
      "Condition" : {
        "StringNotEquals": {
          "aws:sourceVpce": "${aws_vpc_endpoint.s3endpoint.id}"
        }
      }
    }
  ]
}
POLICY
}

# ----------------------------------------------------------------------------------------
# setup instance profile
# ----------------------------------------------------------------------------------------
resource "aws_iam_role" "testhost" {
  name        = "s3ec2test"
  description = "privileges for the test instance"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_policy" "s3access" {
  name        = "s3ec2test"
  description = "allow read access to specific bucket"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:List*",
        "s3:Get*"
      ],
      "Resource": [
        "${aws_s3_bucket.s3_open.arn}",
        "${aws_s3_bucket.s3_open.arn}/*"
      ]
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "s3access" {
  role       = "${aws_iam_role.testhost.name}"
  policy_arn = "${aws_iam_policy.s3access.arn}"
}

resource "aws_iam_instance_profile" "testhost" {
  name = "${aws_iam_role.testhost.name}"
  role = "${aws_iam_role.testhost.id}"
}

# ----------------------------------------------------------------------------------------
# setup an EC2 instance
# ----------------------------------------------------------------------------------------

resource "aws_instance" "testhost" {
  ami           = "${data.aws_ami.target_ami.id}"
  instance_type = "${var.instance_type}"
  key_name      = "${var.ssh_key_name}"
  subnet_id     = "${aws_subnet.s3ec2test.id}"

  vpc_security_group_ids = [
    "${aws_security_group.allow_ssh.id}",
    "${aws_security_group.allow_http_out.id}"
  ]

  iam_instance_profile = "${aws_iam_instance_profile.testhost.name}"

  root_block_device = {
    volume_type = "gp2"
    volume_size = "${var.root_vol_size}"
  }

  tags        = "${merge(map("Name","s3ec2test"), var.tags)}"
  volume_tags = "${var.tags}"

  user_data = <<EOF
#!/bin/bash
yum update -y -q
yum install -y python3-pip
yum update -y aws-cli
pip3 install awscli --upgrade
EOF
}
