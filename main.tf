resource "aws_vpc" "custom_vpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "custom_vpc"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.custom_vpc.id

  tags = {
    Name = "custom_igw"
  }
}

resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.custom_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "custom_routetable"
  }
}

resource "aws_subnet" "subnet1" {
  vpc_id     = aws_vpc.custom_vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "ap-south-1a"

  tags = {
    Name = "subnet1"
  }
}

resource "aws_subnet" "subnet2" {
  vpc_id     = aws_vpc.custom_vpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "ap-south-1b"

  tags = {
    Name = "subnet2"
  }
}

# resource "aws_route_table_association" "gwa" {
#   gateway_id     = aws_internet_gateway.gw.id
#   route_table_id = aws_route_table.rt.id
# }

resource "aws_route_table_association" "sna1" {
  subnet_id      = aws_subnet.subnet1.id
  route_table_id = aws_route_table.rt.id
}

resource "aws_route_table_association" "sna2" {
  subnet_id      = aws_subnet.subnet2.id
  route_table_id = aws_route_table.rt.id
}

#creating instances

resource "aws_instance" "web1" {
  ami           = var.ami_id
  instance_type = var.instance_type
  key_name = var.keypair
  associate_public_ip_address = true

  tags = {
    Name = "server1"
  }
  subnet_id = aws_subnet.subnet1.id
  # security_groups = ["${aws_security_group.server_sg.name}"]
  security_groups = [aws_security_group.server_sg.id]
  user_data = <<-EOF
  #!/bin/bash
  sudo apt-get update -y
  sudo apt-get install -y apache2
  sudo systemctl status apache2
  sudo systemctl start apache2
  sudo chown -R $USER:$USER /var/www/html
  sudo echo "<h1>Hello from Server1</h1>" > /var/www/html/index.html
  EOF
}

resource "aws_instance" "web2" {
  ami           = var.ami_id
  instance_type = var.instance_type
  key_name = var.keypair
  associate_public_ip_address = true

  tags = {
    Name = "server2"
  }
  subnet_id = aws_subnet.subnet2.id
  # security_groups = ["${aws_security_group.server_sg.name}"]
  security_groups = [aws_security_group.server_sg.id]
  user_data = <<-EOF
  #!/bin/bash
  sudo apt-get update -y
  sudo apt-get install -y apache2
  sudo systemctl status apache2
  sudo systemctl start apache2
  sudo chown -R $USER:$USER /var/www/html
  sudo echo "<h1>Hello from Server2</h1>" > /var/www/html/index.html
  EOF
}

#Security Groups
resource "aws_security_group" "server_sg" {
  
  vpc_id = aws_vpc.custom_vpc.id
  description = "Allow traffic for the servers created in custom vpc"
  

  ingress {
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["223.185.65.48/32"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "server_sg"
  }
}

# creating Sg for application load balancer

resource "aws_security_group" "lb_sg" {
  
  vpc_id = aws_vpc.custom_vpc.id
  description = "Allow traffic for the alb created in custom vpc"
  

  ingress {
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    from_port        = 443
    to_port          = 443
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
    Name = "lb_sg"
  }
}

# creating application load balancer

resource "aws_lb" "custom_alb" {
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb_sg.id]
  subnets = [aws_subnet.subnet1.id , aws_subnet.subnet2.id]
  tags = {
    Name = "custom_alb"
  }
}

# resource "aws_lb" "front_end" {
#   # ...
# }
resource "aws_lb_target_group" "lb_tg" {
  port     = 80
  protocol = "HTTP"
  target_type = "instance"
  vpc_id   = aws_vpc.custom_vpc.id
  health_check {
    interval            = 70
    path                = "/"
    port                = 80
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 60 
    protocol            = "HTTP"
  }
}

resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.custom_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lb_tg.arn
  }
}
resource "aws_lb_target_group_attachment" "association1" {
  target_group_arn = aws_lb_target_group.lb_tg.arn
  target_id        = aws_instance.web1.id
  port             = 80
}
resource "aws_lb_target_group_attachment" "association2" {
  target_group_arn = aws_lb_target_group.lb_tg.arn
  target_id        = aws_instance.web2.id
  port             = 80
}

