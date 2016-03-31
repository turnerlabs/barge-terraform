# Configure the AWS Provider
provider "aws" {
  profile = "${var.aws_customprofile}"
  region = "${var.aws_region}"
}

resource "template_file" "bootstrap" {
  template = "${file("${path.module}/bootstrap.tpl")}"
  vars {
    customer = "${var.customer}"
    environment = "${var.environment}"
    conftag = "${var.conftag}"
    barge_customer = "${var.barge_customer}"
    barge_type = "${var.barge_type}"
    package_size = "${var.package_size}"
  }
}

resource "aws_launch_configuration" "barge" {
  name_prefix = "${var.customer}-${var.barge_type}-${var.environment}-terraform-"
  image_id = "${var.ami}"
  instance_type = "${var.instance_type}" 
  security_groups = ["${split(",", var.security_groups)}"]
  user_data = "${template_file.bootstrap.rendered}"
  enable_monitoring = false
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "barge" {
  name = "${var.customer}-${var.barge_type}-${var.environment}-terraform"
  launch_configuration = "${aws_launch_configuration.barge.name}"

  lifecycle {
    create_before_destroy = true
  }
  availability_zones = ["${split(",", var.availability_zones)}"]
  max_size = "${var.asg_max_size}"
  min_size = "${var.asg_min_size}"
  desired_capacity = "${var.asg_desired_capacity}"
  health_check_grace_period = 300
  health_check_type = "EC2"
  vpc_zone_identifier = ["${split(",", var.vpc_zone_identifiers)}"]
  termination_policies = ["${var.termination_policy}"]

  tag {
    key = "creator"
    value = "autoscale"
    propagate_at_launch = true
  }
  tag {
    key = "customer"
    value = "${var.customer}"
    propagate_at_launch = true
  }
  tag {
    key = "environment"
    value = "${var.environment}"
    propagate_at_launch = true
  }
  tag {
    key = "owner"
    value = "ictops"
    propagate_at_launch = true
  }
  tag {
    key = "purpose"
    value = "barge"
    propagate_at_launch = true
  }
  tag {
    key = "type"
    value = "compute"
    propagate_at_launch = true
  }
}

resource "aws_sns_topic" "barge-notifications" {
  name = "barge-notifications-terraform"
}

/* TODO:
Email is not supported, but documenting here that we do like emails sent for ASG updates
resource "aws_sns_topic_subscription" "barge-notifications" {
    topic_arn = "${aws_sns_topic.barge-notifications-terraform.arn}"
    protocol  = "email"
    endpoint  = "madops@turner.com"
}
*/

/* TODO: Lambda function does not handle duplicate definitions well, needs to be broken out into a one time run...
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
*/

resource "aws_lambda_function" "lambda-elb-update" {
    s3_bucket = "${var.elb_lambda_s3_bucket}"
    s3_key = "${var.elb_lambda_s3_key}"
    function_name = "${var.elb_lambda_function_name}"
    role = "${var.elb_lambda_role}"
    handler = "${var.elb_lambda_handler}"
    description = "Update ELB-s assocated with services on a barge when the ASG scales in/out"
    memory_size = "128"
    runtime = "nodejs"
    timeout = "300"
}

resource "aws_sns_topic" "barge-elb-update" {
  name = "barge-elb-update-terraform"
}

resource "aws_sns_topic_subscription" "barge-elb-update" {
    topic_arn = "${aws_sns_topic.barge-elb-update.arn}"
    protocol  = "lambda"
    endpoint  = "${aws_lambda_function.lambda-elb-update.arn}"
}

resource "aws_autoscaling_notification" "elb_asg_update_notification" {
  group_names = [
    "${aws_autoscaling_group.barge.name}"
  ]
  notifications = [
    "autoscaling:EC2_INSTANCE_LAUNCH"
  ]
  topic_arn = "${aws_sns_topic.barge-elb-update.arn}"
}

/* Another resource like IAM role/lambda function that needs to be run only once per account...
resource "aws_iam_server_certificate" "dummy-cert" {
  name = "dummy-cert"
  certificate_body = "${file("${path.module}/dummy-cert.crt")}"
  private_key = "${file("${path.module}/dummy-cert.key")}"
}
*/
