provider "aws" {
  region     = "us-east-1"
  access_key = "##########################"
  secret_key = "############################"
}

resource "aws_instance" "myfirst_instance" {
  ami           = "ami-0885b1f6bd170450c"
  instance_type = "t2.micro"
  availability_zone = "us-east-1a"
  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install apache2 -y
              sudo systemctl start apache2
              sudo bash -c 'echo First web server using terraform > /var/www/html/index.html'
              sudo apt-get install docker.io -y
              EOF

  tags = {
    Name = "Terraform instance"
  }
}  

resource "aws_vpc" "first-vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "production"
  }
}

resource "aws_subnet" "subnet-1" {
  vpc_id     = aws_vpc.first-vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "prod-subnet"
  }
}
  resource "aws_internet_gateway" "firstIG" {
  vpc_id = aws_vpc.first-vpc.id

  tags = {
    Name = "Internet-gateway"
  }
}

resource "aws_route_table" "prod-route-table" {
  vpc_id = aws_vpc.first-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.firstIG.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.firstIG.id
  }

  tags = {
    Name = "route-table"
  }
}

# route table association
resource "aws_route_table_association" "association" {
  subnet_id      = aws_subnet.subnet-1.id
  route_table_id = aws_route_table.prod-route-table.id
}
# security group creation
resource "aws_security_group" "My-SG" {
  name        = "allow_tls"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.first-vpc.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_web"
  }
}
# creating a network interface

resource "aws_network_interface" "Network-interface" {
  subnet_id       = aws_subnet.subnet-1.id
  private_ips     = ["10.0.0.50"]
  security_groups = [aws_security_group.My-SG.id]
}
# attaching an elastic IP

resource "aws_eip" "elastic-IP-address" {
  vpc                       = true
  network_interface         = aws_network_interface.Network-interface.id
  associate_with_private_ip = "10.0.0.50"
  depends_on                = [aws_internet_gateway.firstIG]
}  
