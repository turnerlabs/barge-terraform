variable "customer" {}
variable "conftag" {
  default = "PROD"
}
variable "real_customer" {
  default = "mss"
}
variable "environment" {}
variable "products" {}
variable "ami" {
  default = "ami-864d84ee"
}
variable "instance_type" {}
variable "package_size" {}
variable "aws_region" {
  default = "us-east-1"
}
variable "aws_customprofile" {}
variable "key_name" {}
variable "security_groups" {}
variable "availability_zone" {}
variable "subnet_id" {}
