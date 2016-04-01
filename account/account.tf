# Configure the AWS Provider
provider "aws" {
  profile = "${var.aws_customprofile}"
  region = "${var.aws_region}"
}

resource "aws_iam_role" "iam_for_lambda" {
    name = "lambda_asg_barge_elb_update-terraform"
    assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_server_certificate" "dummy-cert" {
  name = "dummy-cert"
  certificate_body = "${file("${path.module}/dummy-cert.crt")}"
  private_key = "${file("${path.module}/dummy-cert.key")}"
}
