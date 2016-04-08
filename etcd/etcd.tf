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
  barge_type = "${var.barge_type}"
  package_size = "${var.package_size}"
}

resource "aws_instance" "etcd" {
    ami = "${var.ami}"
    instance_type = "${var.instance_type}"
    key_name = "${var.key_name}"
    availability_zone = "${var.availability_zone}"
    subnet_id = "${var.subnet_id}"
    user_data = "${module.bootstrap.user_data}"
    security_groups = ["${split(",", var.security_groups)}"]
    tags {
        customer = "${var.customer}"
        environment = "${var.environment}"
        owner = "ictops"
    }
}
