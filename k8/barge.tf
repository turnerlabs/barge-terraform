# Configure the AWS Provider
provider "aws" {
  profile = "${var.aws_customprofile}"
  region = "${var.aws_region}"
}

module "bootstrap" {
  source = "git::ssh://git@bitbucket.org/vgtf/argo-bootstrap-terraform.git?ref=initial-release"
  products = "${var.products}"
  conftag = "${var.conftag}"
  customer = "${var.customer}"
  real_customer = "${var.real_customer}"
  disk_type = "${var.barge_type}"
  package_size = "${var.package_size}"
}

resource "aws_launch_configuration" "barge" {
  name_prefix = "${var.customer}-${var.barge_type}-${var.environment}-terraform-"
  image_id = "${var.ami}"
  instance_type = "${var.instance_type}" 
  security_groups = ["${split(",", var.security_groups)}"]
  user_data = "${module.bootstrap.user_data}"
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

/* TODO:
resource "aws_sns_topic" "barge-notifications" {
  name = "barge-notifications-terraform"
}

Email is not supported, but documenting here that we do like emails sent for ASG updates
resource "aws_sns_topic_subscription" "barge-notifications" {
    topic_arn = "${aws_sns_topic.barge-notifications-terraform.arn}"
    protocol  = "email"
    endpoint  = "madops@turner.com"
}
*/

resource "aws_lambda_function" "lambda-elb-update" {
    s3_bucket = "${var.elb_lambda_s3_bucket}"
    s3_key = "${var.elb_lambda_s3_key}"
    function_name = "${var.customer}-${var.environment}-${var.elb_lambda_function_name}"
    role = "${var.elb_lambda_role}"
    handler = "${var.elb_lambda_handler}"
    description = "Update ELB-s assocated with services on a barge when the ASG scales in/out"
    memory_size = "128"
    runtime = "nodejs"
    timeout = "300"
}

resource "aws_sns_topic" "barge-elb-update" {
  name = "${var.customer}-${var.environment}-barge-elb-update-terraform"
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
