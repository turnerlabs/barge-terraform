# Configure the AWS Provider
provider "aws" {
  profile = "${var.aws_customprofile}"
  region = "${var.aws_region}"
}

resource "aws_iam_role_policy" "iam_for_lambda_elb_full_access" {
  name = "iam_for_lambda_elb_full_access"
  role = "${aws_iam_role.iam_for_lambda.id}"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "elasticloadbalancing:*",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "cloudwatch:*",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "autoscaling:*",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "iam_for_lambda_cloudwatch_logs_full_access" {
  name = "iam_for_lambda_cloudwatch_logs_full_access"
  role = "${aws_iam_role.iam_for_lambda.id}"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [ "logs:*" ],
      "Resource": "*"
    }
  ]
}
EOF
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

resource "aws_lambda_function" "lambda-elb-update" {
    s3_bucket = "${var.elb_lambda_s3_bucket}"
    s3_key = "${var.elb_lambda_s3_key}"
    function_name = "${var.elb_lambda_function_name}"
    role = "${aws_iam_role.iam_for_lambda.arn}"
    handler = "${var.elb_lambda_handler}"
    description = "Update ELB-s assocated with services on a barge when the ASG scales in/out"
    memory_size = "128"
    runtime = "nodejs"
    timeout = "300"
}

resource "aws_iam_server_certificate" "dummy-cert" {
  name = "dummy-cert"
  certificate_body = "${file("${path.module}/dummy-cert.crt")}"
  private_key = "${file("${path.module}/dummy-cert.key")}"
}

resource "aws_security_group" "harbor-default" {
  name = "harbor-default"
  description = "Allow all inbound/outbound traffic"
  vpc_id = "${var.vpc_id}"

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

  tags {
    Name = "argo-sg"
  }
}

resource "aws_iam_user" "deployit-trigger" {
    name = "deployit-trigger-svc"
}

resource "aws_iam_user_policy" "deployit-trigger" {
    name = "deployit-trigger-svc"
    user = "${aws_iam_user.deployit-trigger.name}"
    policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "ec2:Describe*",
      "Effect": "Allow",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "elasticloadbalancing:*",
      "Resource": "*"
    }
  ]
}
EOF
}
