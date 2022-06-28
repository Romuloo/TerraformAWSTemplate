variable "subnet_prefix" {
  description = "cidr block for the subnet"
}

variable "eof_code"{
  description = "EOF code"
}

variable "provider_conf"{
  description = "Access Key & Secret Key"
}

variable "instance_conf"{
  description = "AWS instance launched"
}

provider "aws" {
  region = var.provider_conf.region
  access_key = var.provider_conf.access_key
  secret_key = var.provider_conf.secret_key
}

resource "tls_private_key" "pk" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "kp" {
  key_name   = "mis-claves"       # Create "myKey" to AWS!!
  public_key = tls_private_key.pk.public_key_openssh
}
resource "aws_vpc" "my-vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "prod-vpc"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.my-vpc.id
}

resource "aws_route_table" "my-rt" {
  vpc_id = aws_vpc.my-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "prod-rt"
  }
}

resource "aws_subnet" "my-subnet-1" {
  vpc_id = aws_vpc.my-vpc.id
  cidr_block = var.subnet_prefix.cidr_block
  availability_zone = var.subnet_prefix.region

  tags = {
    Name = var.subnet_prefix.name
  }
}

resource "aws_route_table_association" "tabla" {
  subnet_id      = aws_subnet.my-subnet-1.id
  route_table_id = aws_route_table.my-rt.id
}

resource "aws_security_group" "allow-web" {
  name        = "allow_web"
  description = "Allow web inbound traffic"
  vpc_id      = aws_vpc.my-vpc.id

  ingress {
    description      = "HTTPS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]

  }

  ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]

  }

  ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_web"
  }
}


resource "aws_network_interface" "web-server" {
  subnet_id       = aws_subnet.my-subnet-1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow-web.id]
}

resource "aws_eip" "one" {
  vpc = true
  network_interface = aws_network_interface.web-server.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [aws_internet_gateway.gw]
}


resource "aws_instance" "web-server-instance" {
  ami = var.instance_conf.ami
  instance_type = var.instance_conf.type
  availability_zone = var.instance_conf.zone
  key_name = var.instance_conf.claves

  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.web-server.id
  }
     user_data = var.eof_code
        tags = {
                Name = "servidor-web"
        }
}