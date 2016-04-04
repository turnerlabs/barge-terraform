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
    package_size = "${var.package_size}"
  }
}

resource "aws_instance" "etcd" {
    ami = "${var.ami}"
    instance_type = "${var.instance_type}"
    key_name = "${var.key_name}"
    availability_zone = "${var.availability_zone}"
    subnet_id = "${var.subnet_id}"
    user_data = "${template_file.bootstrap.rendered}"
    security_groups = ["${split(",", var.security_groups)}"]
    tags {
        customer = "${var.customer}"
        environment = "${var.environment}"
        owner = "ictops"
    }
}
