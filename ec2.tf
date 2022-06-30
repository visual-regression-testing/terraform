data "aws_ami" "amazon_linux" {
  most_recent = true

  filter {
    name   = "image-id"
    values = ["ami-0022f774911c1d690"]
  }

  # owner of the AMI
  owners = ["137112412989"]
}

resource "aws_instance" "web" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t2.small"
  vpc_security_group_ids      = [aws_security_group.security_group.id]
  subnet_id                   = aws_subnet.public.id
  associate_public_ip_address = true

  user_data = data.template_file.init.rendered

  key_name = "${var.tag}-deploy-key"

  tags = {
    Name = "Linux ${var.tag}"
  }
}
