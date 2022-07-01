resource "aws_security_group" "security_group" {
  name   = "Security Group ${var.tag}"
  vpc_id = aws_vpc.vpc.id

  # SSH (todo do not use in production)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP access via the web
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # allow everything that is required since terraform removes it automatically (https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Security Group ${var.tag}"
  }
}

resource "aws_security_group" "db_security_group" {
  name   = "Security Group DB ${var.tag}"
  vpc_id = aws_vpc.vpc.id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.vpc.cidr_block]
  }

  # allow everything that is required since terraform removes it automatically (https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Security Group DB ${var.tag}"
  }
}
