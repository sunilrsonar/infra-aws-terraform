provider "aws" {
    region = "us-east-1"
}

resource "aws_vpc" "prod-example" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags = {
    Name = "prod-vpc"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.prod-example.id

  tags = {
    Name = "prod-igw"
  }
}

resource "aws_subnet" "public_subnet_1a" {
    vpc_id = aws_vpc.prod-example.id
    cidr_block = "10.0.1.0/24"
    availability_zone = "us-east-1a"
    map_public_ip_on_launch = true

    tags = {
      Name = "public-subnet-1a"
    }
}

resource "aws_subnet" "public_subnet_1b" {
    vpc_id = aws_vpc.prod-example.id
    cidr_block = "10.0.2.0/24"
    availability_zone = "us-east-1b"
    map_public_ip_on_launch = true

    tags = {
      Name = "public-subnet-1b"
    }
}

resource "aws_subnet" "private_subnet_1a" {
    vpc_id = aws_vpc.prod-example.id
    cidr_block = "10.0.3.0/24"
    availability_zone = "us-east-1a"

    tags = {
      Name = "private-subnet-1a"
    }
}

resource "aws_subnet" "private_subnet_1b" {
    vpc_id = aws_vpc.prod-example.id
    cidr_block = "10.0.4.0/24"
    availability_zone = "us-east-1b"

    tags = {
      Name = "private-subnet-1b"
    }
}

resource "aws_eip" "nat_1a" {
    domain = "vpc"
}

resource "aws_eip" "nat_1b" {
    domain = "vpc"
}

resource "aws_nat_gateway" "nat_1a" {
    allocation_id = aws_eip.nat_1a.id
    subnet_id = aws_subnet.public_subnet_1a.id

    tags = {
      Name = "nat-gateway-1a"
    }
}

resource "aws_nat_gateway" "nat_1b" {
    allocation_id = aws_eip.nat_1b.id
    subnet_id = aws_subnet.public_subnet_1b.id

    tags = {
      Name = "nat-gateway-1b"
    }
}

resource "aws_route_table" "public_route" {
  vpc_id = aws_vpc.prod-example.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public-rt"
  }
}

resource "aws_route_table_association" "public_rt_1a" {
  subnet_id = aws_subnet.public_subnet_1a.id
  route_table_id = aws_route_table.public_route.id
}

resource "aws_route_table_association" "public_rt_1b" {
  subnet_id = aws_subnet.public_subnet_1b.id
  route_table_id = aws_route_table.public_route.id
}

resource "aws_route_table" "private_rt_1a" {
  vpc_id = aws_vpc.prod-example.id
  
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_1a.id
  }

  tags = {
    Name = "private-rt-1a"
  }
}

resource "aws_route_table_association" "private_rt_assoc_1a" {
  subnet_id = aws_subnet.private_subnet_1a.id
  route_table_id = aws_route_table.private_rt_1a.id
}

resource "aws_route_table" "private_rt_1b" {
  vpc_id = aws_vpc.prod-example.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_1b.id
  }

  tags = {
    Name = "private-rt-1b"
  }
}

resource "aws_route_table_association" "private_rt_assoc_1b" {
  subnet_id = aws_subnet.private_subnet_1b.id
  route_table_id = aws_route_table.private_rt_1b.id
}

resource "aws_security_group" "load_sg" {
  name = "load_sg"
  description = "Allow HTTP traffic"
  vpc_id = aws_vpc.prod-example.id

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
    Name = "load-sg"
  }
}

resource "aws_lb" "app_lb" {
  name = "application-loadbalancer"
  internal = false
  load_balancer_type = "application"
  subnets = [
    aws_subnet.public_subnet_1a.id,
    aws_subnet.public_subnet_1b.id
  ]
  security_groups = [ aws_security_group.load_sg.id ]

  tags = {
    Name = "app-lb"
  }
}

resource "aws_autoscaling_group" "prod_scale" {
  name = "autoscaling-aws-prod"
  max_size = 4
  min_size = 2
  desired_capacity = 2
  vpc_zone_identifier = [
    aws_subnet.private_subnet_1a.id,
    aws_subnet.private_subnet_1b.id
  ]
  health_check_type = "EC2"
  health_check_grace_period = 300
  target_group_arns = [aws_lb_target_group.app_tg.arn]

  launch_template {
    id = aws_launch_template.app_template.id
    version = "$Latest"
  }
  tag {
    key = "Name"
    value = "app-instance"
    propagate_at_launch = true
  }
}

data "aws_instances" "asg_instance" {
  instance_tags = {
    Name = "app-instance"
  }

  instance_state_names = ["running"]

  depends_on = [aws_autoscaling_group.prod_scale]
}

resource "aws_security_group" "app_sg" {
  name = "app-sg"
  description = "Allow traffic from LB"
  vpc_id = aws_vpc.prod-example.id

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    security_groups = [ aws_security_group.load_sg.id ]
  }

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    security_groups = [ aws_security_group.jump_sg.id ]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "app-sg"
  }
}

resource "aws_key_pair" "local_key" {
  public_key = file("/home/aizen-sosuke/.ssh/id_ed25519.pub")

  tags = {
    Name = "My-key-pair"
  }
}


resource "aws_launch_template" "app_template" {
  name_prefix             = "app-it-"  # Change from `name` to `name_prefix`
  image_id                = "ami-084568db4383264d4"
  instance_type           = "t2.micro"
  vpc_security_group_ids  = [aws_security_group.app_sg.id]
  key_name                = aws_key_pair.local_key.key_name

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "app-instance"
    }
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app_lb.arn
  port = 80
  protocol = "HTTP"

  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

resource "aws_lb_target_group" "app_tg" {
  name = "app-target-group"
  port = 80
  protocol = "HTTP"
  vpc_id = aws_vpc.prod-example.id

  tags = {
    Name = "app-tg"
  }
}

resource "aws_security_group" "jump_sg" {
  name = "jump-sg"
  description = "Allow SSH"
  vpc_id = aws_vpc.prod-example.id

  ingress {
    from_port = 22
    to_port = 22
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
    Name = "jump=sg"
  }
}

resource "aws_instance" "jumpserver" {
  ami = "ami-084568db4383264d4"
  instance_type = "t2.micro"
  availability_zone = "us-east-1a"
  subnet_id = aws_subnet.public_subnet_1a.id
  key_name = aws_key_pair.local_key.key_name
  vpc_security_group_ids = [aws_security_group.jump_sg.id]

  tags = {
    Name = "jumpserver"
  }
}

resource "null_resource" "copy_ansiblefileto_jump" {
  depends_on = [ aws_instance.jumpserver ]

  provisioner "file" {
    source = "install_nginx.yml"
    destination = "/home/ubuntu/install_nginx.yml"
  }

  provisioner "file" {
    source = "/home/aizen-sosuke/.ssh/id_ed25519"
    destination = "/home/ubuntu/id_ed25519"
  }
    
  connection {
    type = "ssh"
    user = "ubuntu"
    private_key = file("/home/aizen-sosuke/.ssh/id_ed25519")
    host = aws_instance.jumpserver.public_ip
  }
}

output "public_ip" {
  value = aws_instance.jumpserver.public_ip
}

output "public_dns" {
  value = aws_lb.app_lb.dns_name
}

output "private_ips" {
  value = data.aws_instances.asg_instance.private_ips
}
