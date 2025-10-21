provider "aws" {
  region = "af-south-1"
}

data "aws_ami" "amiID" {
  most_recent = true

  filter {
    name = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
  filter {
    name = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] 
}

# resource "aws_instance" "app_server" {
#   ami           = data.aws_ami.ubuntu.id
#   instance_type = "t2.micro"

#   tags = {
#     Name = "learn-terraform"
#   }
# }

output "instance_id" {
  description = "AMI ID of ubuntu instance"
  value = data.aws_ami.amiID.id
  
}