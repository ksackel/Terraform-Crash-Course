# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
  access_key = "***************"
  secret_key = "***************"
  
}
# create vpc
resource "aws_vpc" "prod-vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
      Name = "production"
  }
}

#create internet gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.prod-vpc.id
  
}

#create custom route table
resource "aws_route_table" "prod-route-table" {
  vpc_id = aws_vpc.prod-vpc.id

  route{
      #all traffic is sent to internet gateway; all traffic from subnet is being set to internet; creating default route;
      cidr_block = "0.0.0.0/0"
      
      gateway_id = aws_internet_gateway.gw.id
    }
  route  {
      ipv6_cidr_block        = "::/0"
      gateway_id = aws_internet_gateway.gw.id
    }

  tags = {
    Name = "prod"
  }
}

#create subnet where web server  will reside
resource "aws_subnet" "subnet-1" {
  vpc_id = aws_vpc.prod-vpc.id
  cidr_block = "10.0.1.0/24"
  # can specify the availability zone  where vpc will reside; az is 2 or more dc within a region
  availability_zone = "us-east-1a"
  tags = {
    #tag allows u to reference a user friendly name in AWS kamo
    Name = "prod-subnet"
  }
  
}
#created a route table and subnet; need to assign subnet to route table
#associate subnet with route table
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet-1.id
  route_table_id = aws_route_table.prod-route-table.id
}
#create a security group allow port 22, 80, 443
resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow web inbound traffic"
  vpc_id      = aws_vpc.prod-vpc.id

  ingress {
      description      = "https from VPC"
      from_port        = 443
      to_port          = 443
      protocol         = "tcp"
      #any IP address can access the web server
      cidr_blocks      = ["0.0.0.0/0"]
      
    }
  
  ingress {
      description      = "http from VPC"
      from_port        = 80
      to_port          = 80
      protocol         = "tcp"
      #any IP address can access the web server
      cidr_blocks      = ["0.0.0.0/0"]
      
    }
  
  ingress {
      description      = "ssh from VPC"
      from_port        = 22
      to_port          = 22
      protocol         = "tcp"
      #any IP address can access the web server
      cidr_blocks      = ["0.0.0.0/0"]
      
    }
  

  egress {
      from_port        = 0
      to_port          = 0
      # any protocol; allowing all ports in the egress direction
      protocol         = "-1"
      # any IP address
      cidr_blocks      = ["0.0.0.0/0"]
      
    }
  
  tags = {
    "Name" = "allow_web"
  }

  
}
#create network interface
resource "aws_network_interface" "web-server-nic" {
  subnet_id       = aws_subnet.subnet-1.id
  #what IP address do u want to give server ?
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]

  
}
# assign an elastic IP (public IP) to nic
resource "aws_eip" "one" {
  # eip requires internet gateway to be deployed on subnet first before eip gets deployed
  vpc                       = true
  network_interface         = aws_network_interface.web-server-nic.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [
    aws_internet_gateway.gw
  ]
}

#create ubuntu server and install/enable apache2
resource "aws_instance" "web" {
  ami           = "ami-09e67e426f25ce0d7"
  instance_type = "t2.micro"
  # set availability zone as the subnet; we want subnet and interface(server) in the same availability zone to bind.
  availability_zone = "us-east-1a"
  #need to reference key pair to access device
  key_name = "main-key"
  #
  network_interface {
    #provide  adevice index; can apply many interfacces to a single ec2 ; tell ec2 instance which interface it is
    # first network interface associated with this device
    device_index = 0
    network_interface_id = aws_network_interface.web-server-nic.id


  }
  # tell tf to run commands after deployment of server to install apache 
  user_data = <<-EOF
  #!/bin/bash
  sudo apt update -y
  sudo apt intall apache2 -y
  sudo systemctl start apache2
  sudo bash -c 'echo very first web server > /var/www/html/index.html'
  EOF
  tags = {
    Name = "web-server"
  }
}





