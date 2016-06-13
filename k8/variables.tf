variable "customer" {}
variable "conftag" {
  default = "PROD"
}
variable "real_customer" {
  default = "none"
}
variable "products" {}
variable "disk_type" {
  default = "none"
}
variable "barge_type" {}
variable "environment" {}
variable "ami" {
  default = "ami-864d84ee"
}
variable "instance_type" {}
variable "package_size" {}
variable "aws_region" {
  default = "us-east-1"
}
variable "aws_customprofile" {}
variable "security_groups" {}
variable "availability_zones" {}
variable "vpc_zone_identifiers" {}
variable "termination_policy" {
  default = "OldestInstance"
}
variable "asg_max_size" {}
variable "asg_min_size" {}
variable "asg_desired_capacity" {}
variable "elb_lambda_update_arn" {}
variable "artifacts_credentials" {}
variable "artifacts_endpoint" {}
