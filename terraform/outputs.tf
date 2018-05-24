output "public_dns" {
  value = "${aws_instance.testhost.public_dns}"
}

output "private_dns" {
  value = "${aws_instance.testhost.private_dns}"
}

output "connect_string" {
  value = "ssh -i data/${var.ssh_key_name}.pem ec2-user@${aws_instance.testhost.public_dns}"
}

output "vpc_id" {
  value = "${aws_vpc.test_vpc.id}"
}

output "subnet_id" {
  value = "${aws_subnet.s3ec2test.id}"
}

output "open_bucket" {
  value = "${aws_s3_bucket.s3_open.arn}"
}

output "closed_bucket" {
  value = "${aws_s3_bucket.s3_closed.arn}"
}
