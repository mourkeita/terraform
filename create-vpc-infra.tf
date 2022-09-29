provider "aws" {
  region = "eu-west-1"
}

resource "aws_vpc" "vpcdefault" {
  cidr_block = "10.1.0.0/24"
  tags = {
   Name = "mkeita-vpc"
   TagPrefix = "mkeita-vpcdefault-aws_vpc.vpcdefault.id"
  }
}

resource "aws_subnet" "private" {
  vpc_id = aws_vpc.vpcdefault.id
  availability_zone = "eu-west-1a"
  cidr_block = "10.1.0.0/28"
  tags = {
   TagPrefix = "mkeita-subnet-private-aws_subnet.private.id"
  }
}

resource "aws_subnet" "public" {
  vpc_id = aws_vpc.vpcdefault.id
  availability_zone = "eu-west-1a"
  cidr_block = "10.1.0.96/28"
  tags = {
   TagPrefix = "mkeita-subnet-public-aws_subnet.public.id"
  }
}

resource "aws_internet_gateway" "default" {
  vpc_id = aws_vpc.vpcdefault.id
  tags = {
   TagPrefix = "mkeita-internet-gateway-aws_internet_gateway.default.id"
  }
}

resource "aws_nat_gateway" "default" {
  allocation_id = aws_eip.nginx.id
  subnet_id = aws_subnet.public.id
  tags = {
   TagPrefix = "mkeita-nat-gateway-aws_nat_gateway.default.id"
  }
}

resource "aws_security_group" "ssh-internet-access" {
  vpc_id = aws_vpc.vpcdefault.id

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    
  }

  tags = {
   TagPrefix = "mkeita-security-group-aws_security_group.ssh-internet-access.id"
  }
}

resource "aws_security_group" "db-access" {
  vpc_id = aws_vpc.vpcdefault.id

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 5432
    to_port = 5433
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    
  }

  tags = {
   TagPrefix = "mkeita-security-group-aws_security_group.db-access.id"
  }
}

//resource "tls_private_key" "octokey" {
//  algorithm = "RSA"
//  rsa_bits  = "4096"
//}


//resource "aws_key_pair" "octokey" {
//  key_name   = "octokey"
//  public_key = tls_private_key.octokey.public_key_openssh

  //provisioner "local-exec" { # Create "octokey.pem" on server !
  //  command = "echo 'tls_private_key.octokey.private_key_pem}' > ./octokey.pem"
  //}
//}

//resource "aws_key_pair" "octokey" {
// key_name   = "octokey"
// public_key = file(pathexpand("~/.ssh/my_cloud_key"))
//}

resource "aws_instance" "db-postgres" {
  instance_type = "t2.micro"
  ami = "ami-0fd8802f94ed1c969"
  availability_zone = "eu-west-1a"
  subnet_id = aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.db-access.id]
/*
  provisioner "remote-exec" {
    inline = [
      "sudo apt-get -y update",
      "sudo apt install postgresql postgresql-contrib",
      "sudo systemctl start postgresql.service",
    ]
  }

  connection {
   host        = coalesce(self.public_ip, self.private_ip)
   agent       = true
   type        = "ssh"
   user        = "ec2-user"
   private_key = file(pathexpand("~/.ssh/cloud_private_key"))
  }*/

  tags = {
    TagPrefix = "mkeita-postgres-server"
  }
}

resource "aws_eip" "nginx" {
  instance = aws_instance.web-nginx.id
  vpc = true

  tags = {
    TagPrefix = "mkeita-nginx-web-server"
  }
}

resource "aws_instance" "web-nginx" {
  instance_type = "t2.micro"
  ami = "ami-0fd8802f94ed1c969"
  availability_zone = "eu-west-1a"
  subnet_id = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.ssh-internet-access.id]
/*
  provisioner "remote-exec" {
    inline = [
      "sudo apt-get -y update",
      "sudo apt-get -y install nginx",
      "sudo service nginx start",
    ]
  }

  connection {
   host        = coalesce(self.public_ip, self.private_ip)
   agent       = true
   type        = "ssh"
   user        = "ec2-user"
   private_key = file(pathexpand("~/.ssh/cloud_private_key"))
  }*/

  tags = {
   TagPrefix = "mkeita-nginx-web-server"
  }
}

resource "aws_route_table" "rtprivate" {
  vpc_id = aws_vpc.vpcdefault.id

  route {
    cidr_block = "10.1.0.0/28"
    nat_gateway_id = aws_nat_gateway.default.id
  }
  tags = {
   TagPrefix = "mkeita-route-table-aws_route_table.rtprivate.id"
  }
}

resource "aws_route_table" "rtpublic" {
  vpc_id = aws_vpc.vpcdefault.id
  
  route {
    cidr_block = "10.1.0.0/96"
    gateway_id = aws_internet_gateway.default.id
  }
  tags = {
   TagPrefix = "mkeita-route-table-aws_route_table.rtpublic.id"
  }
}
